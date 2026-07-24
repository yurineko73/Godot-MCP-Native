use serde_json::{json, Value};

use crate::{args::parse_value, cli::NodesCommand, client::ApiClient, error::CliError};

use super::tool_call::{call, call_with_options};

pub fn run(client: &ApiClient, command: NodesCommand) -> Result<Value, CliError> {
    match command {
        NodesCommand::Get { node_path } => call(
            client,
            "get_node_properties",
            json!({"node_path": node_path}),
            false,
            false,
            None,
            None,
            None,
        ),
        NodesCommand::List {
            parent_path,
            limit,
            cursor,
        } => call_with_options(
            client,
            "list_nodes",
            json!({"parent_path": parent_path}),
            false,
            false,
            None,
            limit,
            cursor,
            None,
            None,
        ),
        NodesCommand::Create {
            parent,
            node_type,
            name,
        } => call(
            client,
            "create_node",
            json!({
                "parent_path": parent,
                "node_type": node_type,
                "node_name": name
            }),
            false,
            false,
            None,
            None,
            None,
        ),
        NodesCommand::Set {
            node_path,
            property,
            value,
            value_json,
        } => call(
            client,
            "update_node_property",
            json!({
                "node_path": node_path,
                "property_name": property,
                "property_value": parse_value(value, value_json)?
            }),
            false,
            false,
            None,
            None,
            None,
        ),
        NodesCommand::Delete { node_path, apply } => {
            require_apply(apply, "nodes delete")?;
            call(
                client,
                "delete_node",
                json!({"node_path": node_path}),
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
