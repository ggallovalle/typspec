use std::path::Path;
use typst_syntax::{SyntaxKind, SyntaxNode, ast};
use typst_syntax::ast::AstNode;

/// Result of an AST surgery operation.
#[derive(Debug)]
pub struct SurgeryResult {
    /// The modified source text.
    pub source: String,
    /// Number of modifications applied.
    pub changes: usize,
}

/// A spec-delta operation.
#[derive(Debug, Clone)]
pub struct DeltaOp {
    pub action: DeltaAction,
    pub id: String,
    pub content: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum DeltaAction {
    Added,
    Modified,
    Removed,
}

/// Apply a set of spec-delta operations to a target spec file.
pub fn apply_deltas(
    source_path: &Path,
    operations: &[DeltaOp],
) -> Result<SurgeryResult, String> {
    let text = std::fs::read_to_string(source_path)
        .map_err(|e| format!("cannot read {}: {}", source_path.display(), e))?;

    let root = typst_syntax::parse(&text);

    // Split into "added" ops vs modify/remove ops
    let added_ops: Vec<&DeltaOp> = operations.iter().filter(|op| op.action == DeltaAction::Added).collect();
    let mod_ops: Vec<DeltaOp> = operations.iter()
        .filter(|op| op.action != DeltaAction::Added)
        .cloned()
        .collect();

    // Apply modify/remove operations first (tree walk)
    let (mut tree, changes) = apply_ops(&root, &mod_ops);

    // Apply "added" operations — append new content to the root
    let mut added_count = 0usize;
    for op in &added_ops {
        if let Some(content) = &op.content {
            let parsed = typst_syntax::parse(content);
            // Append parsed content to root's children
            let mut children: Vec<SyntaxNode> = tree.children().cloned().collect();
            for child in parsed.children() {
                children.push(child.clone());
            }
            tree = SyntaxNode::inner(SyntaxKind::Markup, children);
            added_count += 1;
        }
    }

    Ok(SurgeryResult {
        source: tree.into_text().to_string(),
        changes: changes + added_count,
    })
}

/// Recursively walk the tree, applying operations.
fn apply_ops(node: &SyntaxNode, ops: &[DeltaOp]) -> (SyntaxNode, usize) {
    match node.kind() {
        SyntaxKind::Markup => {
            let mut new_children: Vec<SyntaxNode> = Vec::new();
            let mut changes = 0usize;

            for child in node.children() {
                let (processed, c) = apply_ops(child, ops);
                changes += c;
                new_children.push(processed);
            }

            (SyntaxNode::inner(SyntaxKind::Markup, new_children), changes)
        }
        SyntaxKind::FuncCall => {
            if let Some(op) = find_matching_op(node, ops) {
                match op.action {
                    DeltaAction::Removed => {
                        (SyntaxNode::leaf(SyntaxKind::Space, ""), 1)
                    }
                    DeltaAction::Modified | DeltaAction::Added => {
                        if let Some(content) = &op.content {
                            let parsed = typst_syntax::parse(content);
                            (parsed, 1)
                        } else {
                            (node.clone(), 0)
                        }
                    }
                }
            } else {
                (node.clone(), 0)
            }
        }
        _ => {
            if node.children().len() > 0 {
                let mut new_children: Vec<SyntaxNode> = Vec::new();
                let mut changes = 0usize;

                for child in node.children() {
                    let (processed, c) = apply_ops(child, ops);
                    changes += c;
                    new_children.push(processed);
                }

                (SyntaxNode::inner(node.kind(), new_children), changes)
            } else {
                (node.clone(), 0)
            }
        }
    }
}

/// Extract the body content block `[...]` from a `#requirement("id", ...)` call
/// in the given source text. Returns `None` if the requirement is not found.
pub fn extract_requirement_body(source_text: &str, id: &str) -> Option<String> {
    let root = typst_syntax::parse(source_text);
    extract_body_from_node(&root, id)
}

fn extract_body_from_node(node: &SyntaxNode, id: &str) -> Option<String> {
    if node.kind() == SyntaxKind::FuncCall {
        let text = node.clone().into_text().to_string();
        let pattern = format!("requirement(\"{}\"", id);
        let pattern2 = format!("requirement('{}'", id);
        if text.contains(&pattern) || text.contains(&pattern2) {
            // Find the opening `(` of the function arguments by looking for
            // `(id` which follows `requirement("
            if let Some(args_start) = text.find('(') {
                // Track paren depth to find the matching closing `)`
                let mut depth = 1u32;
                let mut args_end = 0usize;
                for (i, c) in text[args_start + 1..].char_indices() {
                    match c {
                        '(' => depth += 1,
                        ')' => {
                            depth -= 1;
                            if depth == 0 { args_end = args_start + 1 + i; break; }
                        }
                        _ => {}
                    }
                }
                if depth > 0 { return None; }

                // Now find the body content block `[...]` after the closing `)`
                let after_args = &text[args_end + 1..].trim_start();
                if let Some(body_start_char) = after_args.chars().next() {
                    if body_start_char != '[' { return None; }
                    let body_content = &after_args[1..];
                    let mut depth = 1u32;
                    let mut body_end = 0usize;
                    for (i, c) in body_content.char_indices() {
                        match c {
                            '[' => depth += 1,
                            ']' => {
                                depth -= 1;
                                if depth == 0 { body_end = i; break; }
                            }
                            _ => {}
                        }
                    }
                    if depth == 0 {
                        return Some(body_content[..body_end].trim().to_string());
                    }
                }
            }
        }
    }

    for child in node.children() {
        if let Some(result) = extract_body_from_node(child, id) {
            return Some(result);
        }
    }

    None
}
fn find_matching_op<'a>(node: &SyntaxNode, ops: &'a [DeltaOp]) -> Option<&'a DeltaOp> {
    if node.kind() != SyntaxKind::FuncCall {
        return None;
    }

    let funcall = ast::FuncCall::from_untyped(node)?;
    let callee = funcall.callee();
    let ident = ast::Ident::from_untyped(callee.to_untyped())?;

    if ident.as_str() != "requirement" {
        return None;
    }

    // Get the text representation to extract the requirement ID
    let text = node.clone().into_text().to_string();

    // Find the ID between the first `"` after `requirement(` and its matching `"`
    // This is a text-level approach to extract the ID from the source
    if let Some(start) = text.find('"') {
        if let Some(end) = text[start + 1..].find('"') {
            let id = &text[start + 1..start + 1 + end];
            return ops.iter().find(|op| op.id == id);
        }
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_id_in_requirement() {
        let text = r#"#requirement("ctx-expect", priority: "shall")[body]"#;
        let parsed = typst_syntax::parse(text);
        // Find the FuncCall node
        let ops = vec![DeltaOp {
            action: DeltaAction::Modified,
            id: "ctx-expect".into(),
            content: Some("#requirement(\"ctx-expect\")[modified]".into()),
        }];
        let (result, changes) = apply_ops(&parsed, &ops);
        assert_eq!(changes, 1);
        assert!(result.into_text().contains("modified"));
    }

    #[test]
    fn test_no_match_returns_unchanged() {
        let text = r#"#requirement("other", priority: "shall")[body]"#;
        let parsed = typst_syntax::parse(text);
        let ops = vec![DeltaOp {
            action: DeltaAction::Modified,
            id: "nonexistent".into(),
            content: Some("[new]".into()),
        }];
        let (result, changes) = apply_ops(&parsed, &ops);
        assert_eq!(changes, 0);
        assert!(result.into_text().contains("other"));
    }
}
