use std::path::PathBuf;
use tera::Tera;

/// Supported AI tools for skill generation.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Tool {
    Claude,
    Codex,
    OpenCode,
}

impl Tool {
    pub fn all() -> Vec<Tool> {
        vec![Tool::Claude, Tool::Codex, Tool::OpenCode]
    }

    pub fn from_id(id: &str) -> Option<Tool> {
        match id.to_lowercase().as_str() {
            "claude" => Some(Tool::Claude),
            "codex" => Some(Tool::Codex),
            "opencode" => Some(Tool::OpenCode),
            _ => None,
        }
    }

    pub fn name(&self) -> &str {
        match self {
            Tool::Claude => "Claude Code",
            Tool::Codex => "CodEX",
            Tool::OpenCode => "OpenCode",
        }
    }

    /// The CLI-facing ID (used in --tools flag).
    pub fn cli_id(&self) -> &str {
        match self {
            Tool::Claude => "claude",
            Tool::Codex => "codex",
            Tool::OpenCode => "opencode",
        }
    }

    pub fn skills_dir(&self) -> &str {
        match self {
            Tool::Claude => ".claude/skills",
            Tool::Codex | Tool::OpenCode => ".agents/skills",
        }
    }
}

/// Skill workflow definitions: (dir_name, description, template_fn)
struct SkillDef {
    dir_name: &'static str,
    description: &'static str,
    template: &'static str,
}

fn skills() -> Vec<SkillDef> {
    vec![
        SkillDef {
            dir_name: "typspec-propose",
            description: "Propose a new change — create a change document with all artifacts",
            template: include_str!("../templates/propose.md"),
        },
        SkillDef {
            dir_name: "typspec-explore",
            description: "Explore mode — think through ideas before committing to a change",
            template: include_str!("../templates/explore.md"),
        },
        SkillDef {
            dir_name: "typspec-apply",
            description: "Apply a change — implement tasks from an active change",
            template: include_str!("../templates/apply.md"),
        },
        SkillDef {
            dir_name: "typspec-archive",
            description: "Archive a completed change — merge deltas and move to archive",
            template: include_str!("../templates/archive.md"),
        },
    ]
}

/// Generate skills for a given tool into the project root.
pub fn generate_skills(tool: Tool, project_root: &PathBuf) -> Result<Vec<PathBuf>, String> {
    let skills_base = project_root.join(tool.skills_dir());
    let mut created = Vec::new();

    // Try canonical skills/typspec/ directory first, fall back to embedded templates
    let canonical_dir = project_root.join("skills").join("typspec");

    if canonical_dir.exists() {
        // Copy from canonical source
        for entry in std::fs::read_dir(&canonical_dir).map_err(|e| e.to_string())? {
            let entry = entry.map_err(|e| e.to_string())?;
            let dir_name = entry.file_name().to_string_lossy().to_string();
            let skill_source = entry.path().join("SKILL.md");
            if !skill_source.exists() { continue; }

            let content = std::fs::read_to_string(&skill_source)
                .map_err(|e| format!("failed to read {}: {}", skill_source.display(), e))?;

            let skill_dir = skills_base.join(&dir_name);
            std::fs::create_dir_all(&skill_dir)
                .map_err(|e| format!("failed to create {}: {}", skill_dir.display(), e))?;

            let dest = skill_dir.join("SKILL.md");
            std::fs::write(&dest, &content)
                .map_err(|e| format!("failed to write {}: {}", dest.display(), e))?;

            created.push(dest);
        }
    } else {
        // Fall back to embedded Tera templates
        let mut tera = Tera::default();
        for skill in skills() {
            let tpl_name = format!("{}.md", skill.dir_name);
            tera.add_raw_template(&tpl_name, skill.template)
                .map_err(|e| format!("template error for {}: {}", skill.dir_name, e))?;
        }

        for skill in skills() {
            let skill_dir = skills_base.join(skill.dir_name);
            std::fs::create_dir_all(&skill_dir)
                .map_err(|e| format!("failed to create {}: {}", skill_dir.display(), e))?;

            let mut ctx = tera::Context::new();
            ctx.insert("tool_name", tool.name());
            ctx.insert("description", skill.description);

            let rendered = tera.render(&format!("{}.md", skill.dir_name), &ctx)
                .map_err(|e| format!("render error for {}: {}", skill.dir_name, e))?;

            let skill_path = skill_dir.join("SKILL.md");
            std::fs::write(&skill_path, &rendered)
                .map_err(|e| format!("failed to write {}: {}", skill_path.display(), e))?;

            created.push(skill_path);
        }
    }

    Ok(created)
}
