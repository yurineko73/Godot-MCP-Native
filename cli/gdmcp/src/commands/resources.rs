use serde_json::{json, Value};

use crate::{cli::ResourcesCommand, client::ApiClient, error::CliError};

use super::tool_call::{call, call_with_options};

pub fn run(client: &ApiClient, command: ResourcesCommand) -> Result<Value, CliError> {
    match command {
        ResourcesCommand::List {
            search_path,
            resource_types,
            limit,
            cursor,
        } => {
            let arguments = json!({
                "search_path": search_path,
                "resource_types": resource_types,
            });
            call_with_options(
                client,
                "list_project_resources",
                arguments,
                false,
                false,
                None,
                Some(limit),
                cursor,
                None,
                None,
            )
        }
        ResourcesCommand::Get { path, fields } => {
            let mut value = call(
                client,
                "get_inspector_properties",
                json!({"resource_path": path, "include_values": true}),
                false,
                false,
                None,
                None,
                None,
            )?;
            if let Some(field_names) = fields {
                if let Some(props) = value.pointer_mut("/data/properties") {
                    if let Some(arr) = props.as_array_mut() {
                        let keep: Vec<String> = field_names.to_vec();
                        arr.retain(|item| {
                            item.get("name")
                                .and_then(Value::as_str)
                                .is_some_and(|n| keep.iter().any(|k| k == n))
                        });
                    }
                }
            }
            Ok(value)
        }
        ResourcesCommand::Resolve { name } => {
            let result = call_with_options(
                client,
                "list_project_resources",
                json!({"search_path": "res://"}),
                false,
                false,
                None,
                Some(200),
                None,
                None,
                None,
            )?;
            let items: Vec<&str> = result
                .pointer("/data/resources")
                .and_then(Value::as_array)
                .map(|arr| arr.iter().filter_map(Value::as_str).collect())
                .unwrap_or_default();
            let name_lower = name.to_lowercase();
            let matches: Vec<&str> = items
                .iter()
                .filter(|item| item.to_lowercase().contains(&name_lower))
                .copied()
                .collect();
            Ok(json!({
                "query": name,
                "matches": matches,
                "count": matches.len()
            }))
        }
    }
}
