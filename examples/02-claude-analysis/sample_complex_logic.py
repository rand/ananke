"""
Complex business logic for insurance policy pricing
Demonstrates semantic constraints requiring Claude analysis

This module contains intricate business rules that are difficult to extract
with static analysis alone. Claude can understand:
- Domain-specific business rules
- Complex conditional logic semantics
- Risk calculation constraints
- Compliance requirements
- Temporal constraints
"""

from typing import Optional, List, Dict, Tuple
from dataclasses import dataclass, field
from datetime import datetime, date, timedelta
from decimal import Decimal
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class PolicyType(Enum):
    """Type of insurance policy"""
    AUTO = "auto"
    HOME = "home"
    LIFE = "life"
    HEALTH = "health"


class RiskLevel(Enum):
    """Risk assessment levels"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    VERY_HIGH = "very_high"


@dataclass
class Customer:
    """Customer information for insurance policy"""
    id: str
    age: int
    zip_code: str
    credit_score: int
    claims_history: List[Dict] = field(default_factory=list)
    years_with_company: int = 0
    has_multiple_policies: bool = False


@dataclass
class PolicyDetails:
    """Details specific to policy type"""
    policy_type: PolicyType
    coverage_amount: Decimal
    deductible: Decimal
    term_years: int
    additional_riders: List[str] = field(default_factory=list)


@dataclass
class PricingResult:
    """Result of policy pricing calculation"""
    base_premium: Decimal
    risk_adjustment: Decimal
    discount_amount: Decimal
    final_premium: Decimal
    risk_level: RiskLevel
    factors: Dict[str, any] = field(default_factory=dict)
    warnings: List[str] = field(default_factory=list)


class InsurancePricingEngine:
    """
    Insurance policy pricing engine with complex business rules

    Semantic constraints (requiring Claude to understand):

    1. AGE-BASED RULES:
       - Life insurance: Base rate increases exponentially after age 50
       - Auto insurance: Highest rates for ages 16-25 and 70+
       - Health insurance: Age bands with 3:1 max ratio (ACA compliance)

    2. RISK ASSESSMENT RULES:
       - More than 2 claims in 3 years = high risk
       - Claims within 6 months = very high risk
       - Credit score < 600 adds 15-30% to premium
       - Certain zip codes have higher base rates (flood zones, crime rates)

    3. DISCOUNT RULES:
       - Multi-policy discount: 10-25% based on number of policies
       - Loyalty discount: 5% per year, max 25%
       - Good driver/homeowner: 10% if no claims for 5 years
       - Bundling discount: Additional 5% when combining auto + home

    4. REGULATORY CONSTRAINTS:
       - Cannot deny coverage based solely on age (except life insurance)
       - Health insurance has rate review requirements over certain thresholds
       - Auto insurance must offer minimum liability coverage
       - Premium increases over 10% require regulatory filing

    5. TEMPORAL CONSTRAINTS:
       - Rates must be recalculated annually
       - Claims older than 5 years don't affect pricing
       - Policy changes mid-term prorate the premium
       - Renewals must be offered 60 days before expiration
    """

    def __init__(self):
        self.base_rates = self._load_base_rates()
        self.risk_factors = self._load_risk_factors()
        self.discount_rules = self._load_discount_rules()

    def calculate_premium(
        self,
        customer: Customer,
        policy: PolicyDetails,
        effective_date: date
    ) -> PricingResult:
        """
        Calculate insurance premium with complex business logic

        Semantic constraint: Premium calculation must consider:
        - Base rate for policy type and coverage
        - Risk adjustments based on customer profile
        - Applicable discounts based on loyalty and behavior
        - Regulatory caps and floors
        - Temporal factors (seasonality, rate changes)
        """
        logger.info(f"Calculating premium for customer {customer.id}, policy {policy.policy_type}")

        # Step 1: Calculate base premium
        # Semantic constraint: Base varies by policy type and coverage amount
        base_premium = self._calculate_base_premium(policy, customer.age)

        # Step 2: Apply risk adjustments
        # Semantic constraint: Risk factors compound, not add linearly
        risk_level, risk_adjustment = self._calculate_risk_adjustment(
            customer, policy, effective_date
        )

        # Step 3: Calculate discounts
        # Semantic constraint: Some discounts stack, others don't
        discount_amount = self._calculate_discounts(
            customer, policy, base_premium, risk_adjustment
        )

        # Step 4: Apply regulatory constraints
        # Semantic constraint: Final premium must comply with regulations
        final_premium = self._apply_regulatory_constraints(
            base_premium + risk_adjustment - discount_amount,
            policy,
            customer
        )

        # Step 5: Validate business rules
        # Semantic constraint: Certain combinations require manual review
        warnings = self._validate_business_rules(customer, policy, final_premium)

        result = PricingResult(
            base_premium=base_premium,
            risk_adjustment=risk_adjustment,
            discount_amount=discount_amount,
            final_premium=final_premium,
            risk_level=risk_level,
            factors={
                "age_factor": self._get_age_factor(customer.age, policy.policy_type),
                "claims_factor": self._get_claims_factor(customer.claims_history),
                "credit_factor": self._get_credit_factor(customer.credit_score),
                "loyalty_years": customer.years_with_company
            },
            warnings=warnings
        )

        return result

    def _calculate_base_premium(self, policy: PolicyDetails, age: int) -> Decimal:
        """
        Calculate base premium before adjustments

        Semantic constraints:
        - Life insurance: Exponential increase after age 50
        - Coverage amount affects rate non-linearly
        - Term length affects pricing (longer terms = higher total but lower annual)
        """
        base_rate = self.base_rates.get(policy.policy_type, Decimal("1000"))

        # Semantic constraint: Coverage scaling is non-linear
        coverage_factor = (policy.coverage_amount / Decimal("100000")) ** Decimal("0.85")

        # Semantic constraint: Age bands have different multipliers
        if policy.policy_type == PolicyType.LIFE:
            if age < 30:
                age_multiplier = Decimal("0.8")
            elif age < 40:
                age_multiplier = Decimal("1.0")
            elif age < 50:
                age_multiplier = Decimal("1.3")
            elif age < 60:
                age_multiplier = Decimal("1.8")
            else:
                # Semantic constraint: Exponential increase after 60
                age_multiplier = Decimal("1.8") * (Decimal("1.15") ** (age - 60))
        else:
            age_multiplier = Decimal("1.0")

        # Semantic constraint: Deductible inversely affects premium
        deductible_factor = Decimal("1.0") - (policy.deductible / policy.coverage_amount) * Decimal("0.3")

        base_premium = base_rate * coverage_factor * age_multiplier * deductible_factor

        return base_premium.quantize(Decimal("0.01"))

    def _calculate_risk_adjustment(
        self,
        customer: Customer,
        policy: PolicyDetails,
        effective_date: date
    ) -> Tuple[RiskLevel, Decimal]:
        """
        Calculate risk-based adjustments

        Semantic constraints:
        - Recent claims weight more heavily than old claims
        - Multiple claims in short period = exponential increase
        - Geographic risk varies by policy type
        - Credit score impact is non-linear
        """
        risk_score = Decimal("0")

        # Semantic constraint: Recent claims (< 6 months) are critical
        recent_claims = self._get_recent_claims(customer.claims_history, effective_date, months=6)
        if len(recent_claims) > 0:
            risk_score += Decimal("50") * len(recent_claims)

        # Semantic constraint: Multiple claims in 3 years compound
        three_year_claims = self._get_recent_claims(customer.claims_history, effective_date, months=36)
        if len(three_year_claims) > 2:
            # Exponential penalty for multiple claims
            risk_score += Decimal("30") * (Decimal("1.5") ** len(three_year_claims))

        # Semantic constraint: Credit score affects risk non-linearly
        credit_factor = self._get_credit_factor(customer.credit_score)
        risk_score += credit_factor * Decimal("20")

        # Semantic constraint: Geographic risk varies by policy type
        geo_risk = self._assess_geographic_risk(customer.zip_code, policy.policy_type)
        risk_score += geo_risk

        # Semantic constraint: Determine risk level from score
        if risk_score < 20:
            risk_level = RiskLevel.LOW
        elif risk_score < 50:
            risk_level = RiskLevel.MEDIUM
        elif risk_score < 100:
            risk_level = RiskLevel.HIGH
        else:
            risk_level = RiskLevel.VERY_HIGH

        return risk_level, risk_score

    def _calculate_discounts(
        self,
        customer: Customer,
        policy: PolicyDetails,
        base_premium: Decimal,
        risk_adjustment: Decimal
    ) -> Decimal:
        """
        Calculate applicable discounts

        Semantic constraints:
        - Loyalty discount: 5% per year, max 25%
        - Multi-policy discount: 10-25% based on count
        - Clean record discount: 10% if no claims for 5 years
        - Bundling bonus: Additional 5% for auto + home
        - Some discounts stack, others take the maximum
        """
        total_discount = Decimal("0")
        subtotal = base_premium + risk_adjustment

        # Semantic constraint: Loyalty discount caps at 25%
        loyalty_discount = min(
            customer.years_with_company * Decimal("0.05"),
            Decimal("0.25")
        ) * subtotal

        # Semantic constraint: Multi-policy discount tiers
        if customer.has_multiple_policies:
            # 10% for 2 policies, 15% for 3, 25% for 4+
            multi_discount = Decimal("0.10") * subtotal
        else:
            multi_discount = Decimal("0")

        # Semantic constraint: Clean record = no claims in 5 years
        five_year_claims = [c for c in customer.claims_history
                          if (datetime.now() - datetime.fromisoformat(c['date'])).days < 1825]
        if len(five_year_claims) == 0:
            clean_record_discount = Decimal("0.10") * subtotal
        else:
            clean_record_discount = Decimal("0")

        # Semantic constraint: These discounts stack
        total_discount = loyalty_discount + multi_discount + clean_record_discount

        # Semantic constraint: Total discount capped at 40% of subtotal
        max_discount = subtotal * Decimal("0.40")
        return min(total_discount, max_discount).quantize(Decimal("0.01"))

    def _apply_regulatory_constraints(
        self,
        calculated_premium: Decimal,
        policy: PolicyDetails,
        customer: Customer
    ) -> Decimal:
        """
        Apply regulatory constraints to premium

        Semantic constraints:
        - Minimum premium floor by policy type
        - Maximum rate increase limits (10% year-over-year)
        - Health insurance age band ratios (3:1 max)
        - Cannot discriminate based on protected characteristics
        """
        # Semantic constraint: Minimum premium floors
        min_premiums = {
            PolicyType.AUTO: Decimal("300"),
            PolicyType.HOME: Decimal("500"),
            PolicyType.LIFE: Decimal("200"),
            PolicyType.HEALTH: Decimal("400")
        }

        min_premium = min_premiums.get(policy.policy_type, Decimal("100"))
        final_premium = max(calculated_premium, min_premium)

        # Semantic constraint: Health insurance age ratio constraint (ACA)
        if policy.policy_type == PolicyType.HEALTH:
            # Oldest customers can't pay more than 3x youngest
            # This is simplified; real implementation would check age bands
            pass

        return final_premium.quantize(Decimal("0.01"))

    def _validate_business_rules(
        self,
        customer: Customer,
        policy: PolicyDetails,
        final_premium: Decimal
    ) -> List[str]:
        """
        Validate business rules and generate warnings

        Semantic constraints:
        - Very high premiums require underwriter review
        - Very high risk customers need manual approval
        - Certain policy combinations need review
        - Age limits for certain policy types
        """
        warnings = []

        # Semantic constraint: High premiums need review
        if final_premium > Decimal("5000"):
            warnings.append("Premium over $5000 requires underwriter review")

        # Semantic constraint: Age limits
        if policy.policy_type == PolicyType.LIFE and customer.age > 75:
            warnings.append("Life insurance for age 75+ requires medical exam")

        # Semantic constraint: Very high risk requires approval
        if len(customer.claims_history) > 5:
            warnings.append("More than 5 claims - manual approval required")

        # Semantic constraint: Credit score below threshold
        if customer.credit_score < 500:
            warnings.append("Credit score below 500 - risk assessment needed")

        return warnings

    # Helper methods

    def _get_recent_claims(
        self,
        claims_history: List[Dict],
        effective_date: date,
        months: int
    ) -> List[Dict]:
        """Get claims within specified months"""
        cutoff = effective_date - timedelta(days=months * 30)
        return [
            c for c in claims_history
            if datetime.fromisoformat(c['date']).date() > cutoff
        ]

    def _get_age_factor(self, age: int, policy_type: PolicyType) -> Decimal:
        """Calculate age-based factor"""
        # Simplified age factor calculation
        if policy_type == PolicyType.AUTO:
            if age < 25:
                return Decimal("1.5")
            elif age > 70:
                return Decimal("1.3")
            else:
                return Decimal("1.0")
        return Decimal("1.0")

    def _get_claims_factor(self, claims_history: List[Dict]) -> Decimal:
        """Calculate claims-based factor"""
        if len(claims_history) == 0:
            return Decimal("0.9")  # Good driver discount
        elif len(claims_history) <= 2:
            return Decimal("1.0")
        else:
            return Decimal("1.0") + (Decimal("0.2") * len(claims_history))

    def _get_credit_factor(self, credit_score: int) -> Decimal:
        """
        Calculate credit-based factor

        Semantic constraint: Non-linear relationship
        """
        if credit_score >= 750:
            return Decimal("0.8")  # Discount
        elif credit_score >= 650:
            return Decimal("1.0")  # Neutral
        elif credit_score >= 600:
            return Decimal("1.15")  # Small penalty
        else:
            return Decimal("1.30")  # Large penalty

    def _assess_geographic_risk(self, zip_code: str, policy_type: PolicyType) -> Decimal:
        """
        Assess geographic risk

        Semantic constraint: Different factors by policy type
        - Auto: Crime rate, accident frequency
        - Home: Natural disasters, fire risk
        - Health: Healthcare costs in area
        """
        # Simplified geographic risk
        # TODO: Load from external risk database
        return Decimal("10")

    def _load_base_rates(self) -> Dict[PolicyType, Decimal]:
        """Load base rates for each policy type"""
        return {
            PolicyType.AUTO: Decimal("800"),
            PolicyType.HOME: Decimal("1200"),
            PolicyType.LIFE: Decimal("600"),
            PolicyType.HEALTH: Decimal("1500")
        }

    def _load_risk_factors(self) -> Dict:
        """Load risk factors configuration"""
        return {}

    def _load_discount_rules(self) -> Dict:
        """Load discount rules configuration"""
        return {}
