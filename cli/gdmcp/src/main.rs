mod args;
mod cli;
mod client;
mod commands;
mod config;
mod contracts;
mod error;
mod output;

use std::process::ExitCode;

use clap::Parser;
use serde_json::{json, Value};

use cli::{Cli, Commands};
use client::ApiClient;
use config::Config;
use error::CliError;

fn main() -> ExitCode {
    let cli = Cli::parse();
    let json_mode = cli.json;
    match run(cli) {
        Ok(value) => match output::render(&value, json_mode) {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => exit_with_error(error, json_mode),
        },
        Err(error) => exit_with_error(error, json_mode),
    }
}

fn run(cli: Cli) -> Result<Value, CliError> {
    let config = Config::load(&cli)?;
    let client = ApiClient::new(config)?;
    match cli.command {
        Commands::Doctor => commands::doctor::run(&client),
        Commands::Tools { command } => commands::tools::run(&client, command),
        Commands::ToolCall(args) => commands::tool_call::execute(&client, args),
        Commands::Editor { command } => match command {
            cli::EditorCommand::State => commands::editor::state(&client),
        },
        Commands::Scenes { command } => commands::scenes::run(&client, command),
        Commands::Nodes { command } => commands::nodes::run(&client, command),
        Commands::Scripts { command } => commands::scripts::run(&client, command),
        Commands::Resources { command } => commands::resources::run(&client, command),
        Commands::Project { command } => commands::project::run(&client, command),
        Commands::Debug { command } => commands::debug::run(&client, command),
        Commands::Runtime { command } => commands::runtime::run(&client, command),
        Commands::Batch { command } => commands::batch::run(&client, command),
    }
}

fn exit_with_error(error: CliError, json_mode: bool) -> ExitCode {
    let code = error.exit_code();
    if json_mode {
        let data = match &error {
            CliError::BatchFailed {
                failed_index,
                completed_count,
                completed,
                ..
            } => json!({
                "failed_index": failed_index,
                "completed_count": completed_count,
                "completed": completed,
                "execution": "sequential",
                "atomic": false
            }),
            _ => Value::Null,
        };
        println!(
            "{}",
            json!({
                "schema_version": 1,
                "ok": false,
                "data": data,
                "error": {
                    "code": error_code(&error),
                    "message": error.to_string(),
                    "retryable": code == 4 || code == 5
                },
                "meta": {
                    "truncated": false,
                    "next_cursor": null
                }
            })
        );
    } else {
        eprintln!("gdmcp: {error}");
    }
    ExitCode::from(code as u8)
}

fn error_code(error: &CliError) -> &'static str {
    match error {
        CliError::InvalidArguments(_) => "INVALID_ARGUMENT",
        CliError::Configuration(_) => "CONFIGURATION_ERROR",
        CliError::Unreachable(_) => "SERVICE_UNREACHABLE",
        CliError::Api(_) => "API_ERROR",
        CliError::Permission(_) => "PERMISSION_REQUIRED",
        CliError::VersionMismatch(_) => "API_VERSION_MISMATCH",
        CliError::BatchFailed { .. } => "BATCH_PARTIAL_FAILURE",
        CliError::Io(_) => "IO_ERROR",
        CliError::Json(_) => "INVALID_JSON",
        CliError::Http(_) => "HTTP_ERROR",
    }
}
