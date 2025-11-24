# Python Sample File
# This file tests various Python patterns for constraint extraction

from typing import List, Dict, Optional, Any
from dataclasses import dataclass
import asyncio

# Dataclass with type hints
@dataclass
class User:
    id: int
    name: str
    email: str
    is_active: bool = True

# Type hints for function parameters and return values
def create_user(name: str, email: str) -> User:
    """Create a new user with the given name and email."""
    return User(id=0, name=name, email=email)

# Async function with type hints
async def fetch_user(user_id: int) -> Optional[User]:
    """Fetch a user from the database asynchronously."""
    try:
        # Simulate async database call
        await asyncio.sleep(0.1)
        return User(id=user_id, name="Test", email="test@example.com")
    except Exception as e:
        raise ValueError(f"Failed to fetch user: {e}")
    finally:
        print("Fetch operation completed")

# Lambda function
square = lambda x: x * x

# Class with methods
class UserService:
    def __init__(self, database: Any):
        self.db = database

    async def get_users(self) -> List[User]:
        """Get all users from the database."""
        try:
            users = await self.db.query("SELECT * FROM users")
            return [User(**u) for u in users]
        except Exception as e:
            print(f"Error fetching users: {e}")
            raise

    def update_user(self, user_id: int, updates: Dict[str, Any]) -> None:
        """Update a user with the given updates."""
        try:
            self.db.update("users", updates, {"id": user_id})
        except Exception:
            raise

# Decorator example
def log_calls(func):
    """Decorator to log function calls."""
    def wrapper(*args, **kwargs):
        print(f"Calling {func.__name__}")
        return func(*args, **kwargs)
    return wrapper

@log_calls
async def async_operation() -> str:
    """An async operation with a decorator."""
    await asyncio.sleep(0.1)
    return "completed"

# Type hints with generics
def process_items(items: List[str]) -> Dict[str, int]:
    """Process a list of items and return counts."""
    return {item: len(item) for item in items}
