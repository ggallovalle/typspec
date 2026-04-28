#![allow(dead_code)]

use std::path::{Path, PathBuf};
use clap::{CommandFactory, Parser, Subcommand, ValueEnum};

mod core;
mod skills;

/// typspec — structured specification management powered by Typst.
#[derive(Parser, Debug)]
#[command(name = "typspec", version, about)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Machine-readable JSON output
    #[arg(global = true, long)]
    json: bool,

    /// Preview actions without executing (implies -vv)
    #[arg(global = true, long)]
    dry_run: bool,

    /// Verbosity: -v = warning, -vv = info, -vvv = debug
    #[arg(global = true, short, action = clap::ArgAction::Count)]
    verbose: u8,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Scaffold a new typspec project
    Init {
        /// Target directory (default: current directory)
        path: Option<PathBuf>,
        /// AI tools to generate skills for (comma-separated: claude,codex,opencode; all, none)
        #[arg(long)]
        tools: Option<String>,
    },
    /// Create a new spec or change file
    New {
        #[command(subcommand)]
        kind: NewKind,
    },
    /// List specs or changes
    #[command(alias = "ls")]
    List {
        /// Show specs instead of changes
        #[arg(long)]
        specs: bool,
        /// Output bare names for shell completion (hidden)
        #[arg(long, hide = true)]
        complete: bool,
        /// Include archive names in listing
        #[arg(long)]
        all: bool,
    },
    /// Display metadata from a spec or change
    Status {
        /// Name of the spec or change
        name: String,
    },
    /// Compile a .typ file to PDF
    Render {
        /// File to render
        path: Option<PathBuf>,
        /// Auto-recompile on changes
        #[arg(short, long)]
        watch: bool,
    },
    /// Archive a completed change
    Archive {
        /// Change name to archive
        #[arg(value_name = "CHANGE_NAME")]
        change_name: String,
        /// Skip confirmation
        #[arg(short, long)]
        yes: bool,
    },
    /// Validate a .typ file's structure
    Validate {
        /// File to validate
        path: Option<PathBuf>,
    },
    /// Fetch workspace dependencies
    Install,
    /// Locate a file by name across specs, changes, and archive
    Which {
        /// Name of the spec, change, or archived change
        #[arg(value_name = "TARGET")]
        target: String,
    },
    /// Generate usage spec for shell completions (hidden)
    #[command(hide = true)]
    Usage,
    /// Generate JSON Schema for typspec.jsonc (hidden)
    #[command(hide = true)]
    Schema,
    /// Generate shell completion scripts
    Completion {
        /// Shell to generate completions for
        #[arg(value_enum)]
        shell: ShellKind,
    },
}

#[derive(ValueEnum, Clone, Debug)]
enum ShellKind {
    Zsh,
}

#[derive(Subcommand, Debug)]
enum NewKind {
    /// Create a new spec file
    Spec {
        /// Spec name
        name: String,
    },
    /// Create a new change file
    Change {
        /// Change name
        name: String,
    },
}

fn main() {
    let cli = Cli::parse();

    let log_level = match cli.verbose {
        0 => "error",
        1 => "warning",
        2 => "info",
        _ => "debug",
    };
    // SAFETY: single-threaded startup, no concurrent access
    unsafe { std::env::set_var("TYPSPEC_LOG", log_level); }

    if cli.dry_run {
        eprintln!("[dry-run] would execute: {:?}", cli.command);
        return;
    }

    match &cli.command {
        Commands::Init { path, tools } => cmd_init(path.as_deref(), cli.json, tools.as_deref()),
        Commands::New { kind } => cmd_new(kind, cli.json),
        Commands::List { specs, complete, all } => cmd_list(*specs, *complete, *all, cli.json),
        Commands::Status { name } => cmd_status(name, cli.json),
        Commands::Render { path, watch } => cmd_render(path.as_deref(), *watch),
        Commands::Archive { change_name, yes } => cmd_archive(change_name, *yes, cli.json),
        Commands::Validate { path } => cmd_validate(path.as_deref()),
        Commands::Install => cmd_install(),
        Commands::Which { target } => cmd_which(target, cli.json),
        Commands::Usage => cmd_usage(),
        Commands::Schema => cmd_schema(),
        Commands::Completion { shell } => cmd_completion(shell),
    }
}

fn cmd_init(path: Option<&Path>, json: bool, tools: Option<&str>) {
    let dir = path.unwrap_or_else(|| Path::new("."));
    let typspec_dir = dir.join("typspec");
    let specs_dir = typspec_dir.join("specs");
    let changes_dir = typspec_dir.join("changes");
    let archive_dir = typspec_dir.join("archive");
    let bibliographies_dir = typspec_dir.join("bibliographies");
    let config_path = typspec_dir.join("typspec.jsonc");

    std::fs::create_dir_all(&specs_dir).expect("failed to create specs dir");
    std::fs::create_dir_all(&changes_dir).expect("failed to create changes dir");
    std::fs::create_dir_all(&archive_dir).expect("failed to create archive dir");
    std::fs::create_dir_all(&bibliographies_dir).expect("failed to create bibliographies dir");

    let example_yaml = bibliographies_dir.join("example.yaml");
    if !example_yaml.exists() {
        let content = r#"# Hayagriva bibliography file
# https://github.com/typst/hayagriva/blob/main/docs/file-format.md
# JSON Schema tracking: https://github.com/typst/hayagriva/issues/33
#
# Replace this file with your own bibliography entries.
# Reference it from your .typ files with:
#   #bibliography("typspec/bibliographies/<your-file>.yaml")

example-book:
  type: Book
  title: Example Book Title
  author: Author, Jane
  date: 2024
  publisher: Example Press
"#;
        std::fs::write(&example_yaml, content).expect("failed to write example.yaml");
    }

    if !config_path.exists() {
        let config = r#"{
  "$schema": "https://raw.githubusercontent.com/ggallovalle/typspec/main/assets/typspec.schema.json",
  "project": {
    "name": "my-project",
    "version": "0.1.0"
  }
}"#;
        std::fs::write(&config_path, config).expect("failed to write config");
    }

    // Generate AI agent skills if --tools flag provided
    if let Some(tools_str) = tools {
        generate_tool_skills(tools_str, dir, json);
    }

    if json {
        println!(r#"{{"created": ["specs", "changes", "archive", "bibliographies", "typspec/typspec.jsonc"]}}"#);
    } else {
        println!("✓ Initialized typspec project at {}", dir.display());
        println!("  {}/", specs_dir.display());
        println!("  {}/", changes_dir.display());
        println!("  {}/", archive_dir.display());
        println!("  {}/", bibliographies_dir.display());
        println!("  {}", config_path.display());
    }
}

fn cmd_new(kind: &NewKind, json: bool) {
    match kind {
        NewKind::Spec { name } => create_spec(name, json),
        NewKind::Change { name } => create_change(name, json),
    }
}

fn create_spec(name: &str, json: bool) {
    let paths = resolve_project_paths().unwrap_or_else(|e| {
        eprintln!("error: {}", e); std::process::exit(1);
    });
    let spec_file = format!("{}.typ", name);
    let path = paths.specs.join(&spec_file);

    let template = format!(
        r#"#show: spec.with(title: "{}")

= {}

== Requirement 1

#requirement("req-1", priority: "shall")[
  Description of what the system SHALL do.

  #scenario("scenario name",
    when: [action],
    then: [expected result],
  )
]
"#, name, name
    );

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("failed to create specs dir");
    }
    std::fs::write(&path, &template).expect("failed to write spec");

    if json {
        println!(r#"{{"created": "{}"}}"#, path.display());
    } else {
        println!("✓ Created spec: {}", path.display());
    }
}

fn create_change(name: &str, json: bool) {
    let paths = resolve_project_paths().unwrap_or_else(|e| {
        eprintln!("error: {}", e); std::process::exit(1);
    });
    let change_file = format!("{}.typ", name);
    let path = paths.changes.join(&change_file);

    let template = format!(
        r#"#show: change.with(id: "{}")

= Proposal

== Motivation

Why is this change needed?

== Scope

What is and isn't changing.

= Design

#decision(
  "Decision title",
  rationale: [Why this approach.],
)

= Spec Deltas

== ADDED Requirements

#requirement("new-req", priority: "shall", action: "added")[
  Description.

  #scenario("name",
    when: [action],
    then: [result],
  )
]

= Tasks

#task_group("Implementation", (
  task([Do the thing], done: false),
))
"#, name
    );

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("failed to create changes dir");
    }
    std::fs::write(&path, &template).expect("failed to write change");

    if json {
        println!(r#"{{"created": "{}"}}"#, path.display());
    } else {
        println!("✓ Created change: {}", path.display());
    }
}

fn cmd_list(specs: bool, complete: bool, all: bool, json: bool) {
    let paths = resolve_project_paths().unwrap_or_else(|e| {
        eprintln!("error: {}", e); std::process::exit(1);
    });
    let cwd = std::env::current_dir().unwrap_or_default();

    let dirs: Vec<&PathBuf> = if all {
        vec![&paths.specs, &paths.changes, &paths.archive]
    } else if specs {
        vec![&paths.specs]
    } else {
        vec![&paths.changes]
    };

    let mut entries: Vec<(String, PathBuf)> = Vec::new();
    for (dir_idx, dir) in dirs.iter().enumerate() {
        if let Ok(dir_entries) = std::fs::read_dir(dir) {
            for entry in dir_entries.flatten() {
                if entry.path().extension().map(|ext| ext == "typ").unwrap_or(false) {
                    let path = entry.path();
                    let stem = path.file_stem().unwrap().to_string_lossy().to_string();
                    let name = if dir_idx == 2 && stem.len() > 11 {
                        // Archive: strip YYYY-MM-DD- prefix
                        stem[11..].to_string()
                    } else {
                        stem
                    };
                    entries.push((name, path));
                }
            }
        }
    }

    if complete {
        for (name, _) in &entries {
            println!("{}", name);
        }
        return;
    }

    if json {
        let items: Vec<serde_json::Value> = entries.iter()
            .map(|(name, path)| {
                let rel = path.strip_prefix(&cwd).unwrap_or(path);
                serde_json::json!({"name": name, "path": rel.to_string_lossy()})
            })
            .collect();
        println!("{}", serde_json::to_string(&items).unwrap());
    } else {
        for (name, path) in &entries {
            let rel = path.strip_prefix(&cwd).unwrap_or(path);
            println!("  {} ({})", name, rel.to_string_lossy());
        }
        if entries.is_empty() {
            let label = if all { "specs, changes, or archive" } else if specs { "specs" } else { "changes" };
            println!("  (no {} found)", label);
        }
    }
}

fn cmd_status(name: &str, json: bool) {
    let paths = resolve_project_paths().unwrap_or_else(|e| {
        eprintln!("error: {}", e); std::process::exit(1);
    });
    let spec_path = paths.specs.join(format!("{}.typ", name));
    let change_path = paths.changes.join(format!("{}.typ", name));

    let target = if spec_path.exists() {
        spec_path
    } else if change_path.exists() {
        change_path.clone()
    } else {
        eprintln!("error: '{}' not found in {}/ or {}/", name, paths.specs.display(), paths.changes.display());
        suggest_name(name, &[paths.specs, paths.changes]);
        std::process::exit(1);
    };

    let root = find_project_root().unwrap_or_else(|| PathBuf::from("."));
    let output = std::process::Command::new("typst")
        .args(["query", "--root", &root.to_string_lossy(), &target.to_string_lossy(), "metadata", "--field", "value"])
        .output()
        .expect("failed to run typst query");

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        eprintln!("error: typst query failed: {}", stderr);
        std::process::exit(1);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);

    if json {
        println!("{}", stdout);
    } else {
        let entries: Vec<serde_json::Value> = serde_json::from_str(&stdout).unwrap_or_default();
        let req_count = entries.iter().filter(|v| v["kind"] == "typspec:requirement").count();
        let task_count = entries.iter().filter(|v| v["kind"] == "typspec:task").count();
        let task_done = entries.iter().filter(|v| v["kind"] == "typspec:task" && v["done"] == true).count();
        let scenario_count = entries.iter().filter(|v| v["kind"] == "typspec:scenario").count();

        println!("Status: {}", name);
        println!("  Requirements: {}", req_count);
        println!("  Scenarios: {}", scenario_count);
        println!("  Tasks: {}/{} complete", task_done, task_count);
        println!();

        // Read change file source to extract task descriptions
        let task_descriptions = if change_path.exists() {
            std::fs::read_to_string(&change_path)
                .ok()
                .map(|text| crate::core::surgery::extract_task_bodies(&text))
                .unwrap_or_default()
        } else {
            vec![]
        };
        let mut task_idx = 0usize;

        for entry in &entries {
            let kind = entry["kind"].as_str().unwrap_or("");
            match kind {
                "typspec:requirement" => {
                    let id = entry["id"].as_str().unwrap_or("");
                    let action = entry["action"].as_str().unwrap_or("active");
                    println!("  [req] {} ({})", id, action);
                }
                "typspec:task" => {
                    let done = entry["done"].as_bool().unwrap_or(false);
                    let assignee = entry["assignee"].as_str().map(|a| format!(" @{}", a)).unwrap_or_default();
                    let mark = if done { "[x]" } else { "[ ]" };
                    let desc = task_descriptions.get(task_idx)
                        .and_then(|d| d.as_deref())
                        .unwrap_or("(no description)");
                    task_idx += 1;
                    println!("  {} {}{}", mark, desc, assignee);
                }
                "typspec:decision" => {
                    let title = entry["title"].as_str().unwrap_or("");
                    println!("  [dec] {}", title);
                }
                _ => {}
            }
        }
    }
}

fn cmd_render(path: Option<&Path>, watch: bool) {
    let target = match path {
        Some(p) => p.to_path_buf(),
        None => find_latest_typ_file(),
    };

    let output = target.with_extension("pdf");

    let root = find_project_root().unwrap_or_else(|| PathBuf::from("."));
    let mut cmd = std::process::Command::new("typst");
    cmd.args(["compile", "--root", &root.to_string_lossy(), &target.to_string_lossy(), &output.to_string_lossy()]);
    if watch {
        cmd.arg("--watch");
    }

    let status = cmd.status().expect("failed to run typst");

    if !status.success() {
        std::process::exit(status.code().unwrap_or(1));
    }
}

fn find_latest_typ_file() -> PathBuf {
    let paths = resolve_project_paths().unwrap_or_else(|e| {
        eprintln!("error: {}", e); std::process::exit(1);
    });
    let candidates = [paths.specs, paths.changes];
    let mut latest: Option<PathBuf> = None;
    let mut latest_time = std::time::SystemTime::UNIX_EPOCH;

    for dir in &candidates {
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                if entry.path().extension().map(|e| e == "typ").unwrap_or(false) {
                    if let Ok(metadata) = entry.metadata() {
                        if let Ok(modified) = metadata.modified() {
                            if modified > latest_time {
                                latest_time = modified;
                                latest = Some(entry.path());
                            }
                        }
                    }
                }
            }
        }
    }

    latest.unwrap_or_else(|| {
        eprintln!("error: no .typ files found. Specify a path or create one first.");
        std::process::exit(1);
    })
}

fn cmd_archive(change_name: &str, _yes: bool, json: bool) {
    let paths = resolve_project_paths().unwrap_or_else(|e| {
        eprintln!("error: {}", e); std::process::exit(1);
    });
    let change_path = paths.changes.join(format!("{}.typ", change_name));

    if !change_path.exists() {
        eprintln!("error: change '{}' not found at {}", change_name, change_path.display());
        suggest_name(change_name, &[paths.changes.clone()]);
        std::process::exit(1);
    }

    // Query the change file for metadata
    let output = std::process::Command::new("typst")
        .args(["query", "--root", &paths.root.to_string_lossy(), &change_path.to_string_lossy(), "metadata", "--field", "value"])
        .output()
        .expect("failed to run typst query");

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        eprintln!("error: typst query failed: {}", stderr);
        std::process::exit(1);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let entries: Vec<serde_json::Value> = serde_json::from_str(&stdout).unwrap_or_default();

    // Find the change metadata
    let change_meta = entries.iter().find(|v| v["kind"] == "typspec:change");
    let modifies = change_meta
        .and_then(|m| m["modifies"].as_array())
        .map(|a| a.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect::<Vec<_>>())
        .unwrap_or_default();

    // Find spec-delta requirements
    let mut delta_ops = crate::core::metadata_to_delta_ops(&entries);

    // Extract requirement bodies from the change file source
    if let Ok(change_text) = std::fs::read_to_string(&change_path) {
        for op in &mut delta_ops {
            if op.content.is_none() {
                if let Some(body) = crate::core::surgery::extract_requirement_body(&change_text, &op.id) {
                    op.content = Some(format!(
                        "#requirement(\"{}\", priority: \"shall\")[\n{}\n]\n",
                        op.id, body
                    ));
                }
            }
        }
    }

    // Check for git conflicts — warn if spec files have uncommitted changes
    for spec_name in &modifies {
        let spec_file = paths.specs.join(format!("{}.typ", spec_name));
        if spec_file.exists() {
            check_git_conflict(&spec_file, json);
        }
    }

    // Group delta ops by target spec using modifies field
    let (spec_deltas, validation_errors) = crate::core::group_delta_ops_by_spec(
        &delta_ops, &modifies, &paths.specs,
    );

    // Print validation errors
    for err in &validation_errors {
        eprintln!("warning: {}", err);
    }

    // Apply deltas
    if !spec_deltas.is_empty() {
        if json {
            println!(r#"{{"applying_deltas": {}}}"#, serde_json::to_string(&modifies).unwrap());
        } else {
            println!("Applying spec-deltas to: {:?}", modifies);
        }

        match crate::core::apply_spec_deltas(&spec_deltas) {
            Ok(results) => {
                let total_changes: usize = results.values().map(|r| r.changes).sum();
                if total_changes > 0 {
                    for (path, result) in &results {
                        println!("  → {} ({} change(s))", path, result.changes);
                    }
                    crate::core::write_results(&results).unwrap_or_else(|e| {
                        eprintln!("error writing changes: {}", e);
                    });
                } else {
                    println!("  (no matching requirements with action found)");
                }
            }
            Err(e) => {
                eprintln!("error applying deltas: {}", e);
            }
        }
    } else if !modifies.is_empty() {
        println!("Info: change modifies {:?} but no spec-deltas found", modifies);
        println!("  (requirements must have `action:` set to be processed)");
    }

    // Move change to archive
    std::fs::create_dir_all(&paths.archive).expect("failed to create archive dir");

    let today = today_date();
    let archived_name = format!("{}-{}", today, change_name);
    let dest = paths.archive.join(format!("{}.typ", archived_name));

    // Use git mv when tracked, fs::rename otherwise
    git_mv_or_rename(&change_path, &dest);

    if json {
        println!(r#"{{"archived": "{}"}}"#, dest.display());
    } else {
        println!("✓ Archived {} → {}", change_name, dest.display());
    }
}

fn cmd_validate(path: Option<&Path>) {
    let target = path.unwrap_or_else(|| Path::new("."));
    let root = find_project_root().unwrap_or_else(|| PathBuf::from("."));

    let status = std::process::Command::new("typst")
        .args(["compile", "--root", &root.to_string_lossy(), &target.to_string_lossy()])
        .arg("--format=pdf")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped())
        .status()
        .expect("failed to run typst");

    if status.success() {
        println!("✓ {} is valid", target.display());
    } else {
        std::process::exit(status.code().unwrap_or(1));
    }
}

fn cmd_install() {
    // Load config and find git workspace dependencies
    match crate::core::config::load_config(Path::new(".")) {
        Ok(cfg) => {
            let mut found = false;
            for (name, entry) in &cfg.workspaces {
                match entry {
                    crate::core::config::WorkspaceEntry::Git { git, tag, commit, subpath: _ } => {
                        found = true;
                        let cache_dir = PathBuf::from(".typspec")
                            .join("cache")
                            .join("workspaces")
                            .join(name);

                        if cache_dir.exists() {
                            println!("  ✓ {} (cached)", name);
                            continue;
                        }

                        let ref_spec = tag.as_ref()
                            .map(|t| format!("refs/tags/{}", t))
                            .or_else(|| commit.clone());

                        std::fs::create_dir_all(&cache_dir).expect("failed to create cache dir");

                        let mut cmd = std::process::Command::new("git");
                        cmd.args(["clone", "--depth", "1"]);
                        if let Some(ref_spec) = &ref_spec {
                            if tag.is_some() {
                                cmd.arg("--branch");
                            }
                            cmd.arg(ref_spec);
                        }
                        cmd.arg(git).arg(&cache_dir);

                        let status = cmd.status().expect("failed to run git clone");
                        if status.success() {
                            println!("  ✓ {} cloned to {}", name, cache_dir.display());
                        } else {
                            eprintln!("  ✗ failed to clone {}", name);
                        }
                    }
                    _ => {}
                }
            }
            if !found {
                println!("No git workspace dependencies found in config.");
            }
        }
        Err(e) => {
            eprintln!("error: failed to load config: {}", e);
        }
    }
}

/// Locate a file by name across specs, changes, and archive directories.
fn cmd_which(target: &str, json: bool) {
    let paths = match resolve_project_paths() {
        Ok(p) => p,
        Err(e) => {
            eprintln!("error: {}", e);
            std::process::exit(1);
        }
    };

    // Search in order: specs → changes → archive
    let dirs = [&paths.specs, &paths.changes, &paths.archive];
    let file_name = format!("{}.typ", target);

    for (i, dir) in dirs.iter().enumerate() {
        if i == 2 {
            // Archive files have date prefixes: YYYY-MM-DD-<name>.typ
            // Match by suffix
            if let Ok(entries) = std::fs::read_dir(dir) {
                for entry in entries.flatten() {
                    let p = entry.path();
                    if p.extension().map(|e| e == "typ").unwrap_or(false) {
                        if let Some(stem) = p.file_stem() {
                            let stem = stem.to_string_lossy();
                            if stem.ends_with(&format!("-{}", target)) || stem == target {
                                let cwd = std::env::current_dir().unwrap_or_default();
                                let rel = p.strip_prefix(&cwd).unwrap_or(&p);
                                if json {
                                    println!(r#"{{"name": "{}", "path": "{}"}}"#, target, rel.to_string_lossy());
                                } else {
                                    println!("{}", rel.to_string_lossy());
                                }
                                return;
                            }
                        }
                    }
                }
            }
        } else {
            let candidate = dir.join(&file_name);
            if candidate.exists() {
                let cwd = std::env::current_dir().unwrap_or_default();
                let rel = candidate.strip_prefix(&cwd).unwrap_or(&candidate);
                if json {
                    println!(r#"{{"name": "{}", "path": "{}"}}"#, target, rel.to_string_lossy());
                } else {
                    println!("{}", rel.to_string_lossy());
                }
                return;
            }
        }
    }

    // Not found — suggest alternatives
    let mut candidates: Vec<String> = Vec::new();
    for dir in &dirs {
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                if entry.path().extension().map(|e| e == "typ").unwrap_or(false) {
                    if let Some(stem) = entry.path().file_stem() {
                        candidates.push(stem.to_string_lossy().to_string());
                    }
                }
            }
        }
    }

    eprintln!("error: '{}' not found", target);
    let suggestions = crate::core::fuzzy::best_fuzzy_match(target, &candidates);
    if suggestions.len() == 1 {
        eprintln!("  tip: a similar name exists: '{}'", suggestions[0]);
    } else if suggestions.len() > 1 {
        let joined = suggestions.iter().map(|s| format!("'{}'", s)).collect::<Vec<_>>().join("' or '");
        eprintln!("  tip: a similar name exists: {}?", joined);
    }

    std::process::exit(1);
}

fn cmd_usage() {
    let mut cmd = Cli::command();
    let mut buf = Vec::new();
    clap_usage::generate(&mut cmd, "typspec", &mut buf);
    let spec = String::from_utf8(buf).unwrap_or_default();
    print!("{}", spec);

    println!(r#"complete "NAME" run="typspec list --specs --complete; typspec list --complete" descriptions=#true"#);
    println!(r#"complete "CHANGE_NAME" run="typspec list --complete""#);
    println!(r#"complete "TARGET" run="typspec list --all --complete""#);
}

fn cmd_schema() {
    let value = crate::core::config::generate_schema();
    println!("{}", serde_json::to_string_pretty(&value).unwrap());
}

fn cmd_completion(shell: &ShellKind) {
    match shell {
        ShellKind::Zsh => {
            println!("#compdef typspec");
            println!("# @generated by usage-cli from usage spec");
            println!(r#"local curcontext="$curcontext""#);
            println!();
            println!("_typspec() {{");
            println!("  typeset -A opt_args");
            println!(r#"  local curcontext="$curcontext""#);
            println!();
            println!("  if ! type -p usage &> /dev/null; then");
            println!("      echo >&2");
            println!("      echo \"Error: usage CLI not found. This is required for completions to work with typspec.\" >&2");
            println!("      echo \"See https://usage.jdx.dev for more information.\" >&2");
            println!("      return 1");
            println!("  fi");
            println!();
            println!(r#"  local spec_file="${{TMPDIR:-/tmp}}/typspec_spec""#);
            println!("  if [[ ! -f \"$spec_file\" ]]; then");
            println!("    typspec usage >| \"$spec_file\"");
            println!("  fi");
            println!("  local -a completions=()");
            println!("  while IFS= read -r line; do");
            println!("    completions+=(\"$line\")");
            println!(r#"  done < <(command usage complete-word --shell zsh -f "$spec_file" -- "${{words[@]}}")"#);
            println!("  _describe 'completions' completions -S ''");
            println!("  return 0");
            println!("}}");
            println!();
            println!(r#"if [ "$funcstack[1]" = "_typspec" ]; then"#);
            println!(r#"    _typspec "$@""#);
            println!("else");
            println!("    compdef _typspec typspec");
            println!("fi");
        }
    }
}

/// Suggest a "did you mean" name when a spec or change is not found.
fn suggest_name(input: &str, dirs: &[PathBuf]) {
    let mut candidates: Vec<String> = Vec::new();
    for dir in dirs {
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                if entry.path().extension().map(|e| e == "typ").unwrap_or(false) {
                    if let Some(name) = entry.path().file_stem() {
                        candidates.push(name.to_string_lossy().to_string());
                    }
                }
            }
        }
    }

    let suggestions = crate::core::fuzzy::best_fuzzy_match(input, &candidates);
    if suggestions.len() == 1 {
        eprintln!("  tip: a similar name exists: '{}'", suggestions[0]);
    } else if suggestions.len() > 1 {
        let joined = suggestions.iter().map(|s| format!("'{}'", s)).collect::<Vec<_>>().join("' or '");
        eprintln!("  tip: a similar name exists: {}?", joined);
    }
}

/// Canonical paths resolved from the project root.
struct ProjectPaths {
    root: PathBuf,
    specs: PathBuf,
    changes: PathBuf,
    archive: PathBuf,
    _bibliographies: PathBuf,
}

fn resolve_project_paths() -> Result<ProjectPaths, String> {
    let root = find_project_root()
        .ok_or_else(|| "no typspec project found. Run `typspec init` first.".to_string())?;
    Ok(ProjectPaths {
        specs: root.join("typspec/specs"),
        changes: root.join("typspec/changes"),
        archive: root.join("typspec/archive"),
        _bibliographies: root.join("typspec/bibliographies"),
        root,
    })
}

/// Find the project root containing `typspec/typspec.json{c}` by walking up.
/// Returns `None` if not found.
fn find_project_root() -> Option<PathBuf> {
    let home = std::env::var_os("HOME").map(PathBuf::from);
    let mut current = std::env::current_dir().ok()?;

    loop {
        for name in &["typspec/typspec.jsonc", "typspec/typspec.json"] {
            if current.join(name).exists() {
                return Some(current);
            }
        }
        // Stop at git root
        if current.join(".git").exists() {
            return None;
        }
        // Stop at home
        if let Some(ref h) = home {
            if current == *h {
                return None;
            }
        }
        // Stop at filesystem root
        if !current.pop() {
            return None;
        }
    }
}

/// Generate AI agent skills based on --tools flag.
fn generate_tool_skills(tools_str: &str, project_root: &Path, json: bool) {
    let lower = tools_str.to_lowercase();

    let selected_tools: Vec<skills::Tool> = if lower == "all" {
        skills::Tool::all()
    } else if lower == "none" {
        vec![]
    } else {
        let ids: Vec<&str> = tools_str.split(',').map(|s| s.trim()).filter(|s| !s.is_empty()).collect();
        let mut tools = Vec::new();
        let mut errors = Vec::new();
        for id in &ids {
            match skills::Tool::from_id(id) {
                Some(t) => tools.push(t),
                None => errors.push(*id),
            }
        }
        if !errors.is_empty() {
            let valid: Vec<String> = skills::Tool::all().iter().map(|t| format!("  {}", t.cli_id())).collect();
            eprintln!("error: unknown tool(s): {}", errors.join(", "));
            eprintln!("Valid tools:\n{}", valid.join("\n"));
            std::process::exit(1);
        }
        tools
    };

    if selected_tools.is_empty() {
        if json {
            println!(r#"{{"skills_generated": 0}}"#);
        } else {
            println!("  Skills: none (--tools none)");
        }
        return;
    }

    for tool in &selected_tools {
        let dir = project_root.to_path_buf();
        match skills::generate_skills(*tool, &dir) {
            Ok(files) => {
                if json {
                    let paths: Vec<String> = files.iter().map(|f| f.to_string_lossy().to_string()).collect();
                    println!(r#"{{"tool": "{}", "skills": {}}}"#, tool.cli_id(), serde_json::to_string(&paths).unwrap());
                } else {
                    println!("  {}: {} skill(s) in {}/", tool.name(), files.len(), tool.skills_dir());
                    for f in &files {
                        println!("    {}", f.display());
                    }
                }
            }
            Err(e) => {
                eprintln!("error generating skills for {}: {}", tool.name(), e);
            }
        }
    }
}

/// Move a file using `git mv` if it's tracked by git, else `std::fs::rename`.
/// Preserves file history in git repos.
fn git_mv_or_rename(source: &Path, dest: &Path) {
    let is_git_tracked = std::process::Command::new("git")
        .args(["ls-files", "--error-unmatch", &source.to_string_lossy()])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    if is_git_tracked {
        // Ensure parent directory exists for git mv
        if let Some(parent) = dest.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let status = std::process::Command::new("git")
            .args(["mv", &source.to_string_lossy(), &dest.to_string_lossy()])
            .status()
            .expect("failed to run git mv");

        if !status.success() {
            eprintln!("warning: git mv failed, falling back to fs::rename");
            std::fs::rename(source, dest).expect("failed to archive change");
        }
    } else {
        std::fs::rename(source, dest).expect("failed to archive change");
    }
}

/// Check if a spec file has been modified since the last commit.
/// Warns the user if uncommitted changes exist.
fn check_git_conflict(spec_file: &Path, json: bool) {
    let output = std::process::Command::new("git")
        .args(["diff", "--quiet", "HEAD", "--", &spec_file.to_string_lossy()])
        .output();

    match output {
        Ok(out) => {
            if !out.status.success() {
                // Exit code 1 = diff exists (or file not tracked)
                if json {
                    eprintln!(r#"{{"warn": "spec has uncommitted changes: {}"}}"#, spec_file.display());
                } else {
                    eprintln!("⚠  Warning: {} has uncommitted changes", spec_file.display());
                    eprintln!("   Archive may conflict with existing work.");
                    eprintln!("   Commit or stash your changes first for a clean merge.");
                }
            }
        }
        Err(_) => {
            // git not available or not a repository — skip check
        }
    }
}

fn today_date() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let duration = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    let secs = duration.as_secs();
    let days = secs / 86400;

    let mut y = 1970i64;
    let mut remaining_days = days as i64;

    loop {
        let days_in_year = if is_leap(y) { 366 } else { 365 };
        if remaining_days < days_in_year { break; }
        remaining_days -= days_in_year;
        y += 1;
    }

    let months = [31, if is_leap(y) { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut m = 0;
    for (i, &days_in_month) in months.iter().enumerate() {
        if remaining_days < days_in_month { m = i + 1; break; }
        remaining_days -= days_in_month;
    }
    if m == 0 { m = 12; }

    let d = remaining_days + 1;

    format!("{:04}-{:02}-{:02}", y, m, d)
}

fn is_leap(year: i64) -> bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}
