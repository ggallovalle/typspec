use serde::Deserialize;

/// A requirement as emitted by the typspec module.
#[derive(Debug, Clone, Deserialize)]
pub struct RequirementMeta {
    pub kind: String,
    pub id: String,
    pub priority: String,
    pub action: Option<String>,
}

/// A scenario as emitted by the typspec module.
#[derive(Debug, Clone, Deserialize)]
pub struct ScenarioMeta {
    pub kind: String,
    pub name: String,
}

/// A decision as emitted by the typspec module.
#[derive(Debug, Clone, Deserialize)]
pub struct DecisionMeta {
    pub kind: String,
    pub title: String,
}

/// A task as emitted by the typspec module.
#[derive(Debug, Clone, Deserialize)]
pub struct TaskMeta {
    pub kind: String,
    pub done: bool,
    pub assignee: Option<String>,
    pub labels: Option<Vec<String>>,
    pub refs: Option<Vec<String>>,
}

/// A task group as emitted by the typspec module.
#[derive(Debug, Clone, Deserialize)]
pub struct TaskGroupMeta {
    pub kind: String,
    pub name: String,
}

/// A change document header as emitted by the typspec module.
#[derive(Debug, Clone, Deserialize)]
pub struct ChangeMeta {
    pub kind: String,
    pub id: String,
    pub modifies: Option<Vec<String>>,
}

/// A parsed metadata value from `typst query`.
#[derive(Debug, Clone, Deserialize)]
#[serde(untagged)]
pub enum MetadataValue {
    Requirement(RequirementMeta),
    Scenario(ScenarioMeta),
    Decision(DecisionMeta),
    Task(TaskMeta),
    TaskGroup(TaskGroupMeta),
    Change(ChangeMeta),
}

impl MetadataValue {
    pub fn kind(&self) -> &str {
        match self {
            MetadataValue::Requirement(r) => &r.kind,
            MetadataValue::Scenario(s) => &s.kind,
            MetadataValue::Decision(d) => &d.kind,
            MetadataValue::Task(t) => &t.kind,
            MetadataValue::TaskGroup(g) => &g.kind,
            MetadataValue::Change(c) => &c.kind,
        }
    }
}
