use serde_json::{json, Value};

use crate::{cli::RuntimeCommand, client::ApiClient, error::CliError, output::write_output};

use super::tool_call::call;

pub fn run(client: &ApiClient, command: RuntimeCommand) -> Result<Value, CliError> {
    match command {
        RuntimeCommand::Info => call(client, "get_runtime_info", json!({}), false, true, None, None, None),
        RuntimeCommand::Tree { depth, fields } => call(
            client,
            "get_runtime_scene_tree",
            json!({"max_depth": depth.unwrap_or(-1)}),
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
        RuntimeCommand::Screenshot { out } => {
            let value = call(client, "get_runtime_screenshot", json!({}), false, true, None, None, None)?;
            write_output(&out, &value)
        }
    }
}
