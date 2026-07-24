use serde_json::{json, Value};

use crate::{client::ApiClient, error::CliError};

use super::tool_call::call;

pub fn state(client: &ApiClient) -> Result<Value, CliError> {
    call(
        client,
        "get_editor_state",
        json!({}),
        false,
        false,
        None,
        None,
        None,
    )
}
