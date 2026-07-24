use serde_json::{json, Value};

use crate::{cli::ProjectCommand, client::ApiClient, error::CliError};

use super::tool_call::call;

pub fn run(client: &ApiClient, command: ProjectCommand) -> Result<Value, CliError> {
    match command {
        ProjectCommand::Info => call(
            client,
            "get_project_info",
            json!({}),
            false,
            false,
            None,
            None,
            None,
        ),
        ProjectCommand::Settings => call(
            client,
            "get_project_settings",
            json!({}),
            false,
            false,
            None,
            None,
            None,
        ),
        ProjectCommand::Run => call(
            client,
            "run_project",
            json!({}),
            false,
            false,
            None,
            None,
            None,
        ),
        ProjectCommand::Stop => call(
            client,
            "stop_project",
            json!({}),
            false,
            false,
            None,
            None,
            None,
        ),
    }
}
