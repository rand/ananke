"""
Data Model Test Fixture
Tests constraint extraction for:
- Pydantic-like models
- Field validators
- Model relationships
- Serialization
"""

from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any
from datetime import datetime, date
from decimal import Decimal
from enum import Enum
import re


class UserRole(Enum):
    """User role enumeration."""
    ADMIN = "admin"
    USER = "user"
    GUEST = "guest"


class AccountStatus(Enum):
    """Account status enumeration."""
    ACTIVE = "active"
    SUSPENDED = "suspended"
    DELETED = "deleted"


@dataclass
class Address:
    """Address model with validation constraints."""
    street: str
    city: str
    state: str
    zip_code: str
    country: str = "US"

    def __post_init__(self):
        # Street constraint
        if len(self.street) < 5 or len(self.street) > 100:
            raise ValueError("Street must be 5-100 characters")

        # City constraint
        if len(self.city) < 2 or len(self.city) > 50:
            raise ValueError("City must be 2-50 characters")

        # State constraint (US only)
        if self.country == "US":
            if len(self.state) != 2:
                raise ValueError("State must be 2 characters")
            if not self.state.isupper():
                raise ValueError("State must be uppercase")

        # Zip code constraint (US format)
        if self.country == "US":
            if not re.match(r'^\d{5}(-\d{4})?$', self.zip_code):
                raise ValueError("Invalid zip code format")

    def to_dict(self) -> Dict[str, str]:
        """Serialize to dictionary."""
        return {
            'street': self.street,
            'city': self.city,
            'state': self.state,
            'zip_code': self.zip_code,
            'country': self.country
        }


@dataclass
class UserProfile:
    """User profile with validation constraints."""
    user_id: int
    email: str
    username: str
    role: UserRole
    status: AccountStatus
    created_at: datetime
    last_login: Optional[datetime] = None
    address: Optional[Address] = None
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        # Email validation constraint
        if not self._is_valid_email(self.email):
            raise ValueError("Invalid email format")

        # Username constraints
        if len(self.username) < 3 or len(self.username) > 30:
            raise ValueError("Username must be 3-30 characters")

        if not re.match(r'^[a-zA-Z0-9_]+$', self.username):
            raise ValueError("Username can only contain alphanumeric and underscore")

    @staticmethod
    def _is_valid_email(email: str) -> bool:
        """Validate email format."""
        if len(email) > 255:
            return False
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))

    def is_admin(self) -> bool:
        """Check if user is admin."""
        return self.role == UserRole.ADMIN

    def is_active(self) -> bool:
        """Check if account is active."""
        return self.status == AccountStatus.ACTIVE

    def can_access_resource(self, resource: str, action: str) -> bool:
        """
        Check resource access with role-based constraints.
        
        Constraints:
        - Admin: Full access
        - User: Read all, write own
        - Guest: Read only public
        """
        if not self.is_active():
            return False

        if self.role == UserRole.ADMIN:
            return True

        if self.role == UserRole.USER:
            if action == "read":
                return True
            if action == "write":
                return resource.startswith(f"user_{self.user_id}_")
            return False

        if self.role == UserRole.GUEST:
            return action == "read" and resource.startswith("public_")

        return False

    def to_dict(self) -> Dict[str, Any]:
        """Serialize to dictionary."""
        return {
            'user_id': self.user_id,
            'email': self.email,
            'username': self.username,
            'role': self.role.value,
            'status': self.status.value,
            'created_at': self.created_at.isoformat(),
            'last_login': self.last_login.isoformat() if self.last_login else None,
            'address': self.address.to_dict() if self.address else None,
            'metadata': self.metadata
        }


@dataclass
class Product:
    """Product model with pricing constraints."""
    id: int
    name: str
    description: str
    price: Decimal
    stock_quantity: int
    category: str
    is_available: bool = True
    discount_percent: Decimal = Decimal('0')

    def __post_init__(self):
        # Name constraint
        if len(self.name) < 3 or len(self.name) > 100:
            raise ValueError("Product name must be 3-100 characters")

        # Price constraints
        if self.price < 0:
            raise ValueError("Price cannot be negative")

        if self.price > Decimal('999999.99'):
            raise ValueError("Price exceeds maximum")

        # Stock constraint
        if self.stock_quantity < 0:
            raise ValueError("Stock quantity cannot be negative")

        # Discount constraints
        if self.discount_percent < 0 or self.discount_percent > 100:
            raise ValueError("Discount must be 0-100%")

    def get_discounted_price(self) -> Decimal:
        """Calculate discounted price."""
        if self.discount_percent == 0:
            return self.price

        discount = self.price * (self.discount_percent / 100)
        return self.price - discount

    def is_in_stock(self) -> bool:
        """Check if product is in stock."""
        return self.stock_quantity > 0 and self.is_available

    def reduce_stock(self, quantity: int) -> None:
        """Reduce stock with validation."""
        if quantity <= 0:
            raise ValueError("Quantity must be positive")

        if quantity > self.stock_quantity:
            raise ValueError("Insufficient stock")

        self.stock_quantity -= quantity


@dataclass
class Order:
    """Order model with validation."""
    id: int
    user_id: int
    items: List[Dict[str, Any]]
    total_amount: Decimal
    status: str
    created_at: datetime
    shipping_address: Address
    payment_method: str

    def __post_init__(self):
        # Items constraint
        if not self.items:
            raise ValueError("Order must have at least one item")

        # Amount constraint
        if self.total_amount <= 0:
            raise ValueError("Total amount must be positive")

        # Status constraint
        valid_statuses = {'pending', 'confirmed', 'shipped', 'delivered', 'cancelled'}
        if self.status not in valid_statuses:
            raise ValueError(f"Invalid status: {self.status}")

        # Payment method constraint
        valid_payment_methods = {'credit_card', 'debit_card', 'paypal', 'bank_transfer'}
        if self.payment_method not in valid_payment_methods:
            raise ValueError(f"Invalid payment method: {self.payment_method}")

    def can_cancel(self) -> bool:
        """Check if order can be cancelled."""
        return self.status in {'pending', 'confirmed'}

    def can_ship(self) -> bool:
        """Check if order can be shipped."""
        return self.status == 'confirmed'
