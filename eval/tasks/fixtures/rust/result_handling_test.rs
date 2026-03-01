#[path = "result_handling.rs"]
mod result_handling;

use result_handling::*;

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn test_parse_valid_config() {
        let content = r#"
            name = "test_app"
            port = 8080
            debug = true
        "#;
        let config = parse_config(content).unwrap();
        assert_eq!(config.name, "test_app");
        assert_eq!(config.port, 8080);
        assert!(config.debug);
    }

    #[test]
    fn test_parse_config_with_quotes() {
        let content = r#"
            name = "my app"
            port = 3000
            debug = false
        "#;
        let config = parse_config(content).unwrap();
        assert_eq!(config.name, "my app");
        assert_eq!(config.port, 3000);
        assert!(!config.debug);
    }

    #[test]
    fn test_parse_config_missing_name() {
        let content = r#"
            port = 8080
            debug = true
        "#;
        let result = parse_config(content);
        assert!(matches!(result, Err(ConfigError::MissingField(_))));
    }

    #[test]
    fn test_parse_config_missing_port() {
        let content = r#"
            name = "test"
            debug = true
        "#;
        let result = parse_config(content);
        assert!(matches!(result, Err(ConfigError::MissingField(_))));
    }

    #[test]
    fn test_parse_config_invalid_port() {
        let content = r#"
            name = "test"
            port = not_a_number
            debug = true
        "#;
        let result = parse_config(content);
        assert!(matches!(result, Err(ConfigError::ParseError(_))));
    }

    #[test]
    fn test_parse_config_invalid_bool() {
        let content = r#"
            name = "test"
            port = 8080
            debug = maybe
        "#;
        let result = parse_config(content);
        assert!(matches!(result, Err(ConfigError::ParseError(_))));
    }

    #[test]
    fn test_parse_config_debug_defaults_false() {
        let content = r#"
            name = "test"
            port = 8080
        "#;
        let config = parse_config(content).unwrap();
        assert!(!config.debug);
    }

    #[test]
    fn test_parse_config_with_comments() {
        let content = r#"
            # This is a comment
            name = "test"
            # Another comment
            port = 8080
        "#;
        let config = parse_config(content).unwrap();
        assert_eq!(config.name, "test");
    }

    #[test]
    fn test_load_config_file_not_found() {
        let result = load_config("/nonexistent/path/config.txt");
        assert!(matches!(result, Err(ConfigError::IoError(_))));
    }

    #[test]
    fn test_config_error_display() {
        let io_err = ConfigError::IoError(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            "file not found",
        ));
        assert!(io_err.to_string().contains("IO error"));

        let parse_err = ConfigError::ParseError("invalid".to_string());
        assert!(parse_err.to_string().contains("Parse error"));

        let missing_err = ConfigError::MissingField("name".to_string());
        assert!(missing_err.to_string().contains("Missing field"));
    }
}
