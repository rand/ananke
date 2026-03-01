"""Tests for Publish-Subscribe Implementation"""

import pytest
import time
import threading
from pubsub import (
    PubSub,
    Message,
    DeliveryMode,
    TopicPattern,
    create_filtered_subscription
)


class TestPubSub:
    def test_subscribe_and_publish(self):
        pubsub = PubSub()
        received = []

        pubsub.subscribe("test.topic", lambda m: received.append(m.payload))
        pubsub.publish("test.topic", "hello")

        assert len(received) == 1
        assert received[0] == "hello"

    def test_multiple_subscribers(self):
        pubsub = PubSub()
        received_1 = []
        received_2 = []

        pubsub.subscribe("topic", lambda m: received_1.append(m.payload))
        pubsub.subscribe("topic", lambda m: received_2.append(m.payload))
        pubsub.publish("topic", "message")

        assert received_1 == ["message"]
        assert received_2 == ["message"]

    def test_multiple_topics(self):
        pubsub = PubSub()
        received = []

        pubsub.subscribe("topic.a", lambda m: received.append(("a", m.payload)))
        pubsub.subscribe("topic.b", lambda m: received.append(("b", m.payload)))

        pubsub.publish("topic.a", "message_a")
        pubsub.publish("topic.b", "message_b")

        assert ("a", "message_a") in received
        assert ("b", "message_b") in received

    def test_unsubscribe(self):
        pubsub = PubSub()
        received = []

        sub_id = pubsub.subscribe("topic", lambda m: received.append(m.payload))
        pubsub.publish("topic", "first")

        assert pubsub.unsubscribe(sub_id)
        pubsub.publish("topic", "second")

        assert received == ["first"]

    def test_unsubscribe_nonexistent(self):
        pubsub = PubSub()
        assert not pubsub.unsubscribe("nonexistent-id")


class TestMessageFiltering:
    def test_filter_function(self):
        pubsub = PubSub()
        received = []

        def only_even(m: Message) -> bool:
            return m.payload % 2 == 0

        pubsub.subscribe("numbers", lambda m: received.append(m.payload), filter_func=only_even)

        for i in range(5):
            pubsub.publish("numbers", i)

        assert received == [0, 2, 4]

    def test_filter_by_metadata(self):
        pubsub = PubSub()
        received = []

        def high_priority(m: Message) -> bool:
            return m.metadata.get("priority") == "high"

        pubsub.subscribe("events", lambda m: received.append(m.payload), filter_func=high_priority)

        pubsub.publish("events", "low priority event", metadata={"priority": "low"})
        pubsub.publish("events", "high priority event", metadata={"priority": "high"})

        assert received == ["high priority event"]


class TestSubscriptionManagement:
    def test_pause_subscription(self):
        pubsub = PubSub()
        received = []

        sub_id = pubsub.subscribe("topic", lambda m: received.append(m.payload))
        pubsub.publish("topic", "before pause")

        pubsub.pause_subscription(sub_id)
        pubsub.publish("topic", "during pause")

        assert received == ["before pause"]

    def test_resume_subscription(self):
        pubsub = PubSub()
        received = []

        sub_id = pubsub.subscribe("topic", lambda m: received.append(m.payload))
        pubsub.pause_subscription(sub_id)
        pubsub.publish("topic", "during pause")

        pubsub.resume_subscription(sub_id)
        pubsub.publish("topic", "after resume")

        assert received == ["after resume"]

    def test_get_topics(self):
        pubsub = PubSub()
        pubsub.subscribe("topic.a", lambda m: None)
        pubsub.subscribe("topic.b", lambda m: None)

        topics = pubsub.get_topics()
        assert "topic.a" in topics
        assert "topic.b" in topics

    def test_get_subscription_count(self):
        pubsub = PubSub()
        pubsub.subscribe("topic", lambda m: None)
        pubsub.subscribe("topic", lambda m: None)
        pubsub.subscribe("other", lambda m: None)

        assert pubsub.get_subscription_count("topic") == 2
        assert pubsub.get_subscription_count("other") == 1
        assert pubsub.get_subscription_count("nonexistent") == 0


class TestMessageHistory:
    def test_stores_message_history(self):
        pubsub = PubSub()
        pubsub.publish("topic", "message 1")
        pubsub.publish("topic", "message 2")

        history = pubsub.get_message_history()
        assert len(history) == 2
        assert history[0].payload == "message 1"
        assert history[1].payload == "message 2"

    def test_filter_history_by_topic(self):
        pubsub = PubSub()
        pubsub.publish("topic.a", "a1")
        pubsub.publish("topic.b", "b1")
        pubsub.publish("topic.a", "a2")

        history = pubsub.get_message_history(topic="topic.a")
        assert len(history) == 2
        assert all(m.topic == "topic.a" for m in history)

    def test_limit_history(self):
        pubsub = PubSub()
        for i in range(10):
            pubsub.publish("topic", i)

        history = pubsub.get_message_history(limit=5)
        assert len(history) == 5
        assert history[0].payload == 5  # Last 5 messages

    def test_clear_history(self):
        pubsub = PubSub()
        pubsub.publish("topic", "message")
        pubsub.clear_history()

        assert pubsub.get_message_history() == []


class TestMessage:
    def test_message_has_id(self):
        pubsub = PubSub()
        message = pubsub.publish("topic", "payload")
        assert message.id is not None
        assert len(message.id) > 0

    def test_message_has_timestamp(self):
        before = time.time()
        pubsub = PubSub()
        message = pubsub.publish("topic", "payload")
        after = time.time()

        assert before <= message.timestamp <= after

    def test_message_metadata(self):
        pubsub = PubSub()
        message = pubsub.publish("topic", "payload", metadata={"key": "value"})
        assert message.metadata["key"] == "value"


class TestAsyncDelivery:
    def test_async_delivery(self):
        pubsub = PubSub(delivery_mode=DeliveryMode.ASYNC)
        received = []
        event = threading.Event()

        def handler(m):
            received.append(m.payload)
            event.set()

        pubsub.subscribe("topic", handler)
        pubsub.start_async()

        pubsub.publish("topic", "message")
        event.wait(timeout=1.0)

        assert received == ["message"]
        pubsub.stop_async()

    def test_stop_async(self):
        pubsub = PubSub(delivery_mode=DeliveryMode.ASYNC)
        pubsub.start_async()
        pubsub.stop_async()

        # Should not raise
        assert True


class TestTopicPattern:
    def test_exact_match(self):
        pattern = TopicPattern("foo.bar.baz")
        assert pattern.matches("foo.bar.baz")
        assert not pattern.matches("foo.bar")
        assert not pattern.matches("foo.bar.baz.qux")

    def test_single_wildcard(self):
        pattern = TopicPattern("foo.*.baz")
        assert pattern.matches("foo.bar.baz")
        assert pattern.matches("foo.qux.baz")
        assert not pattern.matches("foo.baz")
        assert not pattern.matches("foo.bar.baz.qux")

    def test_multi_wildcard(self):
        pattern = TopicPattern("foo.#")
        assert pattern.matches("foo")
        assert pattern.matches("foo.bar")
        assert pattern.matches("foo.bar.baz")

    def test_multi_wildcard_middle(self):
        pattern = TopicPattern("foo.#.baz")
        assert pattern.matches("foo.baz")
        assert pattern.matches("foo.bar.baz")
        assert pattern.matches("foo.bar.qux.baz")

    def test_combined_wildcards(self):
        pattern = TopicPattern("*.foo.#")
        assert pattern.matches("bar.foo")
        assert pattern.matches("bar.foo.baz")
        assert not pattern.matches("foo.bar")


class TestFilteredSubscription:
    def test_filters_by_payload_field(self):
        pubsub = PubSub()
        received = []

        create_filtered_subscription(
            pubsub, "events",
            lambda m: received.append(m.payload),
            status="active"
        )

        pubsub.publish("events", {"status": "active", "name": "event1"})
        pubsub.publish("events", {"status": "inactive", "name": "event2"})

        assert len(received) == 1
        assert received[0]["name"] == "event1"

    def test_filters_by_metadata(self):
        pubsub = PubSub()
        received = []

        create_filtered_subscription(
            pubsub, "events",
            lambda m: received.append(m.payload),
            source="api"
        )

        pubsub.publish("events", "from api", metadata={"source": "api"})
        pubsub.publish("events", "from ui", metadata={"source": "ui"})

        assert received == ["from api"]
