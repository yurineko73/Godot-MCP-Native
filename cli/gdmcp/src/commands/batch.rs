use std::fs;

use serde::Deserialize;
use serde_json::{json, Value};

use crate::{cli::BatchCommand, client::ApiClient, contracts::ExecuteRequest, error::CliError};

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct BatchFile {
    operations: Vec<BatchOperation>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct BatchOperation {
    tool: String,
    #[serde(default = "empty_arguments")]
    arguments: Value,
    #[serde(default)]
    allow_open_world: bool,
}

fn empty_arguments() -> Value {
    json!({})
}

pub fn run(client: &ApiClient, command: BatchCommand) -> Result<Value, CliError> {
    let (path, apply) = match command {
        BatchCommand::Preview { file } => (file, false),
        BatchCommand::Apply { file, apply } => {
            if !apply {
                return Err(CliError::Permission(
                    "batch apply requires --apply".to_string(),
                ));
            }
            (file, true)
        }
    };
    let batch: BatchFile = serde_json::from_str(&fs::read_to_string(path)?)
        .map_err(|error| CliError::InvalidArguments(format!("invalid batch file: {error}")))?;
    // First pass: local structural validation (no network)
    for (index, operation) in batch.operations.iter().enumerate() {
        if operation.tool.trim().is_empty() {
            return Err(CliError::InvalidArguments(format!(
                "batch operation {index} tool must not be empty"
            )));
        }
        if !operation.arguments.is_object() {
            return Err(CliError::InvalidArguments(format!(
                "batch operation {index}: arguments must be a JSON object"
            )));
        }
    }
    // Second pass: schema preflight validation (requires network)
    for (index, operation) in batch.operations.iter().enumerate() {
        validate_operation(client, index, operation)?;
    }
    let mut results = Vec::with_capacity(batch.operations.len());
    for (index, operation) in batch.operations.into_iter().enumerate() {
        let tool = operation.tool.trim();
        let result = match client.post(
            &format!("/cli/v1/tools/{tool}/execute"),
            &ExecuteRequest {
                arguments: operation.arguments,
                dry_run: !apply,
                apply_confirmed: apply,
                allow_open_world: operation.allow_open_world,
                fields: None,
                limit: None,
                cursor: None,
                depth: None,
                max_bytes: None,
            },
        ) {
            Ok(result) => result,
            Err(error) => {
                return Err(CliError::BatchFailed {
                    failed_index: index,
                    completed_count: results.len(),
                    completed: results,
                    message: error.to_string(),
                });
            }
        };
        results.push(result);
    }
    Ok(json!({
        "schema_version": 1,
        "ok": true,
        "command": if apply { "batch.apply" } else { "batch.preview" },
        "data": {
            "count": results.len(),
            "results": results
        },
        "meta": {
            "truncated": false,
            "next_cursor": null,
            "execution": "sequential",
            "atomic": false
        }
    }))
}

fn validate_operation(
    client: &ApiClient,
    index: usize,
    operation: &BatchOperation,
) -> Result<(), CliError> {
    let tool = operation.tool.trim();
    let schema_response = match client.get(&format!("/cli/v1/tools/{tool}"), &[]) {
        Ok(response) => response,
        Err(CliError::Api(message)) => {
            return Err(CliError::InvalidArguments(format!(
                "batch operation {index} tool validation failed: {message}"
            )))
        }
        Err(error) => return Err(error),
    };
    let schema = schema_response
        .pointer("/data/input_schema")
        .ok_or_else(|| {
            CliError::InvalidArguments(format!("batch operation {index} has no input schema"))
        })?;
    validate_json_schema(schema, &operation.arguments, "arguments").map_err(|message| {
        CliError::InvalidArguments(format!("batch operation {index}: {message}"))
    })
}

fn validate_json_schema(schema: &Value, value: &Value, path: &str) -> Result<(), String> {
    if let Some(expected_type) = schema.get("type").and_then(Value::as_str) {
        let matches = match expected_type {
            "object" => value.is_object(),
            "array" => value.is_array(),
            "string" => value.is_string(),
            "number" => value.is_number(),
            "integer" => value.as_i64().is_some() || value.as_u64().is_some(),
            "boolean" => value.is_boolean(),
            "null" => value.is_null(),
            _ => true,
        };
        if !matches {
            return Err(format!("{path} must be a {expected_type}"));
        }
    }
    if let Some(enum_values) = schema.get("enum").and_then(Value::as_array) {
        if !enum_values.iter().any(|candidate| candidate == value) {
            return Err(format!("{path} must be one of the declared enum values"));
        }
    }
    if let Some(object) = value.as_object() {
        if let Some(required) = schema.get("required").and_then(Value::as_array) {
            for field in required.iter().filter_map(Value::as_str) {
                if !object.contains_key(field) {
                    return Err(format!("{path}.{field} is required"));
                }
            }
        }
        if let Some(properties) = schema.get("properties").and_then(Value::as_object) {
            for (field, field_schema) in properties {
                if let Some(field_value) = object.get(field) {
                    validate_json_schema(field_schema, field_value, &format!("{path}.{field}"))?;
                }
            }
        }
    }
    if let Some(array) = value.as_array() {
        if let Some(item_schema) = schema.get("items") {
            for (index, item) in array.iter().enumerate() {
                validate_json_schema(item_schema, item, &format!("{path}[{index}]"))?;
            }
        }
    }
    Ok(())
}
