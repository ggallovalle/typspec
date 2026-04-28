use std::collections::HashMap;
use std::path::{Path, PathBuf};
use serde::Deserialize;

/// A typspec workspace entry — how to find another package's specs.
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum WorkspaceEntry {
    Path { path: PathBuf },
    Git { git: String, tag: Option<String>, commit: Option<String>, subpath: Option<PathBuf> },
    Registry { registry: String, package: String, version: String },
}

/// The top-level typspec project config.
#[derive(Debug, Clone, Deserialize)]
pub struct ProjectConfig {
    pub name: String,
    #[serde(default)]
    pub version: Option<String>,
}

/// The full `typspec.jsonc` schema.
#[derive(Debug, Clone, Default, Deserialize)]
pub struct TypspecConfig {
    #[serde(default)]
    pub typspec: Option<String>,

    #[serde(default)]
    pub project: Option<ProjectConfig>,

    #[serde(default)]
    pub workspaces: HashMap<String, WorkspaceEntry>,

    #[serde(default)]
    pub exports: HashMap<String, String>,

    #[serde(default)]
    pub bibliographies: Vec<String>,

    #[serde(default)]
    pub context: Option<HashMap<String, String>>,
}

/// Config filenames in discovery order (first-match wins within a directory).
const CONFIG_FILENAMES: &[&str] = &[
    "typspec.jsonc", "typspec.json",
    "typspec/config.jsonc", "typspec/config.json",
    ".config/typspec.jsonc", ".config/typspec.json",
    ".config/typspec/typspec.jsonc", ".config/typspec/typspec.json",
];

/// Local override filenames (git-ignored, higher precedence).
const LOCAL_FILENAMES: &[&str] = &[
    "typspec.local.jsonc", "typspec.local.json",
    "typspec/config.local.jsonc", "typspec/config.local.json",
    ".config/typspec.local.jsonc", ".config/typspec.local.json",
    ".config/typspec/typspec.local.jsonc", ".config/typspec/typspec.local.json",
];

/// User global config paths.
const GLOBAL_FILENAMES: &[&str] = &[
    "config.jsonc", "config.json",
];

/// Discover and load a typspec config by walking up from `cwd`.
/// Merges project configs (child overrides parent), then applies user global config.
pub fn load_config(cwd: &Path) -> Result<TypspecConfig, String> {
    // Walk up from cwd collecting project configs
    let mut merged = TypspecConfig::default();

    if let Ok(dirs) = walk_up_dirs(cwd) {
        for dir in dirs {
            // Load config files in order, merge
            for filename in CONFIG_FILENAMES.iter().chain(LOCAL_FILENAMES.iter()) {
                let path = dir.join(filename);
                if path.exists() {
                    match parse_config_file(&path) {
                        Ok(cfg) => merge_configs(&mut merged, cfg),
                        Err(e) => eprintln!("warning: failed to parse {}: {}", path.display(), e),
                    }
                }
            }
        }
    }

    // Apply user global config as base
    if let Some(home) = std::env::var_os("HOME").map(PathBuf::from) {
        let global_dir = home.join(".config").join("typspec");
        for filename in GLOBAL_FILENAMES {
            let path = global_dir.join(filename);
            if path.exists() {
                if let Ok(cfg) = parse_config_file(&path) {
                    merge_configs(&mut merged, cfg);
                }
            }
        }
    }

    Ok(merged)
}

/// Walk up from `start` to the filesystem root.
fn walk_up_dirs(start: &Path) -> Result<Vec<PathBuf>, String> {
    let mut dirs = Vec::new();
    let mut current = Some(start.to_path_buf());

    while let Some(dir) = current {
        dirs.push(dir.clone());
        current = dir.parent().map(|p| p.to_path_buf());
    }

    Ok(dirs)
}

/// Parse a single JSON or JSONC config file.
fn parse_config_file(path: &Path) -> Result<TypspecConfig, String> {
    let text = std::fs::read_to_string(path)
        .map_err(|e| format!("cannot read {}: {}", path.display(), e))?;

    let is_jsonc = path.extension()
        .map(|ext| ext == "jsonc")
        .unwrap_or(false);

    if is_jsonc {
        // Strip comments and trailing commas for JSONC
        let cleaned = strip_jsonc_comments(&text);
        serde_json::from_str(&cleaned)
            .map_err(|e| format!("parse error in {}: {}", path.display(), e))
    } else {
        serde_json::from_str(&text)
            .map_err(|e| format!("parse error in {}: {}", path.display(), e))
    }
}

/// Strip // and /* */ comments and trailing commas from JSONC text.
fn strip_jsonc_comments(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();

    while let Some(c) = chars.next() {
        match c {
            '/' if chars.peek() == Some(&'/') => {
                while let Some(&c) = chars.peek() {
                    if c == '\n' { break; }
                    chars.next();
                }
            }
            '/' if chars.peek() == Some(&'*') => {
                chars.next();
                while let Some(c) = chars.next() {
                    if c == '*' && chars.peek() == Some(&'/') {
                        chars.next();
                        break;
                    }
                }
            }
            _ => out.push(c),
        }
    }

    // Remove trailing commas with depth tracking
    let mut result = String::with_capacity(out.len());
    let bytes = out.as_bytes();
    let mut i = 0;

    while i < bytes.len() {
        if bytes[i] == b',' {
            // Look ahead past whitespace for a closing bracket
            let mut j = i + 1;
            while j < bytes.len() && (bytes[j] == b' ' || bytes[j] == b'\t' || bytes[j] == b'\n' || bytes[j] == b'\r') {
                j += 1;
            }
            if j < bytes.len() && (bytes[j] == b'}' || bytes[j] == b']') {
                // Skip this comma — it's a trailing comma
                i += 1;
                continue;
            }
        }
        result.push(bytes[i] as char);
        i += 1;
    }

    result
}

/// Merge `child` into `base` (child fields override base). Shallow merge for top-level fields.
fn merge_configs(base: &mut TypspecConfig, child: TypspecConfig) {
    if child.typspec.is_some() { base.typspec = child.typspec; }
    if child.project.is_some() { base.project = child.project; }
    if !child.workspaces.is_empty() { base.workspaces = child.workspaces; }
    if !child.exports.is_empty() { base.exports = child.exports; }
    if !child.bibliographies.is_empty() { base.bibliographies = child.bibliographies; }
    if child.context.is_some() { base.context = child.context; }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_strip_jsonc_comments() {
        let input = r#"{
            // line comment
            "key": "value",
            /* block comment */
            "arr": [1, 2, 3,],
        }"#;
        let result = strip_jsonc_comments(input);
        let parsed: TypspecConfig = serde_json::from_str(&result).unwrap();
        assert!(parsed.project.is_none());
    }

    #[test]
    fn test_parse_valid_config() {
        let json = r#"{
            "project": { "name": "test" },
            "bibliographies": ["refs.yaml"]
        }"#;
        let cfg: TypspecConfig = serde_json::from_str(json).unwrap();
        assert_eq!(cfg.project.unwrap().name, "test");
    }
}
