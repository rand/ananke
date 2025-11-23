/// Sample Rust async HTTP handler for constraint extraction
/// Demonstrates type safety, error handling, and async patterns

use std::sync::Arc;
use tokio::sync::RwLock;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

// Type constraint: Explicit error types
#[derive(Debug)]
pub enum ApiError {
    NotFound(String),
    BadRequest(String),
    Unauthorized,
    InternalError(String),
}

// Type constraint: Serialize/Deserialize for API models
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: u64,
    pub email: String,
    pub username: String,
    pub created_at: DateTime<Utc>,
    #[serde(skip_serializing)]
    password_hash: String, // Security constraint: Never serialize password
}

// Type constraint: Request validation at type level
#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    #[serde(deserialize_with = "validate_email")]
    pub email: String,
    #[serde(deserialize_with = "validate_username")]
    pub username: String,
    pub password: String,
}

// Security constraint: Email validation
fn validate_email<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let email = String::deserialize(deserializer)?;
    // Semantic constraint: Must be valid email format
    if !email.contains('@') || !email.contains('.') {
        return Err(serde::de::Error::custom("Invalid email format"));
    }
    Ok(email)
}

// Security constraint: Username validation
fn validate_username<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let username = String::deserialize(deserializer)?;
    // Semantic constraint: Username length bounds
    if username.len() < 3 || username.len() > 50 {
        return Err(serde::de::Error::custom("Username must be 3-50 characters"));
    }
    // Semantic constraint: Alphanumeric usernames only
    if !username.chars().all(|c| c.is_alphanumeric()) {
        return Err(serde::de::Error::custom("Username must be alphanumeric"));
    }
    Ok(username)
}

// Type constraint: Pagination parameters with bounds
#[derive(Debug, Deserialize)]
pub struct PaginationQuery {
    #[serde(default = "default_page")]
    pub page: u32,
    #[serde(default = "default_limit")]
    pub limit: u32,
}

// Operational constraint: Default pagination values
fn default_page() -> u32 {
    1
}

fn default_limit() -> u32 {
    10
}

impl PaginationQuery {
    /// Semantic constraint: Validate pagination bounds
    pub fn validate(&self) -> Result<(), ApiError> {
        if self.page < 1 {
            return Err(ApiError::BadRequest("Page must be >= 1".to_string()));
        }
        if self.limit < 1 || self.limit > 100 {
            return Err(ApiError::BadRequest(
                "Limit must be between 1 and 100".to_string(),
            ));
        }
        Ok(())
    }

    /// Calculate offset for database queries
    pub fn offset(&self) -> u32 {
        (self.page - 1) * self.limit
    }
}

// Architectural constraint: Repository pattern for data access
pub struct UserRepository {
    users: Arc<RwLock<Vec<User>>>,
}

impl UserRepository {
    pub fn new() -> Self {
        Self {
            users: Arc::new(RwLock::new(Vec::new())),
        }
    }

    /// Create a new user
    /// Error handling constraint: Returns Result type
    pub async fn create(&self, req: CreateUserRequest) -> Result<User, ApiError> {
        // Security constraint: Hash password before storage
        let password_hash = hash_password(&req.password)?;

        let mut users = self.users.write().await;

        // Semantic constraint: Check for duplicate email
        if users.iter().any(|u| u.email == req.email) {
            return Err(ApiError::BadRequest("Email already exists".to_string()));
        }

        // Semantic constraint: Check for duplicate username
        if users.iter().any(|u| u.username == req.username) {
            return Err(ApiError::BadRequest("Username already exists".to_string()));
        }

        let user = User {
            id: (users.len() as u64) + 1,
            email: req.email,
            username: req.username,
            created_at: Utc::now(),
            password_hash,
        };

        users.push(user.clone());
        Ok(user)
    }

    /// List users with pagination
    pub async fn list(&self, pagination: PaginationQuery) -> Result<Vec<User>, ApiError> {
        // Error handling constraint: Validate input first
        pagination.validate()?;

        let users = self.users.read().await;
        let offset = pagination.offset() as usize;
        let limit = pagination.limit as usize;

        // Semantic constraint: Handle out-of-bounds gracefully
        let result: Vec<User> = users
            .iter()
            .skip(offset)
            .take(limit)
            .cloned()
            .collect();

        Ok(result)
    }

    /// Get user by ID
    pub async fn get(&self, user_id: u64) -> Result<User, ApiError> {
        let users = self.users.read().await;

        // Error handling constraint: Return NotFound for missing users
        users
            .iter()
            .find(|u| u.id == user_id)
            .cloned()
            .ok_or_else(|| ApiError::NotFound(format!("User {} not found", user_id)))
    }

    /// Soft delete user
    pub async fn delete(&self, user_id: u64) -> Result<(), ApiError> {
        let users = self.users.read().await;

        // Semantic constraint: Verify user exists before deletion
        if !users.iter().any(|u| u.id == user_id) {
            return Err(ApiError::NotFound(format!("User {} not found", user_id)));
        }

        // TODO: Implement soft delete (set is_active = false)
        // In production, would use a database with soft delete support
        Ok(())
    }
}

// Security constraint: Password hashing with strong algorithm
fn hash_password(password: &str) -> Result<String, ApiError> {
    // Semantic constraint: Password must meet minimum length
    if password.len() < 8 {
        return Err(ApiError::BadRequest(
            "Password must be at least 8 characters".to_string(),
        ));
    }

    // Security constraint: Check password complexity
    let has_uppercase = password.chars().any(|c| c.is_uppercase());
    let has_lowercase = password.chars().any(|c| c.is_lowercase());
    let has_digit = password.chars().any(|c| c.is_numeric());

    if !has_uppercase || !has_lowercase || !has_digit {
        return Err(ApiError::BadRequest(
            "Password must contain uppercase, lowercase, and digit".to_string(),
        ));
    }

    // TODO: Use bcrypt or argon2 for actual hashing
    Ok(format!("hashed_{}", password))
}

// Architectural constraint: Handler layer separated from repository
pub async fn handle_create_user(
    repo: Arc<UserRepository>,
    req: CreateUserRequest,
) -> Result<User, ApiError> {
    // Security constraint: Never log passwords
    log::info!("Creating user: {}", req.username);

    match repo.create(req).await {
        Ok(user) => {
            log::info!("User created successfully: {}", user.id);
            Ok(user)
        }
        Err(e) => {
            // Error handling constraint: Log errors before returning
            log::error!("User creation failed: {:?}", e);
            Err(e)
        }
    }
}

pub async fn handle_list_users(
    repo: Arc<UserRepository>,
    pagination: PaginationQuery,
) -> Result<Vec<User>, ApiError> {
    repo.list(pagination).await
}

pub async fn handle_get_user(
    repo: Arc<UserRepository>,
    user_id: u64,
) -> Result<User, ApiError> {
    repo.get(user_id).await
}

pub async fn handle_delete_user(
    repo: Arc<UserRepository>,
    user_id: u64,
) -> Result<(), ApiError> {
    repo.delete(user_id).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_user() {
        // Type constraint: Test demonstrates expected types
        let repo = Arc::new(UserRepository::new());
        let req = CreateUserRequest {
            email: "test@example.com".to_string(),
            username: "testuser".to_string(),
            password: "Password123".to_string(),
        };

        let result = handle_create_user(repo, req).await;
        assert!(result.is_ok());
    }

    #[test]
    fn test_pagination_validation() {
        // Semantic constraint: Pagination validation tested
        let valid = PaginationQuery { page: 1, limit: 10 };
        assert!(valid.validate().is_ok());

        let invalid_page = PaginationQuery { page: 0, limit: 10 };
        assert!(invalid_page.validate().is_err());

        let invalid_limit = PaginationQuery { page: 1, limit: 101 };
        assert!(invalid_limit.validate().is_err());
    }
}
