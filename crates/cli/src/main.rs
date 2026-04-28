use std::path::{Path, PathBuf};
use clap::{Parser, Subcommand};

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
        name: String,
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
        Commands::Init { path } => cmd_init(path.as_deref(), cli.json),
        Commands::New { kind } => cmd_new(kind, cli.json),
        Commands::List { specs } => cmd_list(*specs, cli.json),
        Commands::Status { name } => cmd_status(name, cli.json),
        Commands::Render { path, watch } => cmd_render(path.as_deref(), *watch),
        Commands::Archive { name, yes } => cmd_archive(name, *yes, cli.json),
        Commands::Validate { path } => cmd_validate(path.as_deref()),
        Commands::Install => cmd_install(),
    }
}

fn cmd_init(path: Option<&Path>, json: bool) {
    let dir = path.unwrap_or_else(|| Path::new("."));
    let specs_dir = dir.join("typspec").join("specs");
    let changes_dir = dir.join("typspec").join("changes");
    let config_path = dir.join("typspec.jsonc");

    std::fs::create_dir_all(&specs_dir).expect("failed to create specs dir");
    std::fs::create_dir_all(&changes_dir).expect("failed to create changes dir");

    if !config_path.exists() {
        let config = r#"{
  "$schema": "https://typspec.dev/schemas/v1.json",
  "project": {
    "name": "my-project",
    "version": "0.1.0"
  }
}"#;
        std::fs::write(&config_path, config).expect("failed to write config");
    }

    if json {
        println!(r#"{{"created": ["specs", "changes", "typspec.jsonc"]}}"#);
    } else {
        println!("✓ Initialized typspec project at {}", dir.display());
        println!("  {}/", specs_dir.display());
        println!("  {}/", changes_dir.display());
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
    let path = PathBuf::from("typspec/specs").join(format!("{}.typ", name));

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
    let path = PathBuf::from("typspec/changes").join(format!("{}.typ", name));

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

fn cmd_list(specs: bool, json: bool) {
    let dir = if specs {
        PathBuf::from("typspec/specs")
    } else {
        PathBuf::from("typspec/changes")
    };

    let entries: Vec<_> = match std::fs::read_dir(&dir) {
        Ok(entries) => entries
            .filter_map(|e| e.ok())
            .filter(|e| e.path().extension().map(|ext| ext == "typ").unwrap_or(false))
            .collect(),
        Err(_) => Vec::new(),
    };

    if json {
        let names: Vec<String> = entries.iter()
            .map(|f| f.path().file_stem().unwrap().to_string_lossy().to_string())
            .collect();
        println!("{}", serde_json::to_string(&names).unwrap());
    } else {
        for file in &entries {
            let path = file.path();
            let name = path.file_stem().unwrap().to_string_lossy();
            println!("  {}", name);
        }
        if entries.is_empty() {
            println!("  (no {} found)", if specs { "specs" } else { "changes" });
        }
    }
}

fn cmd_status(name: &str, json: bool) {
    let spec_path = PathBuf::from("typspec/specs").join(format!("{}.typ", name));
    let change_path = PathBuf::from("typspec/changes").join(format!("{}.typ", name));

    let target = if spec_path.exists() {
        spec_path
    } else if change_path.exists() {
        change_path
    } else {
        eprintln!("error: '{}' not found in typspec/specs/ or typspec/changes/", name);
        suggest_name(name, &[PathBuf::from("typspec/specs"), PathBuf::from("typspec/changes")]);
        std::process::exit(1);
    };

    let output = std::process::Command::new("typst")
        .args(["query", "--root", ".", &target.to_string_lossy(), "metadata", "--field", "value"])
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
                    println!("  {} [task]{}", mark, assignee);
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

    let mut cmd = std::process::Command::new("typst");
    cmd.args(["compile", "--root", ".", &target.to_string_lossy(), &output.to_string_lossy()]);
    if watch {
        cmd.arg("--watch");
    }

    let status = cmd.status().expect("failed to run typst");

    if !status.success() {
        std::process::exit(status.code().unwrap_or(1));
    }
}

fn find_latest_typ_file() -> PathBuf {
    let candidates = [
        PathBuf::from("typspec/specs"),
        PathBuf::from("typspec/changes"),
    ];
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

fn cmd_archive(name: &str, _yes: bool, json: bool) {
    let change_path = PathBuf::from("typspec/changes").join(format!("{}.typ", name));

    if !change_path.exists() {
        eprintln!("error: change '{}' not found at {}", name, change_path.display());
        suggest_name(name, &[PathBuf::from("typspec/changes")]);
        std::process::exit(1);
    }

    // Query the change file for metadata
    let output = std::process::Command::new("typst")
        .args(["query", "--root", ".", &change_path.to_string_lossy(), "metadata", "--field", "value"])
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
    let delta_ops = typspec_core::metadata_to_delta_ops(&entries);

    // Check for git conflicts — warn if spec files have uncommitted changes
    let spec_dir = PathBuf::from("typspec/specs");
    for spec_name in &modifies {
        let spec_file = spec_dir.join(format!("{}.typ", spec_name));
        if spec_file.exists() {
            check_git_conflict(&spec_file, json);
        }
    }

    // Map spec names to file paths
    let spec_dir = PathBuf::from("typspec/specs");
    let mut spec_deltas: std::collections::HashMap<String, Vec<typspec_core::surgery::DeltaOp>> = std::collections::HashMap::new();

    // Group ops by spec (for now, all ops go to first spec in modifies)
    if !delta_ops.is_empty() && !modifies.is_empty() {
        let first_spec = format!("{}.typ", modifies[0]);
        let spec_path = spec_dir.join(&first_spec);
        if spec_path.exists() {
            spec_deltas.insert(spec_path.to_string_lossy().to_string(), delta_ops);
        }
    }

    // Apply deltas
    if !spec_deltas.is_empty() {
        if json {
            println!(r#"{{"applying_deltas": {}}}"#, serde_json::to_string(&modifies).unwrap());
        } else {
            println!("Applying spec-deltas to: {:?}", modifies);
        }

        match typspec_core::apply_spec_deltas(&spec_deltas) {
            Ok(results) => {
                let total_changes: usize = results.values().map(|r| r.changes).sum();
                if total_changes > 0 {
                    for (path, result) in &results {
                        println!("  → {} ({} change(s))", path, result.changes);
                    }
                    typspec_core::write_results(&results).unwrap_or_else(|e| {
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
    let archive_dir = PathBuf::from("typspec/archive");
    std::fs::create_dir_all(&archive_dir).expect("failed to create archive dir");

    let today = today_date();
    let archived_name = format!("{}-{}", today, name);
    let dest = archive_dir.join(format!("{}.typ", archived_name));

    std::fs::rename(&change_path, &dest).expect("failed to archive change");

    if json {
        println!(r#"{{"archived": "{}"}}"#, dest.display());
    } else {
        println!("✓ Archived {} → {}", name, dest.display());
    }
}

fn cmd_validate(path: Option<&Path>) {
    let target = path.unwrap_or_else(|| Path::new("."));

    let status = std::process::Command::new("typst")
        .args(["compile", "--root", ".", &target.to_string_lossy()])
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
    match typspec_core::config::load_config(std::path::Path::new(".")) {
        Ok(cfg) => {
            let mut found = false;
            for (name, entry) in &cfg.workspaces {
                match entry {
                    typspec_core::config::WorkspaceEntry::Git { git, tag, commit, subpath: _ } => {
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

    let suggestions = typspec_core::fuzzy::best_fuzzy_match(input, &candidates);
    if suggestions.len() == 1 {
        eprintln!("  tip: a similar name exists: '{}'", suggestions[0]);
    } else if suggestions.len() > 1 {
        let joined = suggestions.iter().map(|s| format!("'{}'", s)).collect::<Vec<_>>().join("' or '");
        eprintln!("  tip: a similar name exists: {}?", joined);
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
