# Small Python fixture (<100 LOC)
# Simple class with validation

import re
from typing import Optional
from dataclasses import dataclass

@dataclass
class User:
    id: int
    name: str
    email: str

def validate_email(email: str) -> bool:
    """Validate email format using regex."""
    pattern = r'^[^\s@]+@[^\s@]+\.[^\s@]+$'
    return bool(re.match(pattern, email))

def create_user(name: str, email: str) -> Optional[User]:
    """Create a new user with validation."""
    if not validate_email(email):
        return None
    
    import random
    return User(
        id=random.randint(1, 10000),
        name=name.strip(),
        email=email.lower()
    )
