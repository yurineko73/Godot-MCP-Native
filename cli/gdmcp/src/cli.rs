use std::path::PathBuf;

use clap::{Args, Parser, Subcommand};

#[derive(Debug, Parser)]
#[command(
    name = "gdmcp",
    version,
    about = "Agent-friendly CLI for Godot MCP Native"
)]
pub struct Cli {
    #[arg(long, global = true)]
    pub json: bool,
    #[arg(long, global = true)]
    pub url: Option<String>,
    #[arg(long, global = true)]
    pub token_env: Option<String>,
    #[arg(long, global = true)]
    pub timeout: Option<u64>,
    #[command(subcommand)]
    pub command: Commands,
}

/// Parsed line range for `scripts read --lines`.
#[derive(Debug, Clone)]
pub struct LineRange {
    pub start: usize,
    pub end: Option<usize>,
}

impl std::str::FromStr for LineRange {
    type Err = String;
    fn from_str(value: &str) -> Result<Self, Self::Err> {
        let (start_str, end_str) = value.split_once(':').ok_or_else(|| {
            "line range must be start:end or start: (e.g. 1:200 or 50:)".to_string()
        })?;
        let start = start_str
            .parse::<usize>()
            .map_err(|_| format!("invalid start line: {start_str}"))?;
        if start == 0 {
            return Err("start line must be greater than zero".to_string());
        }
        let end = if end_str.is_empty() {
            None
        } else {
            Some(
                end_str
                    .parse::<usize>()
                    .map_err(|_| format!("invalid end line: {end_str}"))?,
            )
        };
        if let Some(end) = end {
            if end < start {
                return Err(format!("end line {end} is before start line {start}"));
            }
        }
        Ok(LineRange { start, end })
    }
}

#[derive(Debug, Subcommand)]
pub enum Commands {
    Doctor,
    Tools {
        #[command(subcommand)]
        command: ToolsCommand,
    },
    ToolCall(ToolCallArgs),
    Editor {
        #[command(subcommand)]
        command: EditorCommand,
    },
    Scenes {
        #[command(subcommand)]
        command: ScenesCommand,
    },
    Nodes {
        #[command(subcommand)]
        command: NodesCommand,
    },
    Scripts {
        #[command(subcommand)]
        command: ScriptsCommand,
    },
    Resources {
        #[command(subcommand)]
        command: ResourcesCommand,
    },
    Project {
        #[command(subcommand)]
        command: ProjectCommand,
    },
    Debug {
        #[command(subcommand)]
        command: DebugCommand,
    },
    Runtime {
        #[command(subcommand)]
        command: RuntimeCommand,
    },
    Batch {
        #[command(subcommand)]
        command: BatchCommand,
    },
}

#[derive(Debug, Subcommand)]
pub enum ToolsCommand {
    Search {
        query: String,
        #[arg(long, default_value_t = 5, value_parser = parse_positive_limit)]
        limit: usize,
    },
    Schema {
        name: String,
    },
    Catalog,
}

#[derive(Debug, Args)]
pub struct ToolCallArgs {
    pub name: String,
    #[arg(long, conflicts_with = "args_file")]
    pub args_json: Option<String>,
    #[arg(long, conflicts_with = "args_json")]
    pub args_file: Option<PathBuf>,
    #[arg(long)]
    pub dry_run: bool,
    #[arg(long)]
    pub apply: bool,
    #[arg(long)]
    pub allow_open_world: bool,
    #[arg(long, value_delimiter = ',')]
    pub fields: Option<Vec<String>>,
    #[arg(long, value_parser = parse_positive_limit)]
    pub limit: Option<usize>,
    #[arg(long)]
    pub cursor: Option<String>,
    #[arg(long)]
    pub depth: Option<i32>,
    #[arg(long)]
    pub max_bytes: Option<usize>,
    #[arg(long)]
    pub out: Option<PathBuf>,
}

#[derive(Debug, Subcommand)]
pub enum EditorCommand {
    State,
}

#[derive(Debug, Subcommand)]
pub enum ScenesCommand {
    Current,
    List {
        #[arg(long, default_value_t = DEFAULT_LIST_LIMIT, value_parser = parse_positive_limit)]
        limit: usize,
        #[arg(long)]
        cursor: Option<String>,
    },
    Tree {
        #[arg(long)]
        depth: Option<i32>,
        #[arg(long, value_delimiter = ',')]
        fields: Option<Vec<String>>,
    },
    Resolve {
        name: String,
    },
    Open {
        path: String,
        #[arg(long)]
        apply: bool,
    },
    Save,
}

#[derive(Debug, Subcommand)]
pub enum NodesCommand {
    Get {
        node_path: String,
        #[arg(long, value_delimiter = ',')]
        fields: Option<Vec<String>>,
    },
    List {
        #[arg(long, default_value = ".")]
        parent_path: String,
        #[arg(long, default_value_t = DEFAULT_LIST_LIMIT, value_parser = parse_positive_limit)]
        limit: usize,
        #[arg(long)]
        cursor: Option<String>,
    },
    Create {
        #[arg(long)]
        parent: String,
        #[arg(long = "type")]
        node_type: String,
        #[arg(long)]
        name: String,
    },
    Move {
        node_path: String,
        #[arg(long)]
        new_parent: String,
    },
    Rename {
        node_path: String,
        #[arg(long)]
        new_name: String,
    },
    Resolve {
        name: String,
    },
    #[command(subcommand)]
    Properties(NodesPropertiesCommand),
    Delete {
        node_path: String,
        #[arg(long)]
        apply: bool,
    },
}

#[derive(Debug, Subcommand)]
pub enum NodesPropertiesCommand {
    Set {
        node_path: String,
        #[arg(long)]
        property: String,
        #[arg(long)]
        value: String,
        #[arg(long)]
        value_json: bool,
    },
}

#[derive(Debug, Subcommand)]
pub enum ScriptsCommand {
    List {
        #[arg(long, default_value_t = DEFAULT_LIST_LIMIT, value_parser = parse_positive_limit)]
        limit: usize,
        #[arg(long)]
        cursor: Option<String>,
    },
    Read {
        path: String,
        #[arg(long, value_parser = parse_line_range)]
        lines: Option<LineRange>,
    },
    Create {
        path: String,
        #[arg(long, default_value = "GDScript")]
        script_type: String,
    },
    Resolve {
        name: String,
    },
    Validate {
        path: String,
    },
    Replace {
        path: String,
        #[arg(long)]
        content_file: PathBuf,
        #[arg(long)]
        apply: bool,
    },
}

#[derive(Debug, Subcommand)]
pub enum ResourcesCommand {
    List {
        #[arg(long, default_value = "res://")]
        search_path: String,
        #[arg(long = "type")]
        resource_types: Vec<String>,
        #[arg(long, default_value_t = DEFAULT_LIST_LIMIT, value_parser = parse_positive_limit)]
        limit: usize,
        #[arg(long)]
        cursor: Option<String>,
    },
    Get {
        path: String,
        #[arg(long, value_delimiter = ',')]
        fields: Option<Vec<String>>,
    },
    Resolve {
        name: String,
    },
}

#[derive(Debug, Subcommand)]
pub enum ProjectCommand {
    Info,
    Settings {
        #[arg(long)]
        filter: Option<String>,
    },
    Run,
    Stop,
}

#[derive(Debug, Subcommand)]
pub enum DebugCommand {
    Logs {
        #[arg(long)]
        level: Option<String>,
        #[arg(long, default_value_t = DEFAULT_LOG_LIMIT, value_parser = parse_positive_limit)]
        limit: usize,
        #[arg(long)]
        cursor: Option<String>,
        #[arg(long)]
        out: Option<PathBuf>,
    },
    Clear {
        #[arg(long)]
        apply: bool,
    },
}

pub const DEFAULT_LIST_LIMIT: usize = 50;
pub const DEFAULT_LOG_LIMIT: usize = 50;

fn parse_positive_limit(value: &str) -> Result<usize, String> {
    let parsed = value
        .parse::<usize>()
        .map_err(|_| "limit must be a positive integer".to_string())?;
    if parsed == 0 {
        return Err("limit must be greater than zero".to_string());
    }
    Ok(parsed)
}

fn parse_line_range(value: &str) -> Result<LineRange, String> {
    value.parse()
}

#[derive(Debug, Subcommand)]
pub enum RuntimeCommand {
    Info,
    Tree {
        #[arg(long)]
        depth: Option<i32>,
        #[arg(long, value_delimiter = ',')]
        fields: Option<Vec<String>>,
    },
    #[command(subcommand)]
    Nodes(RuntimeNodesCommand),
    Screenshot {
        #[arg(long, default_value = "user://mcp_runtime_capture.jpg")]
        save_path: String,
        #[arg(long, default_value = "jpg", value_parser = ["png", "jpg"])]
        format: String,
        #[arg(long)]
        viewport_path: Option<String>,
    },
}

#[derive(Debug, Subcommand)]
pub enum RuntimeNodesCommand {
    Get {
        node_path: String,
    },
    Set {
        node_path: String,
        #[arg(long)]
        property: String,
        #[arg(long)]
        value: String,
        #[arg(long)]
        value_json: bool,
    },
    Call {
        node_path: String,
        #[arg(long)]
        method: String,
        #[arg(long)]
        arguments: Option<String>,
    },
}

#[derive(Debug, Subcommand)]
pub enum BatchCommand {
    Preview {
        file: PathBuf,
    },
    Apply {
        file: PathBuf,
        #[arg(long)]
        apply: bool,
    },
}
