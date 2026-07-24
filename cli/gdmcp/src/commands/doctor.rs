use serde_json::Value;

use crate::{client::ApiClient, error::CliError};

pub fn run(client: &ApiClient) -> Result<Value, CliError> {
    client.get("/cli/v1/doctor", &[])
}
