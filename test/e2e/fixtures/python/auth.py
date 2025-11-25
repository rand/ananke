"""
Authentication Module Test Fixture
Tests constraint extraction for:
- Type hints and annotations
- Dataclasses
- Exception handling
- Decorators
"""

from dataclasses import dataclass
from typing import Optional, Dict, Any, Literal
from datetime import datetime, timedelta
import hashlib
import secrets
import re


@dataclass
class User:
    """User model with validation constraints."""

    id: int
    email: str
    username: str
    role: Literal['admin', 'user', 'guest']
    created_at: datetime
    last_login: Optional[datetime] = None

    def __post_init__(self):
        # Username constraints
        if len(self.username) < 3 or len(self.username) > 30:
            raise ValueError("Username must be between 3 and 30 characters")

        if not re.match(r'^[a-zA-Z0-9_]+$', self.username):
            raise ValueError("Username can only contain letters, numbers, and underscores")

        # Email validation
        if not self._is_valid_email(self.email):
            raise ValueError("Invalid email format")

    @staticmethod
    def _is_valid_email(email: str) -> bool:
        """Validate email format with constraints."""
        if len(email) > 255:
            return False

        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))


@dataclass
class AuthCredentials:
    """Authentication credentials with validation."""

    email: str
    password: str
    remember_me: bool = False

    def __post_init__(self):
        # Email constraint
        if not self.email:
            raise ValueError("Email is required")

        # Password constraints
        if len(self.password) < 8:
            raise ValueError("Password must be at least 8 characters")

        if len(self.password) > 128:
            raise ValueError("Password cannot exceed 128 characters")


class AuthenticationError(Exception):
    """Custom exception for authentication failures."""
    pass


class RateLimitError(AuthenticationError):
    """Exception for rate limit violations."""

    def __init__(self, retry_after: int):
        self.retry_after = retry_after
        super().__init__(f"Rate limit exceeded. Retry after {retry_after} seconds")


class SessionManager:
    """Manages user sessions with constraints."""

    MAX_SESSION_DURATION = timedelta(hours=24)
    MAX_ACTIVE_SESSIONS = 5

    def __init__(self):
        self._sessions: Dict[str, Dict[str, Any]] = {}
        self._failed_attempts: Dict[str, int] = {}

    def authenticate(self, credentials: AuthCredentials) -> tuple[Optional[User], Optional[str]]:
        """
        Authenticate user with rate limiting.

        Returns:
            Tuple of (user, token) if successful, (None, None) otherwise
        """
        # Check rate limiting
        if self._is_rate_limited(credentials.email):
            raise RateLimitError(retry_after=60)

        # Simulate authentication
        if not self._verify_password(credentials.password):
            self._record_failed_attempt(credentials.email)
            return None, None

        # Create session
        user = self._create_user(credentials.email)
        token = self._generate_token()

        # Enforce max sessions constraint
        self._cleanup_old_sessions(user.id)

        self._sessions[token] = {
            'user': user,
            'created_at': datetime.now(),
            'expires_at': datetime.now() + self.MAX_SESSION_DURATION
        }

        return user, token

    def _is_rate_limited(self, email: str) -> bool:
        """Check if email is rate limited (5 failed attempts)."""
        return self._failed_attempts.get(email, 0) >= 5

    def _record_failed_attempt(self, email: str):
        """Record a failed login attempt."""
        self._failed_attempts[email] = self._failed_attempts.get(email, 0) + 1

    def _verify_password(self, password: str) -> bool:
        """Verify password meets security requirements."""
        # Check minimum requirements
        has_lower = any(c.islower() for c in password)
        has_upper = any(c.isupper() for c in password)
        has_digit = any(c.isdigit() for c in password)
        has_special = any(c in '!@#$%^&*()_+-=' for c in password)

        return all([has_lower, has_upper, has_digit, has_special])

    def _generate_token(self) -> str:
        """Generate secure session token."""
        return secrets.token_urlsafe(32)

    def _create_user(self, email: str) -> User:
        """Create a user object (simulation)."""
        return User(
            id=1,
            email=email,
            username=email.split('@')[0],
            role='user',
            created_at=datetime.now()
        )

    def _cleanup_old_sessions(self, user_id: int):
        """Remove old sessions to enforce max sessions constraint."""
        user_sessions = [
            (token, session)
            for token, session in self._sessions.items()
            if session['user'].id == user_id
        ]

        # Sort by creation time
        user_sessions.sort(key=lambda x: x[1]['created_at'])

        # Remove oldest sessions if exceeding limit
        while len(user_sessions) >= self.MAX_ACTIVE_SESSIONS:
            token_to_remove = user_sessions.pop(0)[0]
            del self._sessions[token_to_remove]

    def validate_token(self, token: str) -> Optional[User]:
        """Validate session token and return user."""
        session = self._sessions.get(token)

        if not session:
            return None

        # Check expiration
        if datetime.now() > session['expires_at']:
            del self._sessions[token]
            return None

        return session['user']

    def logout(self, token: str) -> bool:
        """Logout user by invalidating token."""
        if token in self._sessions:
            del self._sessions[token]
            return True
        return False


def hash_password(password: str, salt: Optional[str] = None) -> tuple[str, str]:
    """
    Hash password with salt.

    Args:
        password: Plain text password
        salt: Optional salt (generated if not provided)

    Returns:
        Tuple of (hashed_password, salt)
    """
    if not salt:
        salt = secrets.token_hex(16)

    # Constraint: Use strong hashing algorithm
    hashed = hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        salt.encode('utf-8'),
        100_000  # iterations constraint
    )

    return hashed.hex(), salt


def check_permission(user: User, resource: str, action: str) -> bool:
    """
    Check if user has permission for action on resource.

    Role-based access control with constraints:
    - Admin: Full access
    - User: Read all, write own resources
    - Guest: Read only public resources
    """
    if user.role == 'admin':
        return True

    if user.role == 'user':
        if action == 'read':
            return True
        if action == 'write':
            return resource.startswith(f'user_{user.id}_')
        return False

    if user.role == 'guest':
        return action == 'read' and resource.startswith('public_')

    return False


# Password strength validator
def validate_password_strength(password: str) -> Dict[str, Any]:
    """
    Validate password strength with multiple constraints.

    Returns:
        Dictionary with score and feedback
    """
    score = 0
    feedback = []

    # Length constraints
    if len(password) >= 8:
        score += 1
    else:
        feedback.append("Use at least 8 characters")

    if len(password) >= 12:
        score += 1

    if len(password) >= 16:
        score += 1

    # Character type constraints
    if re.search(r'[a-z]', password):
        score += 1
    else:
        feedback.append("Include lowercase letters")

    if re.search(r'[A-Z]', password):
        score += 1
    else:
        feedback.append("Include uppercase letters")

    if re.search(r'[0-9]', password):
        score += 1
    else:
        feedback.append("Include numbers")

    if re.search(r'[!@#$%^&*()_+\-=\[\]{};\':"\\|,.<>\/?]', password):
        score += 1
    else:
        feedback.append("Include special characters")

    # Common password check
    common_passwords = [
        'password', '12345678', 'qwerty', 'abc123',
        'password123', 'admin', 'letmein'
    ]

    if password.lower() in common_passwords:
        score = 0
        feedback = ["Password is too common"]

    return {
        'score': score,
        'max_score': 7,
        'is_strong': score >= 5,
        'feedback': feedback
    }