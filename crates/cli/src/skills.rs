use std::path::PathBuf;

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

struct SkillDef {
    dir_name: &'static str,
    content: &'static str,
}

fn skills() -> Vec<SkillDef> {
    vec![
        SkillDef {
            dir_name: "typspec-propose",
            content: include_str!("../../../skills/typspec/typspec-propose/SKILL.md"),
        },
        SkillDef {
            dir_name: "typspec-explore",
            content: include_str!("../../../skills/typspec/typspec-explore/SKILL.md"),
        },
        SkillDef {
            dir_name: "typspec-apply",
            content: include_str!("../../../skills/typspec/typspec-apply/SKILL.md"),
        },
        SkillDef {
            dir_name: "typspec-archive",
            content: include_str!("../../../skills/typspec/typspec-archive/SKILL.md"),
        },
    ]
}

/// Generate skills for a given tool into the project root.
pub fn generate_skills(tool: Tool, project_root: &PathBuf) -> Result<Vec<PathBuf>, String> {
    let skills_base = project_root.join(tool.skills_dir());
    let mut created = Vec::new();
    let version = env!("CARGO_PKG_VERSION");

    for skill in skills() {
        let skill_dir = skills_base.join(skill.dir_name);
        std::fs::create_dir_all(&skill_dir)
            .map_err(|e| format!("failed to create {}: {}", skill_dir.display(), e))?;

        let content = skill.content.replace("VERSION", version);

        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(&skill_path, &content)
            .map_err(|e| format!("failed to write {}: {}", skill_path.display(), e))?;

        created.push(skill_path);
    }

    Ok(created)
}
