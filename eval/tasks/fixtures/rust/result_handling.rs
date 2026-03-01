//! Result Error Handling Implementation
//! Demonstrates idiomatic Rust error handling with custom types

use std::fmt;
use std::fs;
use std::io;
use std::path::Path;

#[derive(Debug)]
pub enum ConfigError {
    IoError(io::Error),
    ParseError(String),
    MissingField(String),
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConfigError::IoError(e) => write!(f, "IO error: {}", e),
            ConfigError::ParseError(msg) => write!(f, "Parse error: {}", msg),
            ConfigError::MissingField(field) => write!(f, "Missing field: {}", field),
        }
    }
}

impl std::error::Error for ConfigError {}

impl From<io::Error> for ConfigError {
    fn from(err: io::Error) -> Self {
        ConfigError::IoError(err)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct Config {
    pub name: String,
    pub port: u16,
    pub debug: bool,
}

pub fn load_config<P: AsRef<Path>>(path: P) -> Result<Config, ConfigError> {
    let content = fs::read_to_string(path)?;
    parse_config(&content)
}

pub fn parse_config(content: &str) -> Result<Config, ConfigError> {
    let mut name: Option<String> = None;
    let mut port: Option<u16> = None;
    let mut debug: Option<bool> = None;

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        let parts: Vec<&str> = line.splitn(2, '=').collect();
        if parts.len() != 2 {
            continue;
        }

        let key = parts[0].trim();
        let value = parts[1].trim().trim_matches('"');

        match key {
            "name" => name = Some(value.to_string()),
            "port" => {
                port = Some(value.parse().map_err(|_| {
                    ConfigError::ParseError(format!("Invalid port: {}", value))
                })?);
            }
            "debug" => {
                debug = Some(match value.to_lowercase().as_str() {
                    "true" | "1" | "yes" => true,
                    "false" | "0" | "no" => false,
                    _ => {
                        return Err(ConfigError::ParseError(format!(
                            "Invalid boolean: {}",
                            value
                        )))
                    }
                });
            }
            _ => {}
        }
    }

    Ok(Config {
        name: name.ok_or_else(|| ConfigError::MissingField("name".to_string()))?,
        port: port.ok_or_else(|| ConfigError::MissingField("port".to_string()))?,
        debug: debug.unwrap_or(false),
    })
}

pub fn load_config_with_defaults<P: AsRef<Path>>(
    path: P,
    defaults: Config,
) -> Result<Config, ConfigError> {
    match load_config(path) {
        Ok(config) => Ok(config),
        Err(ConfigError::IoError(e)) if e.kind() == io::ErrorKind::NotFound => Ok(defaults),
        Err(e) => Err(e),
    }
}
