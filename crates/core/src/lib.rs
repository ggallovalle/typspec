//! typspec core library.
//!
//! Provides:
//! - Config parsing (`typspec.jsonc`)
//! - Metadata types for requirements, scenarios, decisions, tasks
//! - AST surgery for spec-delta merging
//! - Fuzzy matching for "did you mean" suggestions
//! - Archive orchestration

pub mod config;
pub mod fuzzy;
pub mod metadata;
pub mod surgery;

use std::collections::HashMap;
use std::path::Path;
use surgery::{DeltaOp, DeltaAction, SurgeryResult};

/// Run the archive merge for a set of spec-delta operations.
///
/// `spec_deltas` maps spec file paths to lists of delta operations extracted
/// from a change document. For each spec file, the operations are applied in
/// order via AST surgery.
///
/// Returns a map from spec file path to surgery result.
pub fn apply_spec_deltas(
    spec_deltas: &HashMap<String, Vec<DeltaOp>>,
) -> Result<HashMap<String, SurgeryResult>, String> {
    let mut results = HashMap::new();

    for (spec_path, ops) in spec_deltas {
        let path = Path::new(spec_path);
        if !path.exists() {
            return Err(format!("spec file not found: {}", spec_path));
        }

        let result = surgery::apply_deltas(path, ops)?;
        results.insert(spec_path.clone(), result);
    }

    Ok(results)
}

/// Write surgery results back to disk.
pub fn write_results(results: &HashMap<String, SurgeryResult>) -> Result<(), String> {
    for (path, result) in results {
        if result.changes > 0 {
            std::fs::write(path, &result.source)
                .map_err(|e| format!("failed to write {}: {}", path, e))?;
        }
    }
    Ok(())
}

/// Parse the `modifies` field from a change document's metadata.
/// Returns spec file IDs (e.g., "module-api", "cli").
pub fn parse_modifies(value: &serde_json::Value) -> Vec<String> {
    if let Some(arr) = value.as_array() {
        arr.iter()
            .filter_map(|v| v.as_str().map(|s| s.to_string()))
            .collect()
    } else if let Some(s) = value.as_str() {
        vec![s.to_string()]
    } else {
        vec![]
    }
}

/// Convert `typspec:requirement` metadata entries into `DeltaOp`s.
/// Also extracts the requirement's `modifies` field (optional target spec).
pub fn metadata_to_delta_ops(entries: &[serde_json::Value]) -> Vec<DeltaOp> {
    let mut ops = Vec::new();

    for entry in entries {
        let kind = entry["kind"].as_str().unwrap_or("");
        if kind != "typspec:requirement" { continue; }

        let action = match entry["action"].as_str() {
            Some("added") => DeltaAction::Added,
            Some("modified") => DeltaAction::Modified,
            Some("removed") => DeltaAction::Removed,
            _ => continue,
        };

        let id = entry["id"].as_str().unwrap_or("").to_string();
        let modifies = entry["modifies"].as_str().map(|s| s.to_string());

        let content = match action {
            DeltaAction::Added => None,
            DeltaAction::Modified => None,
            DeltaAction::Removed => None,
        };

        ops.push(DeltaOp { action, id, modifies, content });
    }

    ops
}

/// Group delta ops by target spec.
///
/// For each op:
/// - If `modifies` is set, route to that spec file.
/// - If `modifies` is None and change_modifies has 1 spec, route to that spec.
/// - If `modifies` is None and change_modifies has >1 specs, error.
///
/// Returns a map of spec file paths to delta ops, and a list of validation errors.
pub fn group_delta_ops_by_spec(
    ops: &[DeltaOp],
    change_modifies: &[String],
    spec_dir: &Path,
) -> (HashMap<String, Vec<DeltaOp>>, Vec<String>) {
    let mut deltas: HashMap<String, Vec<DeltaOp>> = HashMap::new();
    let mut errors: Vec<String> = Vec::new();

    for op in ops {
        let target = match &op.modifies {
            Some(spec_name) => spec_name.clone(),
            None => {
                if change_modifies.len() == 1 {
                    change_modifies[0].clone()
                } else {
                    let available = change_modifies.iter().map(|s| format!("'{}'", s)).collect::<Vec<_>>().join(", ");
                    errors.push(format!(
                        "requirement '{}' is missing `modifies` — change targets multiple specs ({})",
                        op.id, available
                    ));
                    continue;
                }
            }
        };

        // Validate that target is in change_modifies
        if !change_modifies.contains(&target) {
            let available = change_modifies.iter().map(|s| format!("'{}'", s)).collect::<Vec<_>>().join(", ");
            errors.push(format!(
                "requirement '{}' targets '{}' which is not in change's modifies. Available: {}",
                op.id, target, available
            ));
            continue;
        }

        // Check spec file exists
        let spec_file = format!("{}.typ", target);
        let spec_path = spec_dir.join(&spec_file);
        if !spec_path.exists() {
            errors.push(format!("spec '{}' not found at {}", target, spec_path.display()));
            continue;
        }

        deltas.entry(spec_path.to_string_lossy().to_string())
            .or_default()
            .push(op.clone());
    }

    (deltas, errors)
}
