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
    pub modifies: Option<String>,
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
    // Check if this is a FuncCall for requirement("id"...)
    if node.kind() == SyntaxKind::FuncCall {
        if let Some(funcall) = ast::FuncCall::from_untyped(node) {
            // Check callee is "requirement"
            let callee = funcall.callee();
            if let Some(ident) = ast::Ident::from_untyped(callee.to_untyped()) {
                if ident.as_str() != "requirement" {
                    return recurse_children(node, id);
                }
            } else {
                return recurse_children(node, id);
            }

            // Check first positional arg matches id by walking untyped children
            let id_match = find_first_str_in_children(node)
                .and_then(|s| {
                    let text = s.into_text().to_string();
                    Some(text.trim_matches('"').to_string())
                })
                .map(|s| s == id)
                .unwrap_or(false);

            if !id_match {
                return recurse_children(node, id);
            }

            // Find the body content block: it's a ContentBlock child of the FuncCall
            for child in node.children() {
                if child.kind() == SyntaxKind::ContentBlock {
                    let body_text = child.clone().into_text().to_string();
                    if let Some(inner) = body_text.strip_prefix('[')
                        .and_then(|s| s.strip_suffix(']')) {
                        return Some(inner.trim().to_string());
                    }
                    if body_text.len() >= 2 {
                        return Some(body_text[1..body_text.len()-1].trim().to_string());
                    }
                }
            }
        }
    }

    recurse_children(node, id)
}

/// Recurse into children to find the function call.
fn recurse_children<'a>(node: &'a SyntaxNode, id: &str) -> Option<String> {
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

    // Extract the requirement ID from the first positional argument via AST
    // Walk the FuncCall's untyped children to find the first string argument
    for child in node.children() {
        if child.kind() == SyntaxKind::Str {
            let text = child.clone().into_text().to_string();
            // Strip quotes
            let id = text.trim_matches('"');
            return ops.iter().find(|op| op.id == id);
        }
        // Also recurse into the args area to find nested Str nodes
        if child.kind() == SyntaxKind::Args {
            for arg_child in child.children() {
                if let Some(str_node) = find_first_str_in_children(arg_child) {
                    let text = str_node.into_text().to_string();
                    let id = text.trim_matches('"');
                    return ops.iter().find(|op| op.id == id);
                }
            }
        }
    }

    None
}

/// Find the first Str leaf node in a subtree (recursive, depth-first).
fn find_first_str_in_children(node: &SyntaxNode) -> Option<SyntaxNode> {
    if node.kind() == SyntaxKind::Str {
        return Some(node.clone());
    }
    for child in node.children() {
        if let Some(found) = find_first_str_in_children(child) {
            return Some(found);
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
            modifies: None,
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
            modifies: None,
            content: Some("[new]".into()),
        }];
        let (result, changes) = apply_ops(&parsed, &ops);
        assert_eq!(changes, 0);
        assert!(result.into_text().contains("other"));
    }
}
