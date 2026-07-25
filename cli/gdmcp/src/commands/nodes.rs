use serde_json::{json, Value};

use crate::{
    args::parse_value,
    cli::{NodesCommand, NodesPropertiesCommand},
    client::ApiClient,
    error::CliError,
};

use super::tool_call::{call, call_with_options};

pub fn run(client: &ApiClient, command: NodesCommand) -> Result<Value, CliError> {
    match command {
        NodesCommand::Get { node_path, fields } => {
            let mut value = call(
                client,
                "get_node_properties",
                json!({"node_path": node_path}),
                false,
                false,
                None,
                None,
                None,
            )?;
            if let Some(field_names) = fields {
                filter_node_properties(&mut value, &field_names);
            }
            Ok(value)
        }
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
            Some(limit),
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
        NodesCommand::Properties(props) => match props {
            NodesPropertiesCommand::Set {
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
        },
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

fn filter_node_properties(value: &mut Value, fields: &[String]) {
    if let Some(props) = value.pointer_mut("/data/properties") {
        if let Some(obj) = props.as_object_mut() {
            let keep: Vec<String> = fields.to_vec();
            obj.retain(|key, _| keep.contains(key));
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
