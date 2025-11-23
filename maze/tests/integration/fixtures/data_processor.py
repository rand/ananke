"""
Data processing service with type annotations and async operations
"""

from typing import Dict, List, Optional, TypedDict, Protocol
from dataclasses import dataclass
import asyncio


class DataSchema(TypedDict):
    """Schema for validated data"""
    id: str
    value: float
    metadata: Dict[str, str]


@dataclass
class ProcessingResult:
    """Result of data processing"""
    success: bool
    data: Optional[DataSchema]
    error: Optional[str]


class DataValidator(Protocol):
    """Protocol for data validators"""
    async def validate(self, data: Dict) -> bool:
        ...


class DataProcessor:
    """Process and validate data with constraints"""
    
    def __init__(self, validators: List[DataValidator]) -> None:
        self.validators = validators
    
    async def process(self, raw_data: Dict) -> ProcessingResult:
        """
        Process raw data through validation pipeline.
        
        Args:
            raw_data: Raw input data to process
            
        Returns:
            ProcessingResult with validated data or error
        """
        # Validate input
        if not await self._validate_all(raw_data):
            return ProcessingResult(
                success=False,
                data=None,
                error="Validation failed"
            )
        
        # Transform data
        try:
            validated_data: DataSchema = {
                'id': str(raw_data.get('id', '')),
                'value': float(raw_data.get('value', 0.0)),
                'metadata': raw_data.get('metadata', {})
            }
            
            return ProcessingResult(
                success=True,
                data=validated_data,
                error=None
            )
        except (ValueError, KeyError) as e:
            return ProcessingResult(
                success=False,
                data=None,
                error=f"Transform error: {str(e)}"
            )
    
    async def _validate_all(self, data: Dict) -> bool:
        """Run all validators"""
        results = await asyncio.gather(
            *[validator.validate(data) for validator in self.validators],
            return_exceptions=True
        )
        return all(r is True for r in results if not isinstance(r, Exception))
