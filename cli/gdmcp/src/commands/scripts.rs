use std::fs;

use serde_json::{json, Value};

use crate::{cli::ScriptsCommand, client::ApiClient, error::CliError};

use super::tool_call::{call, call_with_options};

pub fn run(client: &ApiClient, command: ScriptsCommand) -> Result<Value, CliError> {
    match command {
        ScriptsCommand::List { limit, cursor } => call_with_options(
            client,
            "list_project_scripts",
            json!({"search_path": "res://"}),
            false,
            false,
            None,
            Some(limit),
            cursor,
            None,
            None,
        ),
        ScriptsCommand::Read { path } => call(
            client,
            "read_script",
            json!({"script_path": path}),
            false,
            false,
            None,
            None,
            None,
        ),
        ScriptsCommand::Validate { path } => call(
            client,
            "validate_script",
            json!({"script_path": path}),
            false,
            false,
            None,
            None,
            None,
        ),
        ScriptsCommand::Replace {
            path,
            content_file,
            apply,
        } => {
            require_apply(apply, "scripts replace")?;
            call(
                client,
                "modify_script",
                json!({
                    "script_path": path,
                    "content": fs::read_to_string(content_file)?
                }),
                true,
                false,
                None,
                None,
                None,
            )
        }
    }
}

fn require_apply(apply: bool, command: &str) -> Result<(), CliError> {
    if apply {
        Ok(())
    } else {
        Err(CliError::Permission(format!("{command} requires --apply")))
    }
}
