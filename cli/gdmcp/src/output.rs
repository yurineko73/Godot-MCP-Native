use std::{fs, path::Path};

use serde_json::{json, Value};

use crate::error::CliError;

pub fn render(value: &Value, json_mode: bool) -> Result<(), CliError> {
    if json_mode {
        println!("{}", serde_json::to_string(value)?);
    } else {
        println!("{}", serde_json::to_string_pretty(value)?);
    }
    Ok(())
}

pub fn write_output(path: &Path, value: &Value) -> Result<Value, CliError> {
    let content = serde_json::to_vec_pretty(value)?;
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)?;
        }
    }
    fs::write(path, &content)?;
    Ok(json!({
        "schema_version": 1,
        "ok": true,
        "command": "output.write",
        "data": {
            "path": path.to_string_lossy(),
            "bytes": content.len()
        },
        "meta": {
            "truncated": false,
            "next_cursor": null
        }
    }))
}
