//! Complex authentication service for testing constraint extraction

use anyhow::Result;
use std::collections::HashMap;
use tokio::sync::RwLock;

#[derive(Debug, Clone)]
pub struct User {
    pub id: u64,
    pub username: String,
    pub email: String,
    pub password_hash: String,
}

#[derive(Debug, Clone)]
pub struct Session {
    pub id: String,
    pub user_id: u64,
    pub expires_at: i64,
}

pub struct AuthService {
    users: RwLock<HashMap<String, User>>,
    sessions: RwLock<HashMap<String, Session>>,
}

impl AuthService {
    pub fn new() -> Self {
        Self {
            users: RwLock::new(HashMap::new()),
            sessions: RwLock::new(HashMap::new()),
        }
    }

    /// Authenticate user and create session
    pub async fn authenticate(
        &self,
        username: &str,
        password: &str,
    ) -> Result<Session> {
        // Validate input
        if username.is_empty() || password.is_empty() {
            return Err(anyhow::anyhow!("Invalid credentials"));
        }

        // Find user
        let users = self.users.read().await;
        let user = users
            .get(username)
            .ok_or_else(|| anyhow::anyhow!("User not found"))?;

        // Verify password
        if !self.verify_password(password, &user.password_hash).await? {
            return Err(anyhow::anyhow!("Invalid password"));
        }

        // Create session
        let session = Session {
            id: uuid::Uuid::new_v4().to_string(),
            user_id: user.id,
            expires_at: chrono::Utc::now().timestamp() + 3600,
        };

        self.sessions.write().await.insert(session.id.clone(), session.clone());

        Ok(session)
    }

    async fn verify_password(&self, password: &str, hash: &str) -> Result<bool> {
        // Placeholder for password verification
        Ok(password == hash)
    }
}
