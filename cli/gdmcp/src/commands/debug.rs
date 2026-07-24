use serde_json::{json, Value};

use crate::{cli::DebugCommand, client::ApiClient, error::CliError, output::write_output};

use super::tool_call::call;

pub fn run(client: &ApiClient, command: DebugCommand) -> Result<Value, CliError> {
    match command {
        DebugCommand::Logs { level, limit, out } => {
            let mut arguments = json!({"source": "mcp", "order": "desc"});
            if let Some(level) = level {
                arguments["type"] = json!([level]);
            }
            if let Some(limit) = limit {
                arguments["count"] = json!(limit);
            }
            let value = call(
                client,
                "get_editor_logs",
                arguments,
                false,
                false,
                None,
                None,
                None,
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
