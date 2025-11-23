// Sample Rust code for constraint extraction testing
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct UserAuth {
    pub username: String,
    pub password: String,
    pub email: Option<String>,
}

pub struct AuthService {
    users: HashMap<String, UserAuth>,
}

impl AuthService {
    pub fn new() -> Self {
        Self {
            users: HashMap::new(),
        }
    }
    
    pub async fn authenticate(&self, username: &str, password: &str) -> Result<bool, String> {
        match self.users.get(username) {
            Some(user) => Ok(user.password == password),
            None => Ok(false),
        }
    }
    
    pub fn register(&mut self, user: UserAuth) -> Result<(), String> {
        if self.users.contains_key(&user.username) {
            return Err("User already exists".to_string());
        }
        self.users.insert(user.username.clone(), user);
        Ok(())
    }
}
