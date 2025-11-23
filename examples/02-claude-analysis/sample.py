"""
Payment processing module with complex business logic
This demonstrates patterns that benefit from semantic analysis with Claude
"""

from typing import Optional, List, Decimal
from dataclasses import dataclass
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


@dataclass
class PaymentRequest:
    """Represents a payment request from a customer"""
    amount: Decimal
    currency: str
    customer_id: str
    payment_method: str
    description: Optional[str] = None
    metadata: Optional[dict] = None


@dataclass
class PaymentResult:
    """Result of a payment processing attempt"""
    success: bool
    transaction_id: Optional[str]
    error_message: Optional[str] = None
    processed_at: datetime = None


class PaymentProcessor:
    """
    Processes payments with fraud detection and compliance checks.

    This class embodies several implicit constraints that are hard to
    extract with static analysis alone:

    1. Payments over $10,000 require additional verification
    2. Repeated failed payments from same customer trigger rate limiting
    3. Certain countries have special compliance requirements
    4. Refunds must be processed within 90 days
    """

    def __init__(self, fraud_threshold: Decimal = Decimal("10000")):
        self.fraud_threshold = fraud_threshold
        self.failed_attempts = {}  # customer_id -> count
        self.processed_transactions = []

    def process_payment(self, request: PaymentRequest) -> PaymentResult:
        """
        Process a payment request with full validation.

        Business rules (implicit constraints):
        - Amount must be positive
        - Currency must be supported (USD, EUR, GBP)
        - Customer must not be rate-limited
        - High-value payments need manual review
        - PCI compliance: Never log full card numbers
        """

        # Validate amount (explicit constraint)
        if request.amount <= 0:
            return PaymentResult(
                success=False,
                transaction_id=None,
                error_message="Amount must be positive"
            )

        # Check if customer is rate-limited (implicit constraint from failed attempts)
        if self._is_rate_limited(request.customer_id):
            logger.warning(f"Customer {request.customer_id} is rate-limited")
            return PaymentResult(
                success=False,
                transaction_id=None,
                error_message="Too many failed attempts. Please try again later."
            )

        # High-value transaction check (business rule)
        if request.amount > self.fraud_threshold:
            return self._process_high_value_payment(request)

        # Standard payment processing
        return self._process_standard_payment(request)

    def _is_rate_limited(self, customer_id: str) -> bool:
        """
        Check if customer has too many failed attempts.

        Implicit constraint: 3 failures within 24 hours = rate limited
        This is a business rule that's hard to extract statically.
        """
        # Simplified: In reality, this would check timestamps
        failed_count = self.failed_attempts.get(customer_id, 0)
        return failed_count >= 3

    def _process_high_value_payment(self, request: PaymentRequest) -> PaymentResult:
        """
        Handle high-value payments that need extra verification.

        Implicit constraints:
        - Must verify customer identity
        - Must check for fraud patterns
        - May require manual approval
        - Must log to audit trail (compliance)
        """
        logger.info(
            f"High-value payment: {request.amount} {request.currency} "
            f"from customer {request.customer_id}"
        )

        # Fraud detection would happen here
        fraud_score = self._calculate_fraud_score(request)

        if fraud_score > 0.8:
            logger.warning(f"High fraud score: {fraud_score}")
            return PaymentResult(
                success=False,
                transaction_id=None,
                error_message="Payment requires manual review"
            )

        return self._process_standard_payment(request)

    def _process_standard_payment(self, request: PaymentRequest) -> PaymentResult:
        """
        Execute the actual payment transaction.

        Implicit constraints:
        - Must be idempotent (duplicate requests handled)
        - Must handle network failures gracefully
        - Must maintain transaction log for compliance
        """
        try:
            # Simulate payment gateway call
            transaction_id = self._charge_payment_method(request)

            # Record successful transaction
            self.processed_transactions.append(transaction_id)

            return PaymentResult(
                success=True,
                transaction_id=transaction_id,
                processed_at=datetime.now()
            )

        except Exception as e:
            # Track failed attempt for rate limiting
            customer_id = request.customer_id
            self.failed_attempts[customer_id] = (
                self.failed_attempts.get(customer_id, 0) + 1
            )

            logger.error(
                f"Payment failed for customer {customer_id}: {str(e)}"
                # Note: Not logging card details (PCI compliance)
            )

            return PaymentResult(
                success=False,
                transaction_id=None,
                error_message="Payment processing failed"
            )

    def _calculate_fraud_score(self, request: PaymentRequest) -> float:
        """
        Calculate fraud risk score.

        Implicit constraints:
        - Score 0.0 (safe) to 1.0 (definitely fraud)
        - Multiple factors contribute to score
        - Must be fast (< 100ms for user experience)
        """
        # Simplified fraud detection
        score = 0.0

        # High amount increases risk
        if request.amount > Decimal("50000"):
            score += 0.3

        # New customer is riskier
        if request.customer_id not in self._get_known_customers():
            score += 0.2

        # International payments higher risk
        if request.currency != "USD":
            score += 0.1

        return min(score, 1.0)

    def _charge_payment_method(self, request: PaymentRequest) -> str:
        """
        Call payment gateway to charge the payment method.

        Implicit constraints:
        - Must use secure connection (TLS)
        - Must include fraud detection token
        - Must handle timeouts and retries
        """
        # Simulate successful charge
        return f"txn_{request.customer_id}_{datetime.now().timestamp()}"

    def _get_known_customers(self) -> List[str]:
        """Return list of customers we've seen before"""
        # Simplified: Would query database
        return ["customer_123", "customer_456"]

    def process_refund(
        self,
        transaction_id: str,
        amount: Decimal,
        reason: str
    ) -> PaymentResult:
        """
        Process a refund for a previous transaction.

        Implicit constraints:
        - Can only refund transactions that exist
        - Can only refund within 90 days (business rule)
        - Partial refunds allowed but not exceeding original amount
        - Must update accounting records
        """

        if transaction_id not in self.processed_transactions:
            return PaymentResult(
                success=False,
                transaction_id=None,
                error_message="Transaction not found"
            )

        # Process refund
        logger.info(f"Processing refund: {amount} for {transaction_id}")

        return PaymentResult(
            success=True,
            transaction_id=f"refund_{transaction_id}",
            processed_at=datetime.now()
        )


def validate_currency(currency: str) -> bool:
    """
    Validate that a currency is supported.

    Implicit constraint: Only USD, EUR, GBP are supported
    This is a business rule that might not be obvious from code alone.
    """
    SUPPORTED_CURRENCIES = ["USD", "EUR", "GBP"]
    return currency in SUPPORTED_CURRENCIES


# Example usage showing implicit behavioral constraints
if __name__ == "__main__":
    processor = PaymentProcessor()

    # Valid payment
    request = PaymentRequest(
        amount=Decimal("99.99"),
        currency="USD",
        customer_id="customer_123",
        payment_method="card_xxx"
    )

    result = processor.process_payment(request)
    print(f"Payment result: {result}")
