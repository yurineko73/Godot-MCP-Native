use std::{fs, path::PathBuf};

use serde_json::Value;

use crate::error::CliError;

pub fn parse_json_input(inline: Option<String>, file: Option<PathBuf>) -> Result<Value, CliError> {
    let value = match (inline, file) {
        (Some(_), Some(_)) => {
            return Err(CliError::InvalidArguments(
                "use exactly one of --args-json and --args-file".to_string(),
            ));
        }
        (Some(value), None) => serde_json::from_str(&value)?,
        (None, Some(path)) => serde_json::from_str(&fs::read_to_string(path)?)?,
        (None, None) => Value::Object(Default::default()),
    };
    if !value.is_object() {
        return Err(CliError::InvalidArguments(
            "tool arguments must be a JSON object".to_string(),
        ));
    }
    Ok(value)
}

pub fn parse_value(value: String, value_json: bool) -> Result<Value, CliError> {
    if value_json {
        Ok(serde_json::from_str(&value)?)
    } else {
        Ok(Value::String(value))
    }
}
