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
    let (modified, changes) = apply_ops(&root, operations);

    Ok(SurgeryResult {
        source: modified.into_text().to_string(),
        changes,
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

/// Check if a FuncCall node matches any operation's requirement ID.
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
