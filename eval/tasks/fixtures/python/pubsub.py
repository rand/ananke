"""
Publish-Subscribe Implementation
Event-driven messaging with topics and subscriptions
"""

from typing import Callable, Any, Dict, List, Optional, Set
from dataclasses import dataclass, field
from collections import defaultdict
import threading
import queue
import uuid
import time
from enum import Enum


class DeliveryMode(Enum):
    SYNC = "sync"
    ASYNC = "async"


@dataclass
class Message:
    """A message in the pub/sub system."""
    topic: str
    payload: Any
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: float = field(default_factory=time.time)
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class Subscription:
    """A subscription to a topic."""
    id: str
    topic: str
    handler: Callable[[Message], None]
    filter_func: Optional[Callable[[Message], bool]] = None
    active: bool = True


class PubSub:
    """
    Publish-Subscribe messaging system.

    Supports:
    - Multiple topics
    - Message filtering
    - Synchronous and asynchronous delivery
    - Subscription management
    """

    def __init__(self, delivery_mode: DeliveryMode = DeliveryMode.SYNC):
        self._subscriptions: Dict[str, List[Subscription]] = defaultdict(list)
        self._subscription_index: Dict[str, Subscription] = {}
        self._delivery_mode = delivery_mode
        self._message_queue: queue.Queue = queue.Queue()
        self._running = False
        self._worker_thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()
        self._message_history: List[Message] = []
        self._history_limit = 1000

    def subscribe(
        self,
        topic: str,
        handler: Callable[[Message], None],
        filter_func: Optional[Callable[[Message], bool]] = None
    ) -> str:
        """
        Subscribe to a topic.

        Args:
            topic: The topic to subscribe to
            handler: Function to call when a message is received
            filter_func: Optional function to filter messages

        Returns:
            Subscription ID
        """
        sub_id = str(uuid.uuid4())
        subscription = Subscription(
            id=sub_id,
            topic=topic,
            handler=handler,
            filter_func=filter_func
        )

        with self._lock:
            self._subscriptions[topic].append(subscription)
            self._subscription_index[sub_id] = subscription

        return sub_id

    def unsubscribe(self, subscription_id: str) -> bool:
        """
        Unsubscribe from a topic.

        Args:
            subscription_id: The subscription ID to remove

        Returns:
            True if subscription was found and removed
        """
        with self._lock:
            if subscription_id not in self._subscription_index:
                return False

            subscription = self._subscription_index[subscription_id]
            self._subscriptions[subscription.topic].remove(subscription)
            del self._subscription_index[subscription_id]

        return True

    def publish(
        self,
        topic: str,
        payload: Any,
        metadata: Optional[Dict[str, Any]] = None
    ) -> Message:
        """
        Publish a message to a topic.

        Args:
            topic: The topic to publish to
            payload: The message payload
            metadata: Optional message metadata

        Returns:
            The published message
        """
        message = Message(
            topic=topic,
            payload=payload,
            metadata=metadata or {}
        )

        # Store in history
        with self._lock:
            self._message_history.append(message)
            if len(self._message_history) > self._history_limit:
                self._message_history = self._message_history[-self._history_limit:]

        if self._delivery_mode == DeliveryMode.ASYNC:
            self._message_queue.put(message)
        else:
            self._deliver_message(message)

        return message

    def _deliver_message(self, message: Message) -> None:
        """Deliver a message to all matching subscribers."""
        with self._lock:
            subscriptions = list(self._subscriptions.get(message.topic, []))

        for subscription in subscriptions:
            if not subscription.active:
                continue

            if subscription.filter_func and not subscription.filter_func(message):
                continue

            try:
                subscription.handler(message)
            except Exception:
                # Log error in production; here we just continue
                pass

    def start_async(self) -> None:
        """Start the async message delivery worker."""
        if self._running:
            return

        self._running = True
        self._worker_thread = threading.Thread(target=self._worker_loop, daemon=True)
        self._worker_thread.start()

    def stop_async(self) -> None:
        """Stop the async message delivery worker."""
        self._running = False
        if self._worker_thread:
            self._message_queue.put(None)  # Signal to stop
            self._worker_thread.join(timeout=1.0)
            self._worker_thread = None

    def _worker_loop(self) -> None:
        """Worker loop for async message delivery."""
        while self._running:
            try:
                message = self._message_queue.get(timeout=0.1)
                if message is None:
                    break
                self._deliver_message(message)
            except queue.Empty:
                continue

    def get_topics(self) -> List[str]:
        """Get all topics with active subscriptions."""
        with self._lock:
            return list(self._subscriptions.keys())

    def get_subscription_count(self, topic: str) -> int:
        """Get the number of subscriptions for a topic."""
        with self._lock:
            return len([s for s in self._subscriptions.get(topic, []) if s.active])

    def pause_subscription(self, subscription_id: str) -> bool:
        """Pause a subscription (stop receiving messages)."""
        with self._lock:
            if subscription_id in self._subscription_index:
                self._subscription_index[subscription_id].active = False
                return True
        return False

    def resume_subscription(self, subscription_id: str) -> bool:
        """Resume a paused subscription."""
        with self._lock:
            if subscription_id in self._subscription_index:
                self._subscription_index[subscription_id].active = True
                return True
        return False

    def get_message_history(self, topic: Optional[str] = None, limit: int = 100) -> List[Message]:
        """Get message history, optionally filtered by topic."""
        with self._lock:
            messages = self._message_history
            if topic:
                messages = [m for m in messages if m.topic == topic]
            return messages[-limit:]

    def clear_history(self) -> None:
        """Clear message history."""
        with self._lock:
            self._message_history.clear()


class TopicPattern:
    """
    Topic pattern matcher for wildcard subscriptions.

    Supports:
    - * matches exactly one word
    - # matches zero or more words
    """

    def __init__(self, pattern: str):
        self.pattern = pattern
        self._parts = pattern.split(".")

    def matches(self, topic: str) -> bool:
        """Check if a topic matches this pattern."""
        topic_parts = topic.split(".")
        return self._match_parts(self._parts, topic_parts)

    def _match_parts(self, pattern_parts: List[str], topic_parts: List[str]) -> bool:
        """Recursively match pattern parts against topic parts."""
        if not pattern_parts:
            return not topic_parts

        if pattern_parts[0] == "#":
            if len(pattern_parts) == 1:
                return True
            # Try matching # with 0, 1, 2, ... words
            for i in range(len(topic_parts) + 1):
                if self._match_parts(pattern_parts[1:], topic_parts[i:]):
                    return True
            return False

        if not topic_parts:
            return False

        if pattern_parts[0] == "*" or pattern_parts[0] == topic_parts[0]:
            return self._match_parts(pattern_parts[1:], topic_parts[1:])

        return False


def create_filtered_subscription(
    pubsub: PubSub,
    topic: str,
    handler: Callable[[Message], None],
    **filters: Any
) -> str:
    """
    Create a subscription with keyword filters.

    Filters are applied to message payload (if dict) or metadata.
    """
    def filter_func(message: Message) -> bool:
        for key, value in filters.items():
            # Check payload
            if isinstance(message.payload, dict) and key in message.payload:
                if message.payload[key] != value:
                    return False
            # Check metadata
            elif key in message.metadata:
                if message.metadata[key] != value:
                    return False
            else:
                return False
        return True

    return pubsub.subscribe(topic, handler, filter_func)
