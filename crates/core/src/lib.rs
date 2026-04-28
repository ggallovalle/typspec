//! typspec core library.
//!
//! Provides:
//! - Config parsing (`typspec.jsonc`)
//! - Metadata types for requirements, scenarios, decisions, tasks
//! - AST surgery for spec-delta merging
//! - Archive orchestration

pub mod config;
pub mod metadata;
pub mod surgery;

use std::path::Path;
use surgery::SurgeryResult;

/// Run the full archive flow:
/// 1. Read the change file
/// 2. Extract spec-delta metadata
/// 3. Apply deltas to target spec files
/// 4. Return the modified spec sources
pub fn archive_change(
    change_path: &Path,
    spec_paths: &[(&str, &Path)],
) -> Result<Vec<SurgeryResult>, String> {
    // TODO: parse change file with typst query
    // TODO: extract metadata, find requirements with action
    // TODO: for each target spec, apply deltas via surgery
    // TODO: handle git SHA conflict detection
    todo!()
}
