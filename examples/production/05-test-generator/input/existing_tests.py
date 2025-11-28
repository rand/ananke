"""
Example test patterns for constraint extraction.

This file demonstrates best practices for pytest tests that will be used
as a template for generating new tests.
"""

import pytest
from decimal import Decimal
from typing import List, Tuple


class TestCalculateShippingCost:
    """
    Example test class showing patterns for:
    - Class-based organization
    - Descriptive test names
    - Parametrized tests
    - Error testing with pytest.raises
    - Clear assertions with custom messages
    """

    def test_basic_shipping_cost(self):
        """Test basic shipping calculation without extras."""
        result = calculate_shipping_cost(weight=5.0, distance=100)
        expected = Decimal('15.00')  # $0.10/lb * 5lb + $0.10/mi * 100mi
        assert result == expected, f"Expected {expected}, got {result}"

    def test_zero_weight(self):
        """Test that zero weight is handled correctly."""
        result = calculate_shipping_cost(weight=0.0, distance=100)
        expected = Decimal('10.00')  # Only distance cost
        assert result == expected

    def test_zero_distance(self):
        """Test that zero distance is handled correctly."""
        result = calculate_shipping_cost(weight=5.0, distance=0)
        expected = Decimal('5.00')  # Only weight cost
        assert result == expected

    @pytest.mark.parametrize(
        "weight,distance,expected",
        [
            (1.0, 10, Decimal('2.00')),
            (10.0, 100, Decimal('20.00')),
            (100.0, 1000, Decimal('200.00')),
        ],
        ids=["small", "medium", "large"],
    )
    def test_shipping_cost_parametrized(
        self, weight: float, distance: int, expected: Decimal
    ):
        """Test various weight/distance combinations."""
        result = calculate_shipping_cost(weight=weight, distance=distance)
        assert result == expected

    @pytest.mark.parametrize(
        "weight,distance,error_message",
        [
            (-1.0, 100, "Weight cannot be negative"),
            (5.0, -10, "Distance cannot be negative"),
            (0.0, 0, "Weight and distance cannot both be zero"),
        ],
        ids=["negative_weight", "negative_distance", "both_zero"],
    )
    def test_invalid_inputs(self, weight: float, distance: int, error_message: str):
        """Test that invalid inputs raise appropriate errors."""
        with pytest.raises(ValueError, match=error_message):
            calculate_shipping_cost(weight=weight, distance=distance)

    def test_with_express_shipping(self):
        """Test express shipping adds correct surcharge."""
        result = calculate_shipping_cost(weight=5.0, distance=100, express=True)
        base_cost = Decimal('15.00')
        surcharge = base_cost * Decimal('0.5')  # 50% surcharge
        expected = base_cost + surcharge
        assert result == expected

    def test_with_insurance(self):
        """Test insurance adds correct amount."""
        result = calculate_shipping_cost(
            weight=5.0, distance=100, insurance_value=Decimal('1000.00')
        )
        base_cost = Decimal('15.00')
        insurance = Decimal('1000.00') * Decimal('0.01')  # 1% of value
        expected = base_cost + insurance
        assert result == expected

    def test_combined_options(self):
        """Test multiple options combined correctly."""
        result = calculate_shipping_cost(
            weight=5.0,
            distance=100,
            express=True,
            insurance_value=Decimal('1000.00'),
        )
        base_cost = Decimal('15.00')
        express_surcharge = base_cost * Decimal('0.5')
        insurance = Decimal('1000.00') * Decimal('0.01')
        expected = base_cost + express_surcharge + insurance
        assert result == expected


class TestCalculateTax:
    """Example showing edge case and boundary testing patterns."""

    def test_standard_tax_rate(self):
        """Test standard 8.5% tax rate."""
        result = calculate_tax(amount=Decimal('100.00'), state='CA')
        expected = Decimal('8.50')
        assert result == expected

    def test_no_tax_state(self):
        """Test that OR has no sales tax."""
        result = calculate_tax(amount=Decimal('100.00'), state='OR')
        expected = Decimal('0.00')
        assert result == expected

    def test_case_insensitive_state(self):
        """Test that state codes are case-insensitive."""
        result_upper = calculate_tax(amount=Decimal('100.00'), state='CA')
        result_lower = calculate_tax(amount=Decimal('100.00'), state='ca')
        assert result_upper == result_lower

    @pytest.mark.parametrize(
        "amount",
        [
            Decimal('0.00'),
            Decimal('0.01'),
            Decimal('999999.99'),
        ],
        ids=["zero", "minimum", "maximum"],
    )
    def test_boundary_amounts(self, amount: Decimal):
        """Test boundary conditions for amounts."""
        result = calculate_tax(amount=amount, state='CA')
        # Tax should be 8.5% of amount
        expected = amount * Decimal('0.085')
        assert result == expected

    def test_precision(self):
        """Test that tax calculation maintains precision."""
        result = calculate_tax(amount=Decimal('99.99'), state='CA')
        # Should round to 2 decimal places
        expected = Decimal('8.50')  # 99.99 * 0.085 = 8.49915, rounds to 8.50
        assert result == expected
        # Verify it's exactly 2 decimal places
        assert result.as_tuple().exponent == -2

    def test_invalid_state_code(self):
        """Test that invalid state codes raise errors."""
        with pytest.raises(ValueError, match="Invalid state code"):
            calculate_tax(amount=Decimal('100.00'), state='XX')

    def test_negative_amount(self):
        """Test that negative amounts raise errors."""
        with pytest.raises(ValueError, match="Amount cannot be negative"):
            calculate_tax(amount=Decimal('-100.00'), state='CA')


# Helper/stub functions for demonstration
def calculate_shipping_cost(
    weight: float,
    distance: int,
    express: bool = False,
    insurance_value: Decimal = Decimal('0'),
) -> Decimal:
    """Stub function for demonstration."""
    if weight < 0:
        raise ValueError("Weight cannot be negative")
    if distance < 0:
        raise ValueError("Distance cannot be negative")
    if weight == 0 and distance == 0:
        raise ValueError("Weight and distance cannot both be zero")

    base = Decimal(str(weight)) * Decimal('1.00') + Decimal(str(distance)) * Decimal('0.10')
    if express:
        base += base * Decimal('0.5')
    if insurance_value > 0:
        base += insurance_value * Decimal('0.01')
    return base


def calculate_tax(amount: Decimal, state: str) -> Decimal:
    """Stub function for demonstration."""
    if amount < 0:
        raise ValueError("Amount cannot be negative")

    state = state.upper()
    tax_rates = {
        'CA': Decimal('0.085'),
        'NY': Decimal('0.08'),
        'OR': Decimal('0.00'),
    }

    if state not in tax_rates:
        raise ValueError("Invalid state code")

    tax = amount * tax_rates[state]
    return tax.quantize(Decimal('0.01'))  # Round to 2 decimal places
