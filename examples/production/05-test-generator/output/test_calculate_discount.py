"""
Generated test suite for calculate_discount.

Auto-generated from function docstring specification.
"""

import pytest
from decimal import Decimal
from input.function_spec import calculate_discount


class TestCalculate_discount:
    """
    Comprehensive test suite for calculate_discount.

    Generated from docstring specifications with:
    - 10 happy path tests
    - 4 edge case tests
    - 6 error condition tests
    - 0 boundary tests

    Target coverage: >90%
    """

    # Happy Path

    def test_calculate_discount_happy_path_0(self):
        """Basic discount."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('10'))
        assert result == Decimal('90'), f"Expected {Decimal('90')}, got {result}"


    def test_calculate_discount_happy_path_1(self):
        """No discount."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('0'))
        assert result == Decimal('100'), f"Expected {Decimal('100')}, got {result}"


    def test_calculate_discount_happy_path_2(self):
        """Full discount."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('100'))
        assert result == Decimal('0'), f"Expected {Decimal('0')}, got {result}"


    def test_calculate_discount_happy_path_3(self):
        """With bronze tier."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('10'), member_tier="bronze")
        assert result == Decimal('88'), f"Expected {Decimal('88')}, got {result}"


    def test_calculate_discount_happy_path_4(self):
        """With silver tier."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('10'), member_tier="silver")
        assert result == Decimal('85'), f"Expected {Decimal('85')}, got {result}"


    def test_calculate_discount_happy_path_5(self):
        """With gold tier."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('10'), member_tier="gold")
        assert result == Decimal('85'), f"Expected {Decimal('85')}, got {result}"


    def test_calculate_discount_happy_path_6(self):
        """With platinum tier."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('10'), member_tier="platinum")
        assert result == Decimal('80'), f"Expected {Decimal('80')}, got {result}"


    def test_calculate_discount_happy_path_7(self):
        """Bulk discount (5 items)."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('10'), quantity=5)
        assert result == Decimal('85'), f"Expected {Decimal('85')}, got {result}"


    def test_calculate_discount_happy_path_8(self):
        """Bulk discount (10 items)."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('10'), quantity=10)
        assert result == Decimal('80'), f"Expected {Decimal('80')}, got {result}"


    def test_calculate_discount_happy_path_9(self):
        """Combined."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('10'), member_tier="gold", quantity=5)
        # 10% base + 5% gold tier + 5% bulk (qty>=5) = 20% total
        assert result == Decimal('80.0'), f"Expected {Decimal('80.0')}, got {result}"


    # Edge Cases

    def test_calculate_discount_edge_cases_10(self):
        """Zero price."""
        result = calculate_discount(original_price=Decimal('0'), discount_percent=Decimal('10'))
        assert result == Decimal('0'), f"Expected {Decimal('0')}, got {result}"


    def test_calculate_discount_edge_cases_11(self):
        """Very small price."""
        result = calculate_discount(original_price=Decimal('0.01'), discount_percent=Decimal('10'))
        # 0.01 - (0.01 * 0.10) = 0.009
        assert result == Decimal('0.009'), f"Expected {Decimal('0.009')}, got {result}"


    def test_calculate_discount_edge_cases_12(self):
        """Very large price."""
        result = calculate_discount(original_price=Decimal('999999.99'), discount_percent=Decimal('10'))
        # 999999.99 * 0.90 = 899999.991
        assert result == Decimal('899999.991'), f"Expected {Decimal('899999.991')}, got {result}"


    def test_calculate_discount_edge_cases_13(self):
        """High quantity."""
        result = calculate_discount(original_price=Decimal('100'), discount_percent=Decimal('10'), quantity=1000)
        # 10% base + 10% bulk (qty>=10) = 20% total, result is $80
        assert result == Decimal('80.0'), f"Expected {Decimal('80.0')}, got {result}"


    # Error Conditions

    def test_calculate_discount_error_conditions_14(self):
        """Negative price."""
        with pytest.raises(ValueError, match="Price cannot be negative"):
            calculate_discount(original_price=Decimal('-100.00'), discount_percent=Decimal('10'))


    def test_calculate_discount_error_conditions_15(self):
        """Negative discount."""
        with pytest.raises(ValueError, match="Discount must be between 0 and 100"):
            calculate_discount(original_price=Decimal('100.00'), discount_percent=Decimal('-10'))


    def test_calculate_discount_error_conditions_16(self):
        """Discount > 100."""
        with pytest.raises(ValueError, match="Discount must be between 0 and 100"):
            calculate_discount(original_price=Decimal('100.00'), discount_percent=Decimal('150'))


    def test_calculate_discount_error_conditions_17(self):
        """Invalid tier."""
        with pytest.raises(ValueError, match="Invalid member tier"):
            calculate_discount(original_price=Decimal('100.00'), discount_percent=Decimal('10'), member_tier="invalid_tier")


    def test_calculate_discount_error_conditions_18(self):
        """Zero quantity."""
        with pytest.raises(ValueError, match="Quantity must be at least 1"):
            calculate_discount(original_price=Decimal('100.00'), discount_percent=Decimal('10'), quantity=0)


    def test_calculate_discount_error_conditions_19(self):
        """Negative quantity."""
        with pytest.raises(ValueError, match="Quantity must be at least 1"):
            calculate_discount(original_price=Decimal('100.00'), discount_percent=Decimal('10'), quantity=-1)

