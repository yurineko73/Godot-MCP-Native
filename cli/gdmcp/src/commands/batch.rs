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
    arguments: Value,
    #[serde(default)]
    allow_open_world: bool,
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
    for (index, operation) in batch.operations.iter().enumerate() {
        if operation.tool.trim().is_empty() {
            return Err(CliError::InvalidArguments(format!(
                "batch operation {index} tool must not be empty"
            )));
        }
        if !operation.arguments.is_object() {
            return Err(CliError::InvalidArguments(format!(
                "batch operation {} arguments must be a JSON object",
                operation.tool
            )));
        }
    }
    let mut results = Vec::with_capacity(batch.operations.len());
    for operation in batch.operations {
        let tool = operation.tool.trim();
        let result = client.post(
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
        )?;
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
