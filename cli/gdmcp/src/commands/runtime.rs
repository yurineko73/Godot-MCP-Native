use serde_json::{json, Value};

use crate::{
    args::parse_value,
    cli::{RuntimeCommand, RuntimeNodesCommand},
    client::ApiClient,
    error::CliError,
};

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
        RuntimeCommand::Nodes(nodes) => match nodes {
            RuntimeNodesCommand::Get { node_path } => call(
                client,
                "inspect_runtime_node",
                json!({"node_path": node_path}),
                false,
                true,
                None,
                None,
                None,
            ),
            RuntimeNodesCommand::Set {
                node_path,
                property,
                value,
                value_json,
            } => call(
                client,
                "update_runtime_node_property",
                json!({
                    "node_path": node_path,
                    "property_name": property,
                    "property_value": parse_value(value, value_json)?
                }),
                false,
                true,
                None,
                None,
                None,
            ),
            RuntimeNodesCommand::Call {
                node_path,
                method,
                arguments,
            } => {
                let parsed_args: Value = arguments
                    .as_deref()
                    .map(|s| {
                        serde_json::from_str(s).map_err(|e| {
                            CliError::InvalidArguments(format!("invalid JSON arguments: {e}"))
                        })
                    })
                    .transpose()?
                    .unwrap_or(Value::Array(vec![]));
                call(
                    client,
                    "call_runtime_node_method",
                    json!({
                        "node_path": node_path,
                        "method_name": method,
                        "arguments": parsed_args
                    }),
                    false,
                    true,
                    None,
                    None,
                    None,
                )
            }
        },
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
