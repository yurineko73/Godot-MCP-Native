use reqwest::{blocking::Client, header, StatusCode, Url};
use serde::Serialize;
use serde_json::{json, Value};

use crate::{config::Config, contracts::ApiErrorBody, error::CliError};

pub struct ApiClient {
    client: Client,
    config: Config,
}

impl ApiClient {
    pub fn new(config: Config) -> Result<Self, CliError> {
        let client = Client::builder().timeout(config.timeout).build()?;
        Ok(Self { client, config })
    }

    pub fn get(&self, path: &str, query: &[(&str, String)]) -> Result<Value, CliError> {
        let mut url = self.url(path)?;
        if !query.is_empty() {
            url.query_pairs_mut()
                .extend_pairs(query.iter().map(|(key, value)| (*key, value.as_str())));
        }
        let request = self.authorize(self.client.get(url));
        self.decode(request.send())
    }

    pub fn post<T: Serialize>(&self, path: &str, body: &T) -> Result<Value, CliError> {
        let request = self.authorize(self.client.post(self.url(path)?).json(body));
        self.decode(request.send())
    }

    fn url(&self, path: &str) -> Result<Url, CliError> {
        Url::parse(&format!("{}{}", self.config.base_url, path))
            .map_err(|error| CliError::Configuration(error.to_string()))
    }

    fn authorize(
        &self,
        mut request: reqwest::blocking::RequestBuilder,
    ) -> reqwest::blocking::RequestBuilder {
        request = request.header("X-GDMCP-API-Version", "1");
        if let Some(token) = &self.config.token {
            request = request.header(header::AUTHORIZATION, format!("Bearer {token}"));
        }
        request
    }

    fn decode(
        &self,
        response: Result<reqwest::blocking::Response, reqwest::Error>,
    ) -> Result<Value, CliError> {
        let response = response.map_err(|error| {
            if error.is_connect() || error.is_timeout() {
                CliError::Unreachable(error.to_string())
            } else {
                CliError::Http(error)
            }
        })?;
        let status = response.status();
        let text = response.text()?;
        let value: Value = serde_json::from_str(&text).unwrap_or_else(|_| {
            json!({
                "error": {
                    "code": "HTTP_STATUS",
                    "message": text
                }
            })
        });
        if status.is_success() {
            return Ok(value);
        }
        let error = value
            .get("error")
            .cloned()
            .and_then(|value| serde_json::from_value::<ApiErrorBody>(value).ok());
        let message = error
            .as_ref()
            .map(|error| format!("{}: {}", error.code, error.message))
            .unwrap_or_else(|| value.to_string());
        if error
            .as_ref()
            .is_some_and(|error| error.code == "API_VERSION_MISMATCH")
        {
            return Err(CliError::VersionMismatch(message));
        }
        match status {
            StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN => Err(CliError::Permission(message)),
            _ => Err(CliError::Api(message)),
        }
    }
}
