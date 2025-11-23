"""
Sample Python FastAPI endpoint for constraint extraction
Demonstrates type hints, async patterns, and validation
"""

from typing import Optional, List
from datetime import datetime
from fastapi import FastAPI, HTTPException, Depends, status
from pydantic import BaseModel, EmailStr, Field, validator
import logging

# Configure logging
logger = logging.getLogger(__name__)

# Type constraint: Pydantic models enforce schema
class UserCreate(BaseModel):
    """Request model for creating a user"""
    email: EmailStr  # Type constraint: Email validation
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8)

    @validator('username')
    def username_alphanumeric(cls, v: str) -> str:
        """Semantic constraint: Username must be alphanumeric"""
        if not v.isalnum():
            raise ValueError('Username must be alphanumeric')
        return v.lower()

    @validator('password')
    def password_strength(cls, v: str) -> str:
        """Security constraint: Password must meet complexity requirements"""
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain uppercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain digit')
        return v


class User(BaseModel):
    """User model with type constraints"""
    id: int
    email: EmailStr
    username: str
    created_at: datetime
    is_active: bool = True  # Operational constraint: Users start active
    role: str = "user"  # Security constraint: Default role is user


class UserResponse(BaseModel):
    """Response model excluding sensitive fields"""
    id: int
    email: EmailStr
    username: str
    created_at: datetime
    is_active: bool

    class Config:
        # Architectural constraint: Use ORM mode for database models
        orm_mode = True


class PaginationParams(BaseModel):
    """Type constraint: Pagination parameters"""
    page: int = Field(default=1, ge=1)  # Semantic constraint: Page >= 1
    limit: int = Field(default=10, ge=1, le=100)  # Semantic constraint: Limit bounds


# Initialize FastAPI app
app = FastAPI(title="User Service")


async def get_current_user() -> User:
    """
    Security constraint: Authentication required
    Dependency injection pattern for auth
    """
    # Placeholder for actual auth logic
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required"
    )


@app.post(
    "/users",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED
)
async def create_user(user_data: UserCreate) -> UserResponse:
    """
    Create a new user with validation

    Constraints demonstrated:
    - Type safety: All parameters and returns typed
    - Validation: Pydantic models validate input
    - Security: Password hashing (placeholder)
    - Error handling: HTTP exceptions for failures
    """
    try:
        # Security constraint: Never log passwords
        logger.info(f"Creating user: {user_data.username}")

        # Security constraint: Hash password before storage
        hashed_password = await hash_password(user_data.password)

        # Simulate database insertion
        # TODO: Replace with actual database call
        new_user = User(
            id=1,
            email=user_data.email,
            username=user_data.username,
            created_at=datetime.utcnow()
        )

        return UserResponse(**new_user.dict())

    except ValueError as e:
        # Error handling constraint: Validation errors return 400
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        # Error handling constraint: Unexpected errors return 500
        logger.error(f"User creation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create user"
        )


@app.get("/users", response_model=List[UserResponse])
async def list_users(
    pagination: PaginationParams = Depends(),
    current_user: User = Depends(get_current_user)
) -> List[UserResponse]:
    """
    List users with pagination

    Constraints:
    - Security: Authentication required via dependency
    - Type safety: Typed parameters and response
    - Semantic: Pagination prevents unbounded queries
    """
    # Architectural constraint: Dependency injection for auth
    logger.info(f"User {current_user.username} listing users")

    # Calculate offset from pagination
    offset = (pagination.page - 1) * pagination.limit

    # Simulate database query
    # TODO: Replace with actual query
    users: List[User] = []

    return [UserResponse(**user.dict()) for user in users]


@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: int,
    current_user: User = Depends(get_current_user)
) -> UserResponse:
    """
    Get specific user by ID

    Constraints:
    - Security: Authentication required
    - Error handling: 404 if not found
    - Type safety: ID is integer
    """
    # Syntactic constraint: Input validation
    if user_id < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID"
        )

    # Simulate database lookup
    user = await fetch_user_by_id(user_id)

    if not user:
        # Error handling constraint: 404 for missing resources
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User {user_id} not found"
        )

    return UserResponse(**user.dict())


@app.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: int,
    current_user: User = Depends(get_current_user)
) -> None:
    """
    Delete user (soft delete)

    Constraints:
    - Security: Only authenticated users can delete
    - Semantic: Soft delete (set is_active=False)
    - Operational: Return 204 No Content on success
    """
    # Security constraint: Check permissions
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin role required"
        )

    # Semantic constraint: Soft delete instead of hard delete
    user = await fetch_user_by_id(user_id)
    if user:
        user.is_active = False
        # await save_user(user)
        logger.info(f"User {user_id} soft deleted by {current_user.username}")


async def hash_password(password: str) -> str:
    """
    Security constraint: Hash passwords with bcrypt
    Placeholder for actual implementation
    """
    # TODO: Use bcrypt or argon2
    return f"hashed_{password}"


async def fetch_user_by_id(user_id: int) -> Optional[User]:
    """
    Database abstraction layer
    Architectural constraint: Separate data access
    """
    # TODO: Replace with actual database query
    return None


if __name__ == "__main__":
    # Operational constraint: Development server configuration
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
