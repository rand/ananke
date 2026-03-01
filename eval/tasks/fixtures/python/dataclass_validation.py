"""
Dataclass Validation Implementation
Validation decorators and validators for dataclasses
"""

from dataclasses import dataclass, field, fields
from typing import Any, Callable, List, Optional, TypeVar, Type, get_type_hints
import re
from functools import wraps


T = TypeVar('T')


class ValidationError(Exception):
    """Raised when validation fails."""

    def __init__(self, field_name: str, message: str):
        self.field_name = field_name
        self.message = message
        super().__init__(f"{field_name}: {message}")


class ValidatorRegistry:
    """Registry for field validators."""

    def __init__(self):
        self._validators: dict = {}

    def register(self, field_name: str, validator: Callable[[Any], bool], message: str):
        """Register a validator for a field."""
        if field_name not in self._validators:
            self._validators[field_name] = []
        self._validators[field_name].append((validator, message))

    def validate(self, field_name: str, value: Any) -> List[str]:
        """Validate a field value. Returns list of error messages."""
        errors = []
        if field_name in self._validators:
            for validator, message in self._validators[field_name]:
                if not validator(value):
                    errors.append(message)
        return errors

    def get_validators(self, field_name: str) -> list:
        """Get all validators for a field."""
        return self._validators.get(field_name, [])


# Global registry for class validators
_class_validators: dict = {}


def validated(cls: Type[T]) -> Type[T]:
    """Decorator to add validation to a dataclass."""
    original_init = cls.__init__

    @wraps(original_init)
    def new_init(self, *args, **kwargs):
        original_init(self, *args, **kwargs)
        validate_instance(self)

    cls.__init__ = new_init
    return cls


def validate_instance(instance: Any) -> None:
    """Validate all fields of a dataclass instance."""
    cls = type(instance)
    if cls not in _class_validators:
        return

    registry = _class_validators[cls]
    errors = []

    for f in fields(instance):
        value = getattr(instance, f.name)
        field_errors = registry.validate(f.name, value)
        errors.extend([f"{f.name}: {e}" for e in field_errors])

    if errors:
        raise ValidationError("validation", "; ".join(errors))


def register_validator(cls: Type, field_name: str, validator: Callable[[Any], bool], message: str):
    """Register a validator for a class field."""
    if cls not in _class_validators:
        _class_validators[cls] = ValidatorRegistry()
    _class_validators[cls].register(field_name, validator, message)


# Common validators

def not_empty(value: Any) -> bool:
    """Check that a value is not empty."""
    if value is None:
        return False
    if isinstance(value, str):
        return len(value.strip()) > 0
    if isinstance(value, (list, dict, set)):
        return len(value) > 0
    return True


def min_length(length: int) -> Callable[[Any], bool]:
    """Create a validator that checks minimum length."""
    def validator(value: Any) -> bool:
        if value is None:
            return False
        return len(value) >= length
    return validator


def max_length(length: int) -> Callable[[Any], bool]:
    """Create a validator that checks maximum length."""
    def validator(value: Any) -> bool:
        if value is None:
            return True
        return len(value) <= length
    return validator


def in_range(min_val: float, max_val: float) -> Callable[[Any], bool]:
    """Create a validator that checks if a number is in range."""
    def validator(value: Any) -> bool:
        if value is None:
            return False
        return min_val <= value <= max_val
    return validator


def positive(value: Any) -> bool:
    """Check that a number is positive."""
    if value is None:
        return False
    return value > 0


def non_negative(value: Any) -> bool:
    """Check that a number is non-negative."""
    if value is None:
        return False
    return value >= 0


def matches_pattern(pattern: str) -> Callable[[Any], bool]:
    """Create a validator that checks if a string matches a regex pattern."""
    compiled = re.compile(pattern)
    def validator(value: Any) -> bool:
        if value is None:
            return False
        return bool(compiled.match(str(value)))
    return validator


def is_email(value: Any) -> bool:
    """Check if a value is a valid email address."""
    if value is None or not isinstance(value, str):
        return False
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, value))


def is_url(value: Any) -> bool:
    """Check if a value is a valid URL."""
    if value is None or not isinstance(value, str):
        return False
    pattern = r'^https?://[^\s/$.?#].[^\s]*$'
    return bool(re.match(pattern, value))


def one_of(allowed: list) -> Callable[[Any], bool]:
    """Create a validator that checks if value is in allowed list."""
    def validator(value: Any) -> bool:
        return value in allowed
    return validator


def is_type(expected_type: type) -> Callable[[Any], bool]:
    """Create a validator that checks if value is of expected type."""
    def validator(value: Any) -> bool:
        return isinstance(value, expected_type)
    return validator


# Field descriptor for validation

class ValidatedField:
    """Descriptor for validated fields."""

    def __init__(
        self,
        default: Any = None,
        validators: Optional[List[tuple]] = None
    ):
        self.default = default
        self.validators = validators or []
        self.name: str = ""

    def __set_name__(self, owner: Type, name: str):
        self.name = name

    def __get__(self, instance: Any, owner: Type) -> Any:
        if instance is None:
            return self
        return instance.__dict__.get(self.name, self.default)

    def __set__(self, instance: Any, value: Any):
        for validator, message in self.validators:
            if not validator(value):
                raise ValidationError(self.name, message)
        instance.__dict__[self.name] = value


def create_validated_dataclass(
    name: str,
    field_specs: dict
) -> Type:
    """
    Create a validated dataclass dynamically.

    field_specs format:
    {
        "field_name": {
            "type": type,
            "default": value,
            "validators": [(validator_func, error_message), ...]
        }
    }
    """
    annotations = {}
    defaults = {}

    for field_name, spec in field_specs.items():
        annotations[field_name] = spec.get("type", Any)
        if "default" in spec:
            defaults[field_name] = spec["default"]

    # Create the class
    cls = type(name, (), {
        "__annotations__": annotations,
        **defaults
    })

    # Apply dataclass decorator
    cls = dataclass(cls)

    # Register validators
    for field_name, spec in field_specs.items():
        for validator, message in spec.get("validators", []):
            register_validator(cls, field_name, validator, message)

    # Apply validated decorator
    cls = validated(cls)

    return cls
