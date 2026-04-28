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

        let content = match action {
            DeltaAction::Added => None,
            DeltaAction::Modified => None,
            DeltaAction::Removed => None,
        };

        ops.push(DeltaOp { action, id, content });
    }

    ops
}
