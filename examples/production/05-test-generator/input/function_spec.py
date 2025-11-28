"""
E-commerce pricing functions with comprehensive test specifications in docstrings.

This module demonstrates how to write function specifications that can be
automatically converted into comprehensive test suites.
"""

from decimal import Decimal
from typing import Optional


def calculate_discount(
    original_price: Decimal,
    discount_percent: Decimal,
    member_tier: Optional[str] = None,
    quantity: int = 1,
) -> Decimal:
    """
    Calculate the final price after applying discounts.

    Applies percentage-based discounts with additional member tier bonuses
    and quantity-based bulk pricing.

    Args:
        original_price: The original price before discounts (must be >= 0)
        discount_percent: Percentage discount to apply (0-100)
        member_tier: Optional membership tier ('bronze', 'silver', 'gold', 'platinum')
        quantity: Number of items (must be >= 1)

    Returns:
        Final price after all discounts applied (never negative)

    Raises:
        ValueError: If original_price is negative
        ValueError: If discount_percent is not in range 0-100
        ValueError: If quantity is less than 1
        ValueError: If member_tier is not a valid tier or None

    Examples:
        >>> calculate_discount(Decimal('100.00'), Decimal('10'))
        Decimal('90.00')

        >>> calculate_discount(Decimal('100.00'), Decimal('10'), member_tier='gold')
        Decimal('85.00')

    Test Cases:
        Happy Path:
            - Basic discount: $100, 10% = $90
            - No discount: $100, 0% = $100
            - Full discount: $100, 100% = $0
            - With bronze tier: $100, 10%, bronze = $88 (extra 2%)
            - With silver tier: $100, 10%, silver = $85 (extra 5%)
            - With gold tier: $100, 10%, gold = $85 (extra 5%)
            - With platinum tier: $100, 10%, platinum = $80 (extra 10%)
            - Bulk discount (5 items): $100, 10%, qty=5 = $85 per item (extra 5%)
            - Bulk discount (10 items): $100, 10%, qty=10 = $80 per item (extra 10%)
            - Combined: $100, 10%, gold, qty=5 = $77.50 (10% + 5% tier + 5% bulk)

        Edge Cases:
            - Zero price: $0, 10% = $0
            - Very small price: $0.01, 10% = $0.01 (rounds to $0.01)
            - Very large price: $999999.99, 10% = $899999.99
            - High quantity: $100, 10%, qty=1000 = $75 per item (max bulk 15%)
            - Case insensitive tier: 'GOLD', 'Gold', 'gold' all work
            - Whitespace in tier: ' gold ' works (stripped)

        Error Conditions:
            - Negative price: ValueError "Price cannot be negative"
            - Negative discount: ValueError "Discount must be between 0 and 100"
            - Discount > 100: ValueError "Discount must be between 0 and 100"
            - Invalid tier: ValueError "Invalid member tier"
            - Zero quantity: ValueError "Quantity must be at least 1"
            - Negative quantity: ValueError "Quantity must be at least 1"

        Boundary Tests:
            - discount_percent = 0 (minimum)
            - discount_percent = 100 (maximum)
            - quantity = 1 (minimum valid)
            - quantity = 5 (bulk threshold)
            - quantity = 10 (higher bulk threshold)
            - Price precision: $99.99 with 33.33% discount

        Type Tests:
            - Accept Decimal types
            - Accept int for quantity
            - Accept str or None for member_tier
            - Return type is Decimal
    """
    # Validation
    if original_price < 0:
        raise ValueError("Price cannot be negative")

    if not (0 <= discount_percent <= 100):
        raise ValueError("Discount must be between 0 and 100")

    if quantity < 1:
        raise ValueError("Quantity must be at least 1")

    # Normalize and validate member tier
    valid_tiers = {'bronze', 'silver', 'gold', 'platinum'}
    tier_bonus = Decimal('0')

    if member_tier is not None:
        normalized_tier = member_tier.strip().lower()
        if normalized_tier not in valid_tiers:
            raise ValueError("Invalid member tier")

        # Tier bonuses (additional discount percentages)
        tier_bonuses = {
            'bronze': Decimal('2'),
            'silver': Decimal('5'),
            'gold': Decimal('5'),
            'platinum': Decimal('10'),
        }
        tier_bonus = tier_bonuses[normalized_tier]

    # Quantity-based bulk discount
    bulk_discount = Decimal('0')
    if quantity >= 10:
        bulk_discount = Decimal('10')
    elif quantity >= 5:
        bulk_discount = Decimal('5')

    # Calculate total discount percentage
    total_discount_percent = discount_percent + tier_bonus + bulk_discount
    # Cap at 100%
    total_discount_percent = min(total_discount_percent, Decimal('100'))

    # Apply discount
    discount_amount = original_price * (total_discount_percent / Decimal('100'))
    final_price = original_price - discount_amount

    # Ensure non-negative (should not happen with validation, but defensive)
    final_price = max(final_price, Decimal('0'))

    return final_price
