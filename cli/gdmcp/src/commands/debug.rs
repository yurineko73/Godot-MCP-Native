use serde_json::{json, Value};

use crate::{cli::DebugCommand, client::ApiClient, error::CliError, output::write_output};

use super::tool_call::{call, call_with_options, OUTPUT_FILE_MAX_BYTES};

pub fn run(client: &ApiClient, command: DebugCommand) -> Result<Value, CliError> {
    match command {
        DebugCommand::Logs {
            level,
            limit,
            cursor,
            out,
        } => {
            let mut arguments = json!({"source": "mcp", "order": "desc"});
            if let Some(level) = level {
                arguments["type"] = json!([level]);
            }
            arguments["count"] = json!(limit);
            if let Some(cursor) = cursor {
                let offset = cursor.parse::<usize>().map_err(|_| {
                    CliError::InvalidArguments(
                        "debug logs cursor must be a non-negative integer".to_string(),
                    )
                })?;
                arguments["offset"] = json!(offset);
            }
            let value = call_with_options(
                client,
                "get_editor_logs",
                arguments,
                false,
                false,
                None,
                None,
                None,
                None,
                out.as_ref().map(|_| OUTPUT_FILE_MAX_BYTES),
            )?;
            if let Some(path) = out {
                return write_output(&path, &value);
            }
            Ok(value)
        }
        DebugCommand::Clear { apply } => call(
            client,
            "clear_output",
            json!({}),
            apply,
            false,
            None,
            None,
            None,
        ),
    }
}
