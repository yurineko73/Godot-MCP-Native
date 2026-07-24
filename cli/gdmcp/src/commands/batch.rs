use std::fs;

use serde::Deserialize;
use serde_json::{json, Value};

use crate::{cli::BatchCommand, client::ApiClient, contracts::ExecuteRequest, error::CliError};

#[derive(Debug, Deserialize)]
struct BatchFile {
    operations: Vec<BatchOperation>,
}

#[derive(Debug, Deserialize)]
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
    let batch: BatchFile = serde_json::from_str(&fs::read_to_string(path)?)?;
    let mut results = Vec::with_capacity(batch.operations.len());
    for operation in batch.operations {
        if !operation.arguments.is_object() {
            return Err(CliError::InvalidArguments(format!(
                "batch operation {} arguments must be a JSON object",
                operation.tool
            )));
        }
        let result = client.post(
            &format!("/cli/v1/tools/{}/execute", operation.tool),
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
            "next_cursor": null
        }
    }))
}
