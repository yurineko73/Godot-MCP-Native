use serde_json::{json, Value};

use crate::{cli::ResourcesCommand, client::ApiClient, error::CliError};

use super::tool_call::call;

pub fn run(client: &ApiClient, command: ResourcesCommand) -> Result<Value, CliError> {
    match command {
        ResourcesCommand::List {
            search_path,
            resource_types,
            limit,
        } => {
            let arguments = json!({
                "search_path": search_path,
                "resource_types": resource_types,
            });
            call(
                client,
                "list_project_resources",
                arguments,
                false,
                false,
                None,
                limit,
                None,
            )
        }
    }
}
