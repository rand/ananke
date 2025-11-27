"""
API Handler Test Fixture
Tests constraint extraction for:
- FastAPI-like route handlers
- Request/response models
- Dependency injection
- Error handling
"""

from dataclasses import dataclass
from typing import Optional, Dict, Any, List, Callable
from datetime import datetime
from enum import Enum


class HTTPMethod(Enum):
    """HTTP method enumeration."""
    GET = "GET"
    POST = "POST"
    PUT = "PUT"
    DELETE = "DELETE"
    PATCH = "PATCH"


@dataclass
class Request:
    """HTTP request model."""
    method: HTTPMethod
    path: str
    body: Dict[str, Any]
    params: Dict[str, str]
    query: Dict[str, str]
    headers: Dict[str, str]


@dataclass
class Response:
    """HTTP response model."""
    status_code: int
    body: Any
    headers: Dict[str, str]

    @staticmethod
    def json(data: Any, status_code: int = 200) -> 'Response':
        """Create JSON response."""
        return Response(
            status_code=status_code,
            body=data,
            headers={'Content-Type': 'application/json'}
        )

    @staticmethod
    def error(message: str, status_code: int = 400) -> 'Response':
        """Create error response."""
        return Response.json({'error': message}, status_code)


@dataclass
class User:
    """User model with validation."""
    id: int
    email: str
    username: str
    created_at: datetime
    is_active: bool = True


class UserService:
    """User service with business logic constraints."""

    def __init__(self):
        self._users: Dict[int, User] = {}
        self._next_id = 1

    def get_user(self, user_id: int) -> Optional[User]:
        """Get user by ID."""
        return self._users.get(user_id)

    def create_user(self, email: str, username: str) -> User:
        """
        Create new user with validation constraints.
        
        Constraints:
        - Email must be valid format
        - Username must be 3-30 characters
        - Username must be unique
        """
        # Email validation constraint
        if '@' not in email or len(email) > 255:
            raise ValueError("Invalid email format")

        # Username length constraint
        if len(username) < 3 or len(username) > 30:
            raise ValueError("Username must be 3-30 characters")

        # Username uniqueness constraint
        for user in self._users.values():
            if user.username == username:
                raise ValueError("Username already exists")

        user = User(
            id=self._next_id,
            email=email,
            username=username,
            created_at=datetime.now()
        )
        self._users[user.id] = user
        self._next_id += 1

        return user

    def update_user(self, user_id: int, updates: Dict[str, Any]) -> Optional[User]:
        """
        Update user with immutability constraints.
        
        Constraints:
        - Cannot update id or created_at
        - Email must remain valid if changed
        """
        user = self._users.get(user_id)
        if not user:
            return None

        # Immutable field constraint
        immutable_fields = {'id', 'created_at'}
        for field in immutable_fields:
            if field in updates:
                raise ValueError(f"Cannot update {field}")

        # Email validation if updating email
        if 'email' in updates:
            email = updates['email']
            if '@' not in email or len(email) > 255:
                raise ValueError("Invalid email format")

        # Apply updates
        for key, value in updates.items():
            if hasattr(user, key):
                setattr(user, key, value)

        return user

    def delete_user(self, user_id: int) -> bool:
        """Delete user by ID."""
        if user_id in self._users:
            del self._users[user_id]
            return True
        return False


# Route handlers with validation
def get_user_handler(request: Request, service: UserService) -> Response:
    """GET /users/:id handler."""
    try:
        # ID parameter constraint
        user_id = int(request.params.get('id', '0'))
        if user_id <= 0:
            return Response.error("Invalid user ID", 400)

        user = service.get_user(user_id)
        if not user:
            return Response.error("User not found", 404)

        return Response.json({
            'id': user.id,
            'email': user.email,
            'username': user.username,
            'created_at': user.created_at.isoformat()
        })

    except ValueError as e:
        return Response.error(str(e), 400)


def create_user_handler(request: Request, service: UserService) -> Response:
    """POST /users handler with body validation."""
    try:
        # Required fields constraint
        email = request.body.get('email')
        username = request.body.get('username')

        if not email or not username:
            return Response.error("Email and username are required", 400)

        user = service.create_user(email, username)

        return Response.json({
            'id': user.id,
            'email': user.email,
            'username': user.username,
            'created_at': user.created_at.isoformat()
        }, 201)

    except ValueError as e:
        return Response.error(str(e), 400)


def update_user_handler(request: Request, service: UserService) -> Response:
    """PUT /users/:id handler."""
    try:
        user_id = int(request.params.get('id', '0'))
        if user_id <= 0:
            return Response.error("Invalid user ID", 400)

        updates = request.body
        user = service.update_user(user_id, updates)

        if not user:
            return Response.error("User not found", 404)

        return Response.json({
            'id': user.id,
            'email': user.email,
            'username': user.username
        })

    except ValueError as e:
        return Response.error(str(e), 400)


def delete_user_handler(request: Request, service: UserService) -> Response:
    """DELETE /users/:id handler with authorization."""
    try:
        user_id = int(request.params.get('id', '0'))
        auth_user_id = int(request.headers.get('x-user-id', '0'))

        # Authorization constraint
        if user_id != auth_user_id:
            return Response.error("Unauthorized", 403)

        if service.delete_user(user_id):
            return Response(status_code=204, body='', headers={})
        else:
            return Response.error("User not found", 404)

    except ValueError as e:
        return Response.error(str(e), 400)


# Middleware
def rate_limit_middleware(max_requests: int, window_seconds: int) -> Callable:
    """
    Rate limiting middleware with constraints.
    
    Constraints:
    - Track requests per client
    - Enforce max requests per window
    """
    requests: Dict[str, List[datetime]] = {}

    def middleware(request: Request, handler: Callable) -> Response:
        client_id = request.headers.get('x-client-id', 'unknown')
        now = datetime.now()

        # Clean old requests
        if client_id in requests:
            requests[client_id] = [
                ts for ts in requests[client_id]
                if (now - ts).total_seconds() < window_seconds
            ]
        else:
            requests[client_id] = []

        # Check rate limit
        if len(requests[client_id]) >= max_requests:
            return Response.error("Too many requests", 429)

        # Record request
        requests[client_id].append(now)

        return handler(request)

    return middleware
