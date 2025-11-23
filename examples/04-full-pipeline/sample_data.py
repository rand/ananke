"""
Data processing pipeline for analytics
Demonstrates constraint patterns for data transformation and validation
"""

from typing import List, Dict, Optional, Iterator, TypedDict, Literal
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from decimal import Decimal
import logging
from enum import Enum

logger = logging.getLogger(__name__)


class DataQuality(Enum):
    """Data quality levels"""
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    INVALID = "invalid"


class ProcessingStatus(Enum):
    """Pipeline processing status"""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


# Type constraint: Strict data schemas
class RawEvent(TypedDict):
    """Raw event data from external source"""
    event_id: str
    user_id: str
    event_type: str
    timestamp: str  # ISO format
    properties: Dict[str, any]
    source: str


@dataclass
class CleanedEvent:
    """Validated and cleaned event data"""
    event_id: str
    user_id: str
    event_type: str
    timestamp: datetime  # Type constraint: Parsed datetime
    properties: Dict[str, any]
    source: str
    quality: DataQuality = DataQuality.MEDIUM
    processed_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class AggregatedMetrics:
    """Aggregated metrics from events"""
    user_id: str
    date: datetime
    event_count: int
    unique_event_types: int
    session_duration_seconds: Optional[float] = None
    conversion_events: int = 0
    revenue: Decimal = Decimal("0")
    data_quality: DataQuality = DataQuality.MEDIUM


@dataclass
class ValidationResult:
    """Result of data validation"""
    is_valid: bool
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    quality: DataQuality = DataQuality.MEDIUM


class DataPipeline:
    """
    Data processing pipeline with comprehensive constraints

    Constraints demonstrated:
    1. Data validation at every stage
    2. Error handling with recovery
    3. Batch processing for performance
    4. Quality scoring
    5. Idempotency handling
    6. Monitoring and logging
    """

    def __init__(self, batch_size: int = 1000, max_retries: int = 3):
        # Semantic constraint: Reasonable batch size
        if batch_size < 1 or batch_size > 10000:
            raise ValueError("Batch size must be between 1 and 10000")

        self.batch_size = batch_size
        self.max_retries = max_retries
        self.processed_ids: set = set()  # Operational constraint: Track for idempotency

    def process_events(
        self,
        raw_events: List[RawEvent],
        enable_validation: bool = True
    ) -> Dict[str, any]:
        """
        Process raw events through complete pipeline

        Semantic constraints:
        - Input validation required
        - Batch processing for efficiency
        - Error tracking and reporting
        - Quality metrics calculated
        """
        logger.info(f"Processing {len(raw_events)} events")

        results = {
            "processed": 0,
            "failed": 0,
            "skipped": 0,
            "quality_breakdown": {
                DataQuality.HIGH: 0,
                DataQuality.MEDIUM: 0,
                DataQuality.LOW: 0,
                DataQuality.INVALID: 0
            },
            "errors": []
        }

        # Semantic constraint: Process in batches for memory efficiency
        for batch_start in range(0, len(raw_events), self.batch_size):
            batch = raw_events[batch_start:batch_start + self.batch_size]
            batch_results = self._process_batch(batch, enable_validation)

            # Aggregate results
            results["processed"] += batch_results["processed"]
            results["failed"] += batch_results["failed"]
            results["skipped"] += batch_results["skipped"]

            for quality, count in batch_results["quality_breakdown"].items():
                results["quality_breakdown"][quality] += count

            results["errors"].extend(batch_results["errors"])

        return results

    def _process_batch(
        self,
        batch: List[RawEvent],
        enable_validation: bool
    ) -> Dict[str, any]:
        """
        Process a single batch of events

        Operational constraint: Batch processing reduces overhead
        """
        results = {
            "processed": 0,
            "failed": 0,
            "skipped": 0,
            "quality_breakdown": {q: 0 for q in DataQuality},
            "errors": []
        }

        for raw_event in batch:
            try:
                # Semantic constraint: Check idempotency
                if raw_event["event_id"] in self.processed_ids:
                    results["skipped"] += 1
                    continue

                # Step 1: Validate
                if enable_validation:
                    validation = self.validate_event(raw_event)
                    if not validation.is_valid:
                        logger.warning(
                            f"Invalid event {raw_event['event_id']}: {validation.errors}"
                        )
                        results["failed"] += 1
                        results["errors"].append({
                            "event_id": raw_event["event_id"],
                            "errors": validation.errors
                        })
                        continue

                # Step 2: Clean and transform
                cleaned = self.clean_event(raw_event)

                # Step 3: Enrich
                enriched = self.enrich_event(cleaned)

                # Step 4: Store
                self.store_event(enriched)

                # Track success
                self.processed_ids.add(raw_event["event_id"])
                results["processed"] += 1
                results["quality_breakdown"][enriched.quality] += 1

            except Exception as e:
                # Error handling constraint: Log and continue
                logger.error(f"Failed to process event {raw_event.get('event_id')}: {e}")
                results["failed"] += 1
                results["errors"].append({
                    "event_id": raw_event.get("event_id"),
                    "error": str(e)
                })

        return results

    def validate_event(self, event: RawEvent) -> ValidationResult:
        """
        Validate raw event data

        Semantic constraints:
        - Required fields must be present
        - Data types must be correct
        - Values must be in expected ranges
        - Timestamps must be recent (not in future, not too old)
        """
        errors = []
        warnings = []
        quality = DataQuality.HIGH

        # Semantic constraint: Required fields
        required_fields = ["event_id", "user_id", "event_type", "timestamp", "source"]
        for field in required_fields:
            if field not in event or not event[field]:
                errors.append(f"Missing required field: {field}")
                quality = DataQuality.INVALID

        if errors:
            return ValidationResult(False, errors, warnings, DataQuality.INVALID)

        # Semantic constraint: Event ID format
        if not self._is_valid_uuid(event["event_id"]):
            errors.append("event_id must be valid UUID")
            quality = DataQuality.INVALID

        # Semantic constraint: User ID format
        if not self._is_valid_uuid(event["user_id"]):
            errors.append("user_id must be valid UUID")
            quality = DataQuality.INVALID

        # Semantic constraint: Event type must be known
        if event["event_type"] not in self._get_valid_event_types():
            warnings.append(f"Unknown event type: {event['event_type']}")
            quality = min(quality, DataQuality.MEDIUM)

        # Semantic constraint: Timestamp validation
        try:
            timestamp = datetime.fromisoformat(event["timestamp"])

            # Semantic constraint: Not in future
            if timestamp > datetime.utcnow():
                errors.append("Timestamp cannot be in future")
                quality = DataQuality.INVALID

            # Semantic constraint: Not too old (90 days)
            if timestamp < datetime.utcnow() - timedelta(days=90):
                warnings.append("Event is older than 90 days")
                quality = min(quality, DataQuality.LOW)

        except (ValueError, KeyError) as e:
            errors.append(f"Invalid timestamp format: {e}")
            quality = DataQuality.INVALID

        # Semantic constraint: Properties should be dict
        if "properties" not in event or not isinstance(event["properties"], dict):
            warnings.append("Missing or invalid properties")
            quality = min(quality, DataQuality.MEDIUM)

        is_valid = len(errors) == 0

        return ValidationResult(
            is_valid=is_valid,
            errors=errors,
            warnings=warnings,
            quality=quality if is_valid else DataQuality.INVALID
        )

    def clean_event(self, raw_event: RawEvent) -> CleanedEvent:
        """
        Clean and transform raw event

        Semantic constraints:
        - Parse timestamps
        - Normalize data formats
        - Remove PII if configured
        - Standardize property names
        """
        # Type constraint: Parse timestamp
        timestamp = datetime.fromisoformat(raw_event["timestamp"])

        # Semantic constraint: Normalize event type
        event_type = raw_event["event_type"].lower().strip()

        # Semantic constraint: Clean properties
        cleaned_properties = self._clean_properties(raw_event["properties"])

        # Operational constraint: Determine quality
        quality = self._assess_quality(raw_event)

        return CleanedEvent(
            event_id=raw_event["event_id"],
            user_id=raw_event["user_id"],
            event_type=event_type,
            timestamp=timestamp,
            properties=cleaned_properties,
            source=raw_event["source"],
            quality=quality,
            processed_at=datetime.utcnow()
        )

    def enrich_event(self, event: CleanedEvent) -> CleanedEvent:
        """
        Enrich event with additional data

        Semantic constraints:
        - Add user context
        - Add session information
        - Add derived properties
        - Maintain data lineage
        """
        # Performance constraint: Batch user lookups in production
        # user_data = self._fetch_user_data(event.user_id)

        # Semantic constraint: Add enrichment metadata
        event.properties["_enriched_at"] = datetime.utcnow().isoformat()
        event.properties["_pipeline_version"] = "1.0"

        # Semantic constraint: Calculate derived properties
        if event.event_type == "purchase":
            event.properties["_is_conversion"] = True
            event.properties["_revenue"] = event.properties.get("amount", 0)

        return event

    def aggregate_metrics(
        self,
        events: List[CleanedEvent],
        group_by: Literal["user", "date", "user_date"] = "user_date"
    ) -> List[AggregatedMetrics]:
        """
        Aggregate events into metrics

        Semantic constraints:
        - Group by appropriate dimensions
        - Calculate accurate aggregations
        - Handle missing data gracefully
        - Maintain metric definitions
        """
        # Semantic constraint: Group events appropriately
        groups: Dict[tuple, List[CleanedEvent]] = {}

        for event in events:
            if group_by == "user":
                key = (event.user_id,)
            elif group_by == "date":
                key = (event.timestamp.date(),)
            else:  # user_date
                key = (event.user_id, event.timestamp.date())

            if key not in groups:
                groups[key] = []
            groups[key].append(event)

        # Calculate metrics for each group
        metrics = []
        for key, group_events in groups.items():
            metric = self._calculate_group_metrics(key, group_events)
            metrics.append(metric)

        return metrics

    def _calculate_group_metrics(
        self,
        key: tuple,
        events: List[CleanedEvent]
    ) -> AggregatedMetrics:
        """
        Calculate metrics for event group

        Semantic constraints:
        - Accurate counting
        - Proper type conversions
        - Handle edge cases
        """
        user_id = key[0] if isinstance(key[0], str) else None
        date = key[1] if len(key) > 1 and isinstance(key[1], datetime) else None

        # Semantic constraint: Count events
        event_count = len(events)

        # Semantic constraint: Count unique event types
        unique_types = len(set(e.event_type for e in events))

        # Semantic constraint: Calculate session duration
        if events:
            sorted_events = sorted(events, key=lambda e: e.timestamp)
            duration = (
                sorted_events[-1].timestamp - sorted_events[0].timestamp
            ).total_seconds()
        else:
            duration = None

        # Semantic constraint: Count conversions
        conversion_events = sum(
            1 for e in events
            if e.properties.get("_is_conversion", False)
        )

        # Semantic constraint: Sum revenue
        revenue = sum(
            Decimal(str(e.properties.get("_revenue", 0)))
            for e in events
        )

        # Operational constraint: Assess overall data quality
        quality_scores = [e.quality for e in events]
        if DataQuality.INVALID in quality_scores:
            overall_quality = DataQuality.INVALID
        elif DataQuality.LOW in quality_scores:
            overall_quality = DataQuality.LOW
        elif DataQuality.MEDIUM in quality_scores:
            overall_quality = DataQuality.MEDIUM
        else:
            overall_quality = DataQuality.HIGH

        return AggregatedMetrics(
            user_id=user_id or "unknown",
            date=date or datetime.utcnow(),
            event_count=event_count,
            unique_event_types=unique_types,
            session_duration_seconds=duration,
            conversion_events=conversion_events,
            revenue=revenue,
            data_quality=overall_quality
        )

    # Helper methods

    def _clean_properties(self, properties: Dict[str, any]) -> Dict[str, any]:
        """
        Clean and normalize properties

        Security constraint: Remove PII
        Semantic constraint: Standardize formats
        """
        cleaned = {}

        for key, value in properties.items():
            # Security constraint: Skip sensitive fields
            if key.lower() in ["password", "ssn", "credit_card"]:
                continue

            # Semantic constraint: Normalize key names
            normalized_key = key.lower().replace(" ", "_")

            # Type constraint: Handle None values
            if value is None:
                cleaned[normalized_key] = None
            elif isinstance(value, (int, float, bool, str)):
                cleaned[normalized_key] = value
            else:
                # Semantic constraint: Convert complex types to strings
                cleaned[normalized_key] = str(value)

        return cleaned

    def _assess_quality(self, event: RawEvent) -> DataQuality:
        """
        Assess data quality of event

        Operational constraint: Quality scoring affects processing
        """
        score = 100

        # Reduce score for missing optional fields
        if not event.get("properties"):
            score -= 20

        # Reduce score for unknown source
        if event.get("source") not in ["mobile", "web", "api"]:
            score -= 10

        if score >= 90:
            return DataQuality.HIGH
        elif score >= 70:
            return DataQuality.MEDIUM
        else:
            return DataQuality.LOW

    def store_event(self, event: CleanedEvent) -> None:
        """
        Store processed event

        Operational constraint: Persistent storage
        """
        # TODO: Implement database storage
        pass

    def _is_valid_uuid(self, value: str) -> bool:
        """Validate UUID format"""
        import re
        pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        return bool(re.match(pattern, value, re.IGNORECASE))

    def _get_valid_event_types(self) -> set:
        """Get list of valid event types"""
        return {
            "page_view", "click", "purchase", "signup",
            "login", "logout", "search", "add_to_cart"
        }


class DataQualityMonitor:
    """
    Monitor data quality metrics

    Operational constraint: Continuous quality monitoring
    """

    def __init__(self, alert_threshold: float = 0.7):
        self.alert_threshold = alert_threshold
        self.metrics_history: List[Dict] = []

    def track_batch_quality(
        self,
        batch_results: Dict[str, any]
    ) -> None:
        """
        Track quality metrics from batch processing

        Semantic constraint: Alert on quality degradation
        """
        total = batch_results["processed"] + batch_results["failed"]
        if total == 0:
            return

        quality_rate = batch_results["processed"] / total

        metric = {
            "timestamp": datetime.utcnow(),
            "quality_rate": quality_rate,
            "processed": batch_results["processed"],
            "failed": batch_results["failed"],
            "quality_breakdown": batch_results["quality_breakdown"]
        }

        self.metrics_history.append(metric)

        # Semantic constraint: Alert if quality drops
        if quality_rate < self.alert_threshold:
            self._send_quality_alert(metric)

    def _send_quality_alert(self, metric: Dict) -> None:
        """
        Send alert for low data quality

        Operational constraint: Alert on quality issues
        """
        logger.warning(
            f"Data quality alert: {metric['quality_rate']:.2%} < {self.alert_threshold:.2%}"
        )
        # TODO: Implement actual alerting (email, Slack, PagerDuty)
