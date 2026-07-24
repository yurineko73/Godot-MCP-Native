use serde_json::Value;

use crate::{
    args::parse_json_input, cli::ToolCallArgs, client::ApiClient, contracts::ExecuteRequest,
    error::CliError, output::write_output,
};

const OUTPUT_FILE_MAX_BYTES: usize = 4 * 1024 * 1024;

pub fn execute(client: &ApiClient, args: ToolCallArgs) -> Result<Value, CliError> {
    let max_bytes = args
        .max_bytes
        .or_else(|| args.out.as_ref().map(|_| OUTPUT_FILE_MAX_BYTES));
    let request = ExecuteRequest {
        arguments: parse_json_input(args.args_json, args.args_file)?,
        dry_run: args.dry_run,
        apply_confirmed: args.apply,
        allow_open_world: args.allow_open_world,
        fields: args.fields,
        limit: args.limit,
        cursor: args.cursor,
        depth: args.depth,
        max_bytes,
    };
    let value = client.post(&format!("/cli/v1/tools/{}/execute", args.name), &request)?;
    if let Some(path) = args.out {
        return write_output(&path, &value);
    }
    Ok(value)
}

#[allow(clippy::too_many_arguments)]
pub fn call(
    client: &ApiClient,
    name: &str,
    arguments: Value,
    apply: bool,
    allow_open_world: bool,
    fields: Option<Vec<String>>,
    limit: Option<usize>,
    depth: Option<i32>,
) -> Result<Value, CliError> {
    call_with_options(
        client,
        name,
        arguments,
        apply,
        allow_open_world,
        fields,
        limit,
        None,
        depth,
        None,
    )
}

#[allow(clippy::too_many_arguments)]
pub fn call_with_options(
    client: &ApiClient,
    name: &str,
    arguments: Value,
    apply: bool,
    allow_open_world: bool,
    fields: Option<Vec<String>>,
    limit: Option<usize>,
    cursor: Option<String>,
    depth: Option<i32>,
    max_bytes: Option<usize>,
) -> Result<Value, CliError> {
    client.post(
        &format!("/cli/v1/tools/{name}/execute"),
        &ExecuteRequest {
            arguments,
            dry_run: false,
            apply_confirmed: apply,
            allow_open_world,
            fields,
            limit,
            cursor,
            depth,
            max_bytes,
        },
    )
}
