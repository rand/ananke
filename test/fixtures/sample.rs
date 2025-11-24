// Rust Sample File
// This file tests various Rust patterns for constraint extraction

use std::collections::HashMap;
use std::error::Error;
use std::fmt;

// Struct definition
#[derive(Debug, Clone)]
struct User {
    id: u64,
    name: String,
    email: String,
    is_active: bool,
}

// Enum definition
#[derive(Debug)]
enum DatabaseError {
    ConnectionFailed,
    QueryFailed(String),
    NotFound,
}

impl fmt::Display for DatabaseError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            DatabaseError::ConnectionFailed => write!(f, "Connection failed"),
            DatabaseError::QueryFailed(msg) => write!(f, "Query failed: {}", msg),
            DatabaseError::NotFound => write!(f, "Not found"),
        }
    }
}

impl Error for DatabaseError {}

// Trait definition
trait UserRepository {
    fn get_user(&self, id: u64) -> Result<User, DatabaseError>;
    fn create_user(&mut self, name: &str, email: &str) -> Result<User, DatabaseError>;
}

// Struct implementing trait
struct InMemoryUserRepo {
    users: HashMap<u64, User>,
    next_id: u64,
}

impl InMemoryUserRepo {
    pub fn new() -> Self {
        InMemoryUserRepo {
            users: HashMap::new(),
            next_id: 1,
        }
    }
}

impl UserRepository for InMemoryUserRepo {
    fn get_user(&self, id: u64) -> Result<User, DatabaseError> {
        self.users
            .get(&id)
            .cloned()
            .ok_or(DatabaseError::NotFound)
    }

    fn create_user(&mut self, name: &str, email: &str) -> Result<User, DatabaseError> {
        let user = User {
            id: self.next_id,
            name: name.to_string(),
            email: email.to_string(),
            is_active: true,
        };
        self.users.insert(self.next_id, user.clone());
        self.next_id += 1;
        Ok(user)
    }
}

// Async function with Result type
async fn fetch_user_async(id: u64) -> Result<User, Box<dyn Error>> {
    // Simulate async operation
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

    Ok(User {
        id,
        name: "Test User".to_string(),
        email: "test@example.com".to_string(),
        is_active: true,
    })
}

// Function with references and lifetimes
fn process_user<'a>(user: &'a User, suffix: &str) -> String {
    format!("{} {}", user.name, suffix)
}

// Function with mutable reference
fn update_user_name(user: &mut User, new_name: &str) {
    user.name = new_name.to_string();
}

// Function using error propagation operator
fn get_and_process_user(repo: &impl UserRepository, id: u64) -> Result<String, DatabaseError> {
    let user = repo.get_user(id)?;
    Ok(process_user(&user, "processed"))
}

// Function with Option type
fn find_user_by_email(users: &[User], email: &str) -> Option<&User> {
    users.iter().find(|u| u.email == email)
}

// Memory management with Box, Rc, Arc
use std::rc::Rc;
use std::sync::Arc;

fn create_shared_user() -> Arc<User> {
    Arc::new(User {
        id: 1,
        name: "Shared User".to_string(),
        email: "shared@example.com".to_string(),
        is_active: true,
    })
}

// Module declaration
mod database {
    pub struct Connection;

    impl Connection {
        pub fn new() -> Self {
            Connection
        }
    }
}
