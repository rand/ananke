"""Tests for Dataclass Validation Implementation"""

import pytest
from dataclasses import dataclass
from dataclass_validation import (
    ValidationError,
    ValidatorRegistry,
    validated,
    validate_instance,
    register_validator,
    not_empty,
    min_length,
    max_length,
    in_range,
    positive,
    non_negative,
    matches_pattern,
    is_email,
    is_url,
    one_of,
    is_type,
    ValidatedField,
    create_validated_dataclass
)


class TestValidatorRegistry:
    def test_registers_validators(self):
        registry = ValidatorRegistry()
        registry.register("field", lambda x: x > 0, "must be positive")
        assert len(registry.get_validators("field")) == 1

    def test_validates_with_registered_validators(self):
        registry = ValidatorRegistry()
        registry.register("age", lambda x: x > 0, "must be positive")
        registry.register("age", lambda x: x < 150, "must be realistic")

        assert registry.validate("age", 30) == []
        assert registry.validate("age", -5) == ["must be positive"]
        assert registry.validate("age", 200) == ["must be realistic"]

    def test_returns_empty_for_unknown_field(self):
        registry = ValidatorRegistry()
        assert registry.validate("unknown", 42) == []


class TestValidatedDecorator:
    def test_validates_on_init(self):
        @dataclass
        class Person:
            name: str
            age: int

        register_validator(Person, "age", positive, "must be positive")
        Person = validated(Person)

        with pytest.raises(ValidationError):
            Person(name="John", age=-5)

    def test_allows_valid_values(self):
        @dataclass
        class Person:
            name: str
            age: int

        register_validator(Person, "age", positive, "must be positive")
        Person = validated(Person)

        person = Person(name="John", age=30)
        assert person.age == 30


class TestCommonValidators:
    def test_not_empty_with_strings(self):
        assert not_empty("hello")
        assert not not_empty("")
        assert not not_empty("   ")
        assert not not_empty(None)

    def test_not_empty_with_collections(self):
        assert not_empty([1, 2, 3])
        assert not not_empty([])
        assert not_empty({"key": "value"})
        assert not not_empty({})

    def test_min_length(self):
        validator = min_length(3)
        assert validator("abc")
        assert validator("abcd")
        assert not validator("ab")
        assert not validator(None)

    def test_max_length(self):
        validator = max_length(5)
        assert validator("abc")
        assert validator("abcde")
        assert not validator("abcdef")
        assert validator(None)  # None passes max_length

    def test_in_range(self):
        validator = in_range(0, 100)
        assert validator(50)
        assert validator(0)
        assert validator(100)
        assert not validator(-1)
        assert not validator(101)
        assert not validator(None)

    def test_positive(self):
        assert positive(1)
        assert positive(0.5)
        assert not positive(0)
        assert not positive(-1)
        assert not positive(None)

    def test_non_negative(self):
        assert non_negative(0)
        assert non_negative(1)
        assert not non_negative(-1)
        assert not non_negative(None)

    def test_matches_pattern(self):
        validator = matches_pattern(r"^\d{3}-\d{4}$")
        assert validator("123-4567")
        assert not validator("1234567")
        assert not validator("abc-defg")
        assert not validator(None)

    def test_is_email(self):
        assert is_email("test@example.com")
        assert is_email("user.name@domain.org")
        assert not is_email("invalid")
        assert not is_email("@example.com")
        assert not is_email(None)

    def test_is_url(self):
        assert is_url("https://example.com")
        assert is_url("http://localhost:3000")
        assert not is_url("not a url")
        assert not is_url("ftp://example.com")  # Only http/https
        assert not is_url(None)

    def test_one_of(self):
        validator = one_of(["red", "green", "blue"])
        assert validator("red")
        assert validator("green")
        assert not validator("yellow")
        assert not validator(None)

    def test_is_type(self):
        int_validator = is_type(int)
        assert int_validator(42)
        assert not int_validator("42")
        assert not int_validator(3.14)


class TestValidatedField:
    def test_validates_on_set(self):
        class Person:
            age = ValidatedField(
                default=0,
                validators=[(positive, "must be positive")]
            )

        person = Person()
        person.age = 30
        assert person.age == 30

        with pytest.raises(ValidationError, match="must be positive"):
            person.age = -5

    def test_uses_default(self):
        class Person:
            age = ValidatedField(default=18)

        person = Person()
        assert person.age == 18

    def test_multiple_validators(self):
        class Person:
            age = ValidatedField(
                validators=[
                    (positive, "must be positive"),
                    (lambda x: x < 150, "must be realistic")
                ]
            )

        person = Person()

        with pytest.raises(ValidationError, match="must be positive"):
            person.age = -5

        with pytest.raises(ValidationError, match="must be realistic"):
            person.age = 200


class TestCreateValidatedDataclass:
    def test_creates_dataclass_with_validators(self):
        User = create_validated_dataclass("User", {
            "name": {
                "type": str,
                "validators": [(not_empty, "name cannot be empty")]
            },
            "age": {
                "type": int,
                "default": 0,
                "validators": [(positive, "age must be positive")]
            }
        })

        user = User(name="John", age=30)
        assert user.name == "John"
        assert user.age == 30

        with pytest.raises(ValidationError):
            User(name="", age=30)

        with pytest.raises(ValidationError):
            User(name="John", age=-5)

    def test_creates_dataclass_with_defaults(self):
        Config = create_validated_dataclass("Config", {
            "debug": {
                "type": bool,
                "default": False
            },
            "port": {
                "type": int,
                "default": 8080,
                "validators": [(in_range(1, 65535), "invalid port")]
            }
        })

        config = Config()
        assert config.debug is False
        assert config.port == 8080


class TestIntegration:
    def test_user_registration_validation(self):
        @dataclass
        class UserRegistration:
            username: str
            email: str
            password: str
            age: int

        register_validator(UserRegistration, "username", min_length(3), "username must be at least 3 characters")
        register_validator(UserRegistration, "email", is_email, "invalid email format")
        register_validator(UserRegistration, "password", min_length(8), "password must be at least 8 characters")
        register_validator(UserRegistration, "age", in_range(13, 120), "age must be between 13 and 120")

        UserRegistration = validated(UserRegistration)

        # Valid registration
        user = UserRegistration(
            username="johndoe",
            email="john@example.com",
            password="securepassword123",
            age=30
        )
        assert user.username == "johndoe"

        # Invalid username
        with pytest.raises(ValidationError, match="username"):
            UserRegistration(
                username="jd",
                email="john@example.com",
                password="securepassword123",
                age=30
            )

        # Invalid email
        with pytest.raises(ValidationError, match="email"):
            UserRegistration(
                username="johndoe",
                email="invalid",
                password="securepassword123",
                age=30
            )
