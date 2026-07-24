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
        #[arg(long, default_value_t = 5)]
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
    #[arg(long)]
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
    List,
    Tree {
        #[arg(long)]
        depth: Option<i32>,
        #[arg(long, value_delimiter = ',')]
        fields: Option<Vec<String>>,
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
    },
    List {
        #[arg(long, default_value = ".")]
        parent_path: String,
    },
    Create {
        #[arg(long)]
        parent: String,
        #[arg(long = "type")]
        node_type: String,
        #[arg(long)]
        name: String,
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
    Delete {
        node_path: String,
        #[arg(long)]
        apply: bool,
    },
}

#[derive(Debug, Subcommand)]
pub enum ScriptsCommand {
    List,
    Read {
        path: String,
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
        #[arg(long)]
        limit: Option<usize>,
    },
}

#[derive(Debug, Subcommand)]
pub enum ProjectCommand {
    Info,
    Settings,
    Run,
    Stop,
}

#[derive(Debug, Subcommand)]
pub enum DebugCommand {
    Logs {
        #[arg(long)]
        level: Option<String>,
        #[arg(long)]
        limit: Option<usize>,
        #[arg(long)]
        out: Option<PathBuf>,
    },
    Clear {
        #[arg(long)]
        apply: bool,
    },
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
    Node {
        node_path: String,
    },
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
