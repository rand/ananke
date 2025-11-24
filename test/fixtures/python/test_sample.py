"""Sample Python test file with pytest assertions for testing the assertion parser"""

import pytest
from typing import Any, Optional, Dict, List


def test_email_validation():
    """Test email validation function"""
    assert validate_email('test@example.com') == True
    assert validate_email('user.name+tag@domain.co.uk') == True
    assert validate_email('invalid') == False
    assert validate_email('') == False
    assert validate_email('missing@domain') == False


def test_email_validation_with_none():
    """Test that email validator raises exception for None input"""
    with pytest.raises(ValueError):
        validate_email(None)

    with pytest.raises(ValueError, match="Input cannot be null"):
        validate_email(None)


class TestUserService:
    """Test suite for user service functionality"""

    def test_create_user_with_valid_data(self):
        """Test user creation with valid input"""
        user = create_user({
            'name': 'John Doe',
            'email': 'john@example.com',
            'age': 25
        })

        assert user is not None
        assert user['name'] == 'John Doe'
        assert user['email'] == 'john@example.com'
        assert user['age'] > 0
        assert user['age'] < 150
        assert user['is_active'] is True

    def test_reject_invalid_user_data(self):
        """Test that invalid user data is rejected"""
        result = create_user({'name': '', 'email': 'invalid'})
        assert result is None
        assert not result

    def test_find_user_by_id(self):
        """Test finding user by ID"""
        user = find_user_by_id('123')
        assert user is not None
        assert user != {}
        assert isinstance(user, dict)


class TestStringUtils:
    """Test suite for string utility functions"""

    def test_format_strings(self):
        """Test string formatting functions"""
        assert to_upper_case('hello') == 'HELLO'
        assert to_lower_case('WORLD') == 'world'
        assert capitalize('test') == 'Test'

    def test_string_membership(self):
        """Test string contains operations"""
        assert 'b' in parse_csv('a,b,c')
        assert 'hello' in split_words('hello world')

    def test_type_checking(self):
        """Test type validation"""
        result = process_string('test')
        assert isinstance(result, str)
        assert isinstance(parse_int('123'), int)
        assert isinstance(parse_float('3.14'), float)


class TestMathOperations:
    """Test suite for mathematical operations"""

    def test_basic_calculations(self):
        """Test basic arithmetic operations"""
        assert add(2, 3) == 5
        assert subtract(10, 4) == 6
        assert multiply(3, 7) == 21
        assert divide(15, 3) == 5

    def test_edge_cases(self):
        """Test edge cases in math operations"""
        assert divide(10, 0) == float('inf')
        assert factorial(0) == 1
        assert is_prime(17) == True
        assert is_prime(18) == False

    def test_comparisons(self):
        """Test comparison operations"""
        assert max_value(5, 3) > 4
        assert min_value(2, 8) < 3
        assert clamp(15, 0, 10) <= 10
        assert clamp(-5, 0, 10) >= 0

    def test_range_validation(self):
        """Test value range validation"""
        assert 5 in range(0, 10)
        assert 15 not in range(0, 10)


def test_object_operations():
    """Test object manipulation functions"""
    original = {'a': 1, 'b': {'c': 2}}
    cloned = deep_clone(original)

    assert cloned == original
    assert cloned is not original
    assert id(cloned) != id(original)


def test_async_operations():
    """Test asynchronous operations"""
    import asyncio

    async def async_test():
        result = await fetch_data('https://api.example.com')
        assert result is not None
        assert len(result) > 0

    asyncio.run(async_test())


def test_complex_conditions():
    """Test complex conditional logic"""
    result = process_data({'type': 'user', 'status': 'active'})

    assert result
    assert result['processed'] == True
    assert result.get('errors') is None
    assert 'warnings' not in result or result['warnings'] is None


def test_exception_handling():
    """Test exception handling patterns"""
    with pytest.raises(KeyError):
        access_missing_key({})

    with pytest.raises(TypeError, match="Invalid type"):
        process_invalid_type("string_instead_of_int")

    with pytest.raises(ValueError) as exc_info:
        validate_range(-1, 0, 100)
    assert "out of range" in str(exc_info.value)


def test_list_operations():
    """Test list manipulation functions"""
    items = [1, 2, 3, 4, 5]

    assert 3 in items
    assert 6 not in items
    assert sum_list(items) == 15
    assert average_list(items) == 3.0


def test_string_patterns():
    """Test string pattern matching"""
    import re

    phone = format_phone('1234567890')
    assert re.match(r'\d{3}-\d{3}-\d{4}', phone)

    date = format_date('2024-01-01')
    assert re.match(r'\d{4}-\d{2}-\d{2}', date)


@pytest.mark.parametrize("input,expected", [
    (0, 1),
    (1, 1),
    (5, 120),
    (10, 3628800)
])
def test_factorial_parametrized(input, expected):
    """Test factorial with multiple inputs"""
    assert factorial(input) == expected


@pytest.fixture
def sample_user():
    """Fixture for sample user data"""
    return {
        'id': '123',
        'name': 'Test User',
        'email': 'test@example.com'
    }


def test_with_fixture(sample_user):
    """Test using pytest fixture"""
    assert sample_user['id'] == '123'
    assert sample_user['name'] == 'Test User'
    assert 'email' in sample_user