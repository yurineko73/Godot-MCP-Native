use std::fs;

use serde_json::{json, Value};

use crate::{cli::ScriptsCommand, client::ApiClient, error::CliError};

use super::tool_call::{call, call_with_options};

pub fn run(client: &ApiClient, command: ScriptsCommand) -> Result<Value, CliError> {
    match command {
        ScriptsCommand::List { limit, cursor } => call_with_options(
            client,
            "list_project_scripts",
            json!({"search_path": "res://"}),
            false,
            false,
            None,
            Some(limit),
            cursor,
            None,
            None,
        ),
        ScriptsCommand::Read { path, lines } => {
            let mut value = call(
                client,
                "read_script",
                json!({"script_path": path}),
                false,
                false,
                None,
                None,
                None,
            )?;
            if let Some(range) = lines {
                slice_read_script_content(&mut value, &range)?;
            }
            Ok(value)
        }
        ScriptsCommand::Validate { path } => call(
            client,
            "validate_script",
            json!({"script_path": path}),
            false,
            false,
            None,
            None,
            None,
        ),
        ScriptsCommand::Replace {
            path,
            content_file,
            apply,
        } => {
            require_apply(apply, "scripts replace")?;
            call(
                client,
                "modify_script",
                json!({
                    "script_path": path,
                    "content": fs::read_to_string(content_file)?
                }),
                true,
                false,
                None,
                None,
                None,
            )
        }
    }
}

fn slice_read_script_content(
    value: &mut Value,
    range: &crate::cli::LineRange,
) -> Result<(), CliError> {
    let content = value
        .pointer("/data/content")
        .and_then(Value::as_str)
        .ok_or_else(|| CliError::Api("read_script response missing content".to_string()))?;
    let lines: Vec<&str> = content.lines().collect();
    let total = lines.len();
    let start = range.start.saturating_sub(1);
    if start >= total {
        return Err(CliError::InvalidArguments(format!(
            "start line {} exceeds file length of {} lines",
            range.start, total
        )));
    }
    let end = range.end.unwrap_or(total).min(total);
    let sliced: String = lines[start..end].join("\n");
    if let Some(data) = value.pointer_mut("/data") {
        data["content"] = Value::String(sliced);
        data["line_count"] = Value::Number((end - start).into());
        data["line_offset"] = Value::Number(range.start.into());
    }
    Ok(())
}

fn require_apply(apply: bool, command: &str) -> Result<(), CliError> {
    if apply {
        Ok(())
    } else {
        Err(CliError::Permission(format!("{command} requires --apply")))
    }
}
