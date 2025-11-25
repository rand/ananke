"""
Validation Module Test Fixture
Tests constraint extraction for:
- Class-based validators
- Property decorators
- Type validation
- Custom exceptions
"""

from dataclasses import dataclass, field
from typing import Optional, List, Union, TypeVar, Generic
from abc import ABC, abstractmethod
import re
from decimal import Decimal
from datetime import date, datetime


class ValidationError(Exception):
    """Base exception for validation errors."""

    def __init__(self, field_name: str, message: str):
        self.field_name = field_name
        self.message = message
        super().__init__(f"{field_name}: {message}")


class EmailValidator:
    """Email validation with multiple constraints."""

    MAX_LENGTH = 255
    MIN_LENGTH = 3
    PATTERN = re.compile(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    )
    BLACKLISTED_DOMAINS = {'tempmail.com', 'throwaway.com', 'guerrillamail.com'}

    def __init__(self, check_mx: bool = False):
        self.check_mx = check_mx

    def validate(self, email: str) -> str:
        """
        Validate email address.

        Args:
            email: Email address to validate

        Returns:
            Normalized email address

        Raises:
            ValidationError: If email is invalid
        """
        if not email:
            raise ValidationError('email', 'Email is required')

        # Length constraints
        if len(email) < self.MIN_LENGTH:
            raise ValidationError(
                'email',
                f'Email must be at least {self.MIN_LENGTH} characters'
            )

        if len(email) > self.MAX_LENGTH:
            raise ValidationError(
                'email',
                f'Email must not exceed {self.MAX_LENGTH} characters'
            )

        # Format validation
        if not self.PATTERN.match(email):
            raise ValidationError('email', 'Invalid email format')

        # Domain validation
        domain = email.split('@')[1].lower()
        if domain in self.BLACKLISTED_DOMAINS:
            raise ValidationError('email', f'Domain {domain} is not allowed')

        # Normalize
        return email.lower()


class PhoneValidator:
    """Phone number validation with format constraints."""

    def __init__(self, country_code: str = 'US'):
        self.country_code = country_code

    def validate(self, phone: str) -> str:
        """
        Validate phone number.

        Args:
            phone: Phone number to validate

        Returns:
            Normalized phone number

        Raises:
            ValidationError: If phone number is invalid
        """
        # Remove all non-digits
        cleaned = re.sub(r'\D', '', phone)

        if self.country_code == 'US':
            return self._validate_us_phone(cleaned)
        else:
            raise NotImplementedError(f"Validation for {self.country_code} not implemented")

    def _validate_us_phone(self, phone: str) -> str:
        """Validate US phone number."""
        # Length constraint
        if len(phone) not in [10, 11]:
            raise ValidationError('phone', 'US phone must be 10 or 11 digits')

        # Country code constraint
        if len(phone) == 11 and not phone.startswith('1'):
            raise ValidationError('phone', '11-digit numbers must start with 1')

        # Area code constraint
        area_code = phone[1:4] if len(phone) == 11 else phone[:3]
        if area_code[0] in '01':
            raise ValidationError('phone', 'Invalid area code')

        return phone


@dataclass
class Address:
    """Address with validation constraints."""

    street: str
    city: str
    state: str
    zip_code: str
    country: str = 'US'

    def __post_init__(self):
        # Street validation
        if len(self.street) < 5 or len(self.street) > 100:
            raise ValidationError('street', 'Street must be between 5 and 100 characters')

        # City validation
        if len(self.city) < 2 or len(self.city) > 50:
            raise ValidationError('city', 'City must be between 2 and 50 characters')

        # State validation (US only)
        if self.country == 'US':
            if len(self.state) != 2:
                raise ValidationError('state', 'State must be 2-letter code')
            if not self.state.isupper():
                raise ValidationError('state', 'State must be uppercase')

        # Zip code validation
        if self.country == 'US':
            if not re.match(r'^\d{5}(-\d{4})?$', self.zip_code):
                raise ValidationError('zip_code', 'Invalid US zip code format')


T = TypeVar('T')


class Validator(ABC, Generic[T]):
    """Abstract base class for validators."""

    @abstractmethod
    def validate(self, value: T) -> T:
        """Validate and return normalized value."""
        pass


class RangeValidator(Validator[Union[int, float, Decimal]]):
    """Numeric range validator."""

    def __init__(self, min_value: Optional[float] = None, max_value: Optional[float] = None):
        self.min_value = min_value
        self.max_value = max_value

    def validate(self, value: Union[int, float, Decimal]) -> Union[int, float, Decimal]:
        """Validate numeric value is within range."""
        if self.min_value is not None and value < self.min_value:
            raise ValidationError(
                'value',
                f'Value must be at least {self.min_value}'
            )

        if self.max_value is not None and value > self.max_value:
            raise ValidationError(
                'value',
                f'Value must not exceed {self.max_value}'
            )

        return value


class StringValidator(Validator[str]):
    """String validation with multiple constraints."""

    def __init__(
        self,
        min_length: Optional[int] = None,
        max_length: Optional[int] = None,
        pattern: Optional[str] = None,
        allowed_chars: Optional[str] = None
    ):
        self.min_length = min_length
        self.max_length = max_length
        self.pattern = re.compile(pattern) if pattern else None
        self.allowed_chars = set(allowed_chars) if allowed_chars else None

    def validate(self, value: str) -> str:
        """Validate string value."""
        if not isinstance(value, str):
            raise ValidationError('value', 'Must be a string')

        # Length constraints
        if self.min_length is not None and len(value) < self.min_length:
            raise ValidationError(
                'value',
                f'Must be at least {self.min_length} characters'
            )

        if self.max_length is not None and len(value) > self.max_length:
            raise ValidationError(
                'value',
                f'Must not exceed {self.max_length} characters'
            )

        # Pattern constraint
        if self.pattern and not self.pattern.match(value):
            raise ValidationError('value', 'Does not match required pattern')

        # Character constraint
        if self.allowed_chars:
            invalid_chars = set(value) - self.allowed_chars
            if invalid_chars:
                raise ValidationError(
                    'value',
                    f'Contains invalid characters: {invalid_chars}'
                )

        return value


class DateValidator(Validator[date]):
    """Date validation with range constraints."""

    def __init__(
        self,
        min_date: Optional[date] = None,
        max_date: Optional[date] = None,
        allow_future: bool = True,
        allow_past: bool = True
    ):
        self.min_date = min_date
        self.max_date = max_date
        self.allow_future = allow_future
        self.allow_past = allow_past

    def validate(self, value: date) -> date:
        """Validate date value."""
        today = date.today()

        # Future date constraint
        if not self.allow_future and value > today:
            raise ValidationError('date', 'Future dates are not allowed')

        # Past date constraint
        if not self.allow_past and value < today:
            raise ValidationError('date', 'Past dates are not allowed')

        # Range constraints
        if self.min_date and value < self.min_date:
            raise ValidationError(
                'date',
                f'Date must be on or after {self.min_date}'
            )

        if self.max_date and value > self.max_date:
            raise ValidationError(
                'date',
                f'Date must be on or before {self.max_date}'
            )

        return value


@dataclass
class FormData:
    """Form data with validation."""

    name: str
    email: str
    phone: str
    age: int
    birth_date: date
    address: Address
    terms_accepted: bool = False

    def validate(self) -> 'FormData':
        """Validate all form fields."""
        errors: List[ValidationError] = []

        # Name validation
        name_validator = StringValidator(min_length=2, max_length=50)
        try:
            self.name = name_validator.validate(self.name)
        except ValidationError as e:
            errors.append(e)

        # Email validation
        email_validator = EmailValidator()
        try:
            self.email = email_validator.validate(self.email)
        except ValidationError as e:
            errors.append(e)

        # Phone validation
        phone_validator = PhoneValidator()
        try:
            self.phone = phone_validator.validate(self.phone)
        except ValidationError as e:
            errors.append(e)

        # Age validation
        age_validator = RangeValidator(min_value=18, max_value=120)
        try:
            self.age = age_validator.validate(self.age)
        except ValidationError as e:
            errors.append(e)

        # Birth date validation
        date_validator = DateValidator(
            min_date=date(1900, 1, 1),
            max_date=date.today(),
            allow_future=False
        )
        try:
            self.birth_date = date_validator.validate(self.birth_date)
        except ValidationError as e:
            errors.append(e)

        # Terms acceptance constraint
        if not self.terms_accepted:
            errors.append(ValidationError('terms_accepted', 'Terms must be accepted'))

        if errors:
            raise ValidationError(
                'form',
                f"Validation failed with {len(errors)} errors: {errors}"
            )

        return self


def validate_credit_card(number: str) -> bool:
    """
    Validate credit card number using Luhn algorithm.

    Args:
        number: Credit card number (digits only)

    Returns:
        True if valid, False otherwise
    """
    # Remove spaces and hyphens
    number = re.sub(r'[\s-]', '', number)

    # Must be digits only
    if not number.isdigit():
        return False

    # Length constraint (common card lengths)
    if len(number) not in [13, 14, 15, 16, 19]:
        return False

    # Luhn algorithm
    digits = [int(d) for d in number]
    checksum = 0

    for i, digit in enumerate(reversed(digits[:-1])):
        if i % 2 == 0:
            doubled = digit * 2
            checksum += doubled if doubled < 10 else doubled - 9
        else:
            checksum += digit

    return (checksum + digits[-1]) % 10 == 0


class PasswordPolicy:
    """Password policy with configurable constraints."""

    def __init__(
        self,
        min_length: int = 8,
        max_length: int = 128,
        require_uppercase: bool = True,
        require_lowercase: bool = True,
        require_digit: bool = True,
        require_special: bool = True,
        special_chars: str = '!@#$%^&*()_+-=[]{}|;:,.<>?'
    ):
        self.min_length = min_length
        self.max_length = max_length
        self.require_uppercase = require_uppercase
        self.require_lowercase = require_lowercase
        self.require_digit = require_digit
        self.require_special = require_special
        self.special_chars = special_chars

    def validate(self, password: str) -> List[str]:
        """
        Validate password against policy.

        Returns:
            List of policy violations (empty if valid)
        """
        violations = []

        # Length constraints
        if len(password) < self.min_length:
            violations.append(f"Password must be at least {self.min_length} characters")

        if len(password) > self.max_length:
            violations.append(f"Password must not exceed {self.max_length} characters")

        # Character type constraints
        if self.require_uppercase and not re.search(r'[A-Z]', password):
            violations.append("Password must contain uppercase letters")

        if self.require_lowercase and not re.search(r'[a-z]', password):
            violations.append("Password must contain lowercase letters")

        if self.require_digit and not re.search(r'\d', password):
            violations.append("Password must contain digits")

        if self.require_special:
            if not any(c in self.special_chars for c in password):
                violations.append("Password must contain special characters")

        return violations