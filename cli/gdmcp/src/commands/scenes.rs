use serde_json::{json, Value};

use crate::{cli::ScenesCommand, client::ApiClient, error::CliError};

use super::tool_call::{call, call_with_options};

pub fn run(client: &ApiClient, command: ScenesCommand) -> Result<Value, CliError> {
    match command {
        ScenesCommand::Current => call(
            client,
            "get_current_scene",
            json!({}),
            false,
            false,
            None,
            None,
            None,
        ),
        ScenesCommand::List { limit, cursor } => call_with_options(
            client,
            "list_project_scenes",
            json!({"search_path": "res://"}),
            false,
            false,
            None,
            Some(limit),
            cursor,
            None,
            None,
        ),
        ScenesCommand::Tree { depth, fields } => call(
            client,
            "get_scene_structure",
            json!({"max_depth": depth.unwrap_or(6)}),
            false,
            false,
            fields,
            None,
            None,
        ),
        ScenesCommand::Open { path, apply } => {
            require_apply(apply, "scenes open")?;
            call(
                client,
                "open_scene",
                json!({"scene_path": path, "allow_ui_focus": true}),
                true,
                false,
                None,
                None,
                None,
            )
        }
        ScenesCommand::Save => call(
            client,
            "save_scene",
            json!({}),
            false,
            false,
            None,
            None,
            None,
        ),
    }
}

fn require_apply(apply: bool, command: &str) -> Result<(), CliError> {
    if apply {
        Ok(())
    } else {
        Err(CliError::Permission(format!("{command} requires --apply")))
    }
}
