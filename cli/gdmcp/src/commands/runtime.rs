use serde_json::{json, Value};

use crate::{cli::RuntimeCommand, client::ApiClient, error::CliError};

use super::tool_call::call;

pub fn run(client: &ApiClient, command: RuntimeCommand) -> Result<Value, CliError> {
    match command {
        RuntimeCommand::Info => call(
            client,
            "get_runtime_info",
            json!({}),
            false,
            true,
            None,
            None,
            None,
        ),
        RuntimeCommand::Tree { depth, fields } => call(
            client,
            "get_runtime_scene_tree",
            json!({"max_depth": depth.unwrap_or(6)}),
            false,
            true,
            fields,
            None,
            None,
        ),
        RuntimeCommand::Node { node_path } => call(
            client,
            "inspect_runtime_node",
            json!({"node_path": node_path}),
            false,
            true,
            None,
            None,
            None,
        ),
        RuntimeCommand::Screenshot {
            save_path,
            format,
            viewport_path,
        } => {
            let mut arguments = json!({"save_path": save_path, "format": format});
            if let Some(viewport_path) = viewport_path {
                arguments["viewport_path"] = Value::String(viewport_path);
            }
            call(
                client,
                "get_runtime_screenshot",
                arguments,
                false,
                true,
                None,
                None,
                None,
            )
        }
    }
}
