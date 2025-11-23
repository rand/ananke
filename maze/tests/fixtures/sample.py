# Sample Python code for constraint extraction testing
from typing import Optional, Dict
from dataclasses import dataclass

@dataclass
class UserAuth:
    username: str
    password: str
    email: Optional[str] = None

class AuthService:
    def __init__(self):
        self.users: Dict[str, UserAuth] = {}
    
    async def authenticate(self, username: str, password: str) -> bool:
        """Authenticate a user with username and password."""
        user = self.users.get(username)
        if not user:
            return False
        return user.password == password
    
    def register(self, user: UserAuth) -> None:
        """Register a new user."""
        if user.username in self.users:
            raise ValueError("User already exists")
        self.users[user.username] = user
