# Python Fixture (target ~100 lines)
# Generated for benchmark testing

from typing import Optional, List, Dict, Any
from dataclasses import dataclass
from datetime import datetime
import asyncio

@dataclass
class Entity:
    id: int
    name: str
    email: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

@dataclass
class CreateDto:
    name: str
    email: str

@dataclass
class UpdateDto:
    name: Optional[str] = None
    email: Optional[str] = None
    is_active: Optional[bool] = None

class EntityService:
    def __init__(self, db, logger, cache):
        self.db = db
        self.logger = logger
        self.cache = cache


    async def operation_0(self, entity_id: int, data: str) -> Optional[Entity]:
        """Async operation operation_0"""
        try:
            result = await self.db.query(
                "SELECT * FROM entities WHERE id = ?",
                (entity_id,)
            )
            self.logger.debug(f"Fetched {entity_id}")
            return Entity(**result) if result else None
        except Exception as e:
            self.logger.error(f"Operation failed: {e}")
            raise

    async def operation_1(self, entity_id: int, data: str) -> Optional[Entity]:
        """Async operation operation_1"""
        try:
            result = await self.db.query(
                "SELECT * FROM entities WHERE id = ?",
                (entity_id,)
            )
            self.logger.debug(f"Fetched {entity_id}")
            return Entity(**result) if result else None
        except Exception as e:
            self.logger.error(f"Operation failed: {e}")
            raise

    async def operation_2(self, entity_id: int, data: str) -> Optional[Entity]:
        """Async operation operation_2"""
        try:
            result = await self.db.query(
                "SELECT * FROM entities WHERE id = ?",
                (entity_id,)
            )
            self.logger.debug(f"Fetched {entity_id}")
            return Entity(**result) if result else None
        except Exception as e:
            self.logger.error(f"Operation failed: {e}")
            raise
