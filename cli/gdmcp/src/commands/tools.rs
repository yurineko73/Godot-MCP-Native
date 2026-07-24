use serde_json::Value;

use crate::{cli::ToolsCommand, client::ApiClient, error::CliError};

pub fn run(client: &ApiClient, command: ToolsCommand) -> Result<Value, CliError> {
    match command {
        ToolsCommand::Search { query, limit } => client.get(
            "/cli/v1/tools/search",
            &[("q", query), ("limit", limit.clamp(1, 20).to_string())],
        ),
        ToolsCommand::Schema { name } => client.get(&format!("/cli/v1/tools/{name}"), &[]),
        ToolsCommand::Catalog => client.get("/cli/v1/catalog", &[]),
    }
}
