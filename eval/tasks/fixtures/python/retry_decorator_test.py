"""Tests for Retry Decorator Implementation"""

import pytest
import time
from retry_decorator import (
    retry,
    RetryConfig,
    RetryError,
    RetryStats,
    execute_with_retry,
    retry_with_stats,
    RetryContext,
    with_fallback,
    conditional_retry,
    CircuitBreaker
)


class TestRetryDecorator:
    def test_succeeds_on_first_attempt(self):
        call_count = 0

        @retry(max_attempts=3, base_delay=0.01)
        def always_succeeds():
            nonlocal call_count
            call_count += 1
            return "success"

        result = always_succeeds()
        assert result == "success"
        assert call_count == 1

    def test_retries_on_failure(self):
        call_count = 0

        @retry(max_attempts=3, base_delay=0.01)
        def fails_twice():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise ValueError("temporary failure")
            return "success"

        result = fails_twice()
        assert result == "success"
        assert call_count == 3

    def test_raises_after_max_attempts(self):
        call_count = 0

        @retry(max_attempts=3, base_delay=0.01)
        def always_fails():
            nonlocal call_count
            call_count += 1
            raise ValueError("permanent failure")

        with pytest.raises(RetryError) as exc_info:
            always_fails()

        assert exc_info.value.attempts == 3
        assert call_count == 3

    def test_only_retries_specified_exceptions(self):
        call_count = 0

        @retry(max_attempts=3, base_delay=0.01, exceptions=(ValueError,))
        def raises_type_error():
            nonlocal call_count
            call_count += 1
            raise TypeError("not retried")

        with pytest.raises(TypeError):
            raises_type_error()

        assert call_count == 1

    def test_on_retry_callback(self):
        retry_attempts = []

        def on_retry(attempt, exception):
            retry_attempts.append((attempt, str(exception)))

        @retry(max_attempts=3, base_delay=0.01, on_retry=on_retry)
        def fails_twice():
            if len(retry_attempts) < 2:
                raise ValueError("failure")
            return "success"

        fails_twice()
        assert len(retry_attempts) == 2
        assert retry_attempts[0][0] == 1
        assert retry_attempts[1][0] == 2


class TestRetryConfig:
    def test_calculates_exponential_delay(self):
        config = RetryConfig(base_delay=1.0, exponential_base=2.0, jitter=False)

        assert config.calculate_delay(1) == 1.0
        assert config.calculate_delay(2) == 2.0
        assert config.calculate_delay(3) == 4.0

    def test_respects_max_delay(self):
        config = RetryConfig(base_delay=1.0, exponential_base=2.0, max_delay=3.0, jitter=False)

        assert config.calculate_delay(1) == 1.0
        assert config.calculate_delay(2) == 2.0
        assert config.calculate_delay(3) == 3.0  # Capped at max_delay
        assert config.calculate_delay(10) == 3.0

    def test_adds_jitter(self):
        config = RetryConfig(base_delay=1.0, jitter=True, jitter_factor=0.5)

        delays = [config.calculate_delay(1) for _ in range(10)]
        # All delays should be different (with high probability)
        assert len(set(delays)) > 1
        # All delays should be within expected range
        assert all(0.5 <= d <= 1.5 for d in delays)


class TestRetryWithStats:
    def test_returns_stats_on_success(self):
        def succeeds():
            return "result"

        config = RetryConfig(max_attempts=3, base_delay=0.01)
        result, stats = retry_with_stats(succeeds, config)

        assert result == "result"
        assert stats.success
        assert stats.attempts == 1
        assert stats.exceptions == []

    def test_returns_stats_on_retry(self):
        call_count = 0

        def fails_once():
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                raise ValueError("first failure")
            return "result"

        config = RetryConfig(max_attempts=3, base_delay=0.01)
        result, stats = retry_with_stats(fails_once, config)

        assert result == "result"
        assert stats.success
        assert stats.attempts == 2
        assert len(stats.exceptions) == 1


class TestRetryContext:
    def test_successful_operation(self):
        config = RetryConfig(max_attempts=3, base_delay=0.01)
        ctx = RetryContext(config)

        while ctx.should_retry():
            ctx.wait()
            with ctx:
                result = "success"
                break

        assert ctx.success
        assert result == "success"

    def test_retries_on_exception(self):
        config = RetryConfig(max_attempts=3, base_delay=0.01)
        ctx = RetryContext(config)
        attempts = 0

        while ctx.should_retry():
            ctx.wait()
            with ctx:
                attempts += 1
                if attempts < 3:
                    raise ValueError("retry")
                result = "success"

        assert ctx.success
        assert attempts == 3


class TestWithFallback:
    def test_returns_result_on_success(self):
        def succeeds():
            return "primary"

        wrapped = with_fallback(succeeds, "fallback")
        assert wrapped() == "primary"

    def test_returns_fallback_value_on_failure(self):
        def fails():
            raise ValueError("error")

        wrapped = with_fallback(fails, "fallback")
        assert wrapped() == "fallback"

    def test_calls_fallback_function(self):
        def fails(x):
            raise ValueError("error")

        def fallback(x):
            return f"fallback for {x}"

        wrapped = with_fallback(fails, fallback)
        assert wrapped("test") == "fallback for test"


class TestConditionalRetry:
    def test_retries_until_predicate_passes(self):
        call_count = 0

        @conditional_retry(predicate=lambda x: x > 5, max_attempts=10, base_delay=0.01)
        def incrementing():
            nonlocal call_count
            call_count += 1
            return call_count

        result = incrementing()
        assert result == 6
        assert call_count == 6

    def test_returns_last_result_if_predicate_never_passes(self):
        @conditional_retry(predicate=lambda x: x > 100, max_attempts=3, base_delay=0.01)
        def always_low():
            return 1

        result = always_low()
        assert result == 1


class TestCircuitBreaker:
    def test_allows_calls_when_closed(self):
        cb = CircuitBreaker(failure_threshold=3)

        @cb
        def succeeds():
            return "success"

        assert succeeds() == "success"
        assert cb.state == "closed"

    def test_opens_after_threshold_failures(self):
        cb = CircuitBreaker(failure_threshold=3)

        @cb
        def fails():
            raise ValueError("error")

        for _ in range(3):
            with pytest.raises(ValueError):
                fails()

        assert cb.state == "open"

    def test_rejects_calls_when_open(self):
        cb = CircuitBreaker(failure_threshold=1, reset_timeout=60.0)

        @cb
        def fails():
            raise ValueError("error")

        with pytest.raises(ValueError):
            fails()

        with pytest.raises(RetryError, match="Circuit breaker is open"):
            fails()

    def test_half_open_after_timeout(self):
        cb = CircuitBreaker(failure_threshold=1, reset_timeout=0.01)

        @cb
        def fails():
            raise ValueError("error")

        with pytest.raises(ValueError):
            fails()

        assert cb.state == "open"

        time.sleep(0.02)
        assert cb.state == "half-open"

    def test_closes_on_success_after_half_open(self):
        cb = CircuitBreaker(failure_threshold=1, reset_timeout=0.01)
        should_fail = True

        @cb
        def sometimes_fails():
            nonlocal should_fail
            if should_fail:
                raise ValueError("error")
            return "success"

        with pytest.raises(ValueError):
            sometimes_fails()

        time.sleep(0.02)
        should_fail = False
        result = sometimes_fails()

        assert result == "success"
        assert cb.state == "closed"

    def test_reset(self):
        cb = CircuitBreaker(failure_threshold=1)

        @cb
        def fails():
            raise ValueError("error")

        with pytest.raises(ValueError):
            fails()

        assert cb.state == "open"

        cb.reset()
        assert cb.state == "closed"
        assert cb.failures == 0
