"""
Retry Decorator Implementation
Configurable retry logic with exponential backoff
"""

import time
import random
import functools
from typing import Callable, Type, Tuple, Optional, Any, TypeVar, Union
from dataclasses import dataclass


T = TypeVar('T')


class RetryError(Exception):
    """Raised when all retry attempts fail."""

    def __init__(self, message: str, attempts: int, last_exception: Optional[Exception] = None):
        self.message = message
        self.attempts = attempts
        self.last_exception = last_exception
        super().__init__(f"{message} after {attempts} attempts")


@dataclass
class RetryStats:
    """Statistics about a retry operation."""
    attempts: int
    total_time: float
    exceptions: list
    success: bool


class RetryConfig:
    """Configuration for retry behavior."""

    def __init__(
        self,
        max_attempts: int = 3,
        base_delay: float = 1.0,
        max_delay: float = 60.0,
        exponential_base: float = 2.0,
        jitter: bool = True,
        jitter_factor: float = 0.1,
        exceptions: Tuple[Type[Exception], ...] = (Exception,),
        on_retry: Optional[Callable[[int, Exception], None]] = None
    ):
        self.max_attempts = max_attempts
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.exponential_base = exponential_base
        self.jitter = jitter
        self.jitter_factor = jitter_factor
        self.exceptions = exceptions
        self.on_retry = on_retry

    def calculate_delay(self, attempt: int) -> float:
        """Calculate delay before next attempt using exponential backoff."""
        delay = self.base_delay * (self.exponential_base ** (attempt - 1))
        delay = min(delay, self.max_delay)

        if self.jitter:
            jitter_range = delay * self.jitter_factor
            delay += random.uniform(-jitter_range, jitter_range)

        return max(0, delay)


def retry(
    max_attempts: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 60.0,
    exponential_base: float = 2.0,
    jitter: bool = True,
    exceptions: Tuple[Type[Exception], ...] = (Exception,),
    on_retry: Optional[Callable[[int, Exception], None]] = None
) -> Callable[[Callable[..., T]], Callable[..., T]]:
    """
    Decorator that retries a function on failure.

    Args:
        max_attempts: Maximum number of attempts
        base_delay: Base delay between retries in seconds
        max_delay: Maximum delay between retries
        exponential_base: Base for exponential backoff
        jitter: Whether to add random jitter to delays
        exceptions: Tuple of exception types to retry on
        on_retry: Callback function called on each retry

    Returns:
        Decorated function
    """
    config = RetryConfig(
        max_attempts=max_attempts,
        base_delay=base_delay,
        max_delay=max_delay,
        exponential_base=exponential_base,
        jitter=jitter,
        exceptions=exceptions,
        on_retry=on_retry
    )

    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @functools.wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            return execute_with_retry(func, config, *args, **kwargs)
        return wrapper

    return decorator


def execute_with_retry(
    func: Callable[..., T],
    config: RetryConfig,
    *args: Any,
    **kwargs: Any
) -> T:
    """Execute a function with retry logic."""
    last_exception: Optional[Exception] = None

    for attempt in range(1, config.max_attempts + 1):
        try:
            return func(*args, **kwargs)
        except config.exceptions as e:
            last_exception = e

            if attempt == config.max_attempts:
                break

            if config.on_retry:
                config.on_retry(attempt, e)

            delay = config.calculate_delay(attempt)
            time.sleep(delay)

    raise RetryError(
        f"Function {func.__name__} failed",
        config.max_attempts,
        last_exception
    )


def retry_with_stats(
    func: Callable[..., T],
    config: RetryConfig,
    *args: Any,
    **kwargs: Any
) -> Tuple[T, RetryStats]:
    """Execute a function with retry logic and return statistics."""
    exceptions_raised: list = []
    start_time = time.time()

    for attempt in range(1, config.max_attempts + 1):
        try:
            result = func(*args, **kwargs)
            return result, RetryStats(
                attempts=attempt,
                total_time=time.time() - start_time,
                exceptions=exceptions_raised,
                success=True
            )
        except config.exceptions as e:
            exceptions_raised.append(e)

            if attempt == config.max_attempts:
                break

            if config.on_retry:
                config.on_retry(attempt, e)

            delay = config.calculate_delay(attempt)
            time.sleep(delay)

    raise RetryError(
        f"Function {func.__name__} failed",
        config.max_attempts,
        exceptions_raised[-1] if exceptions_raised else None
    )


class RetryContext:
    """Context manager for retry operations."""

    def __init__(self, config: RetryConfig):
        self.config = config
        self.attempt = 0
        self.exceptions: list = []
        self._success = False

    def __enter__(self) -> "RetryContext":
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        if exc_type is None:
            self._success = True
            return False

        if not issubclass(exc_type, self.config.exceptions):
            return False

        self.exceptions.append(exc_val)
        return True  # Suppress the exception

    def should_retry(self) -> bool:
        """Check if another retry attempt should be made."""
        if self._success:
            return False
        return self.attempt < self.config.max_attempts

    def wait(self) -> None:
        """Wait before the next retry attempt."""
        if self.attempt > 0:
            delay = self.config.calculate_delay(self.attempt)
            time.sleep(delay)
        self.attempt += 1

    @property
    def success(self) -> bool:
        return self._success


def with_fallback(
    func: Callable[..., T],
    fallback: Union[T, Callable[..., T]],
    exceptions: Tuple[Type[Exception], ...] = (Exception,)
) -> Callable[..., T]:
    """
    Wrap a function to use a fallback value on failure.

    Args:
        func: The function to wrap
        fallback: Value or function to use on failure
        exceptions: Exception types to catch

    Returns:
        Wrapped function
    """
    @functools.wraps(func)
    def wrapper(*args: Any, **kwargs: Any) -> T:
        try:
            return func(*args, **kwargs)
        except exceptions:
            if callable(fallback):
                return fallback(*args, **kwargs)
            return fallback

    return wrapper


def conditional_retry(
    predicate: Callable[[Any], bool],
    max_attempts: int = 3,
    base_delay: float = 1.0
) -> Callable[[Callable[..., T]], Callable[..., T]]:
    """
    Retry decorator that retries based on return value.

    Args:
        predicate: Function that returns True if result is acceptable
        max_attempts: Maximum number of attempts
        base_delay: Base delay between retries

    Returns:
        Decorated function
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @functools.wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            for attempt in range(1, max_attempts + 1):
                result = func(*args, **kwargs)
                if predicate(result):
                    return result

                if attempt < max_attempts:
                    time.sleep(base_delay * (2 ** (attempt - 1)))

            return result  # Return last result even if it didn't pass

        return wrapper

    return decorator


class CircuitBreaker:
    """
    Circuit breaker pattern implementation.

    Prevents repeated calls to a failing service.
    """

    def __init__(
        self,
        failure_threshold: int = 5,
        reset_timeout: float = 60.0,
        exceptions: Tuple[Type[Exception], ...] = (Exception,)
    ):
        self.failure_threshold = failure_threshold
        self.reset_timeout = reset_timeout
        self.exceptions = exceptions
        self.failures = 0
        self.last_failure_time: Optional[float] = None
        self._state = "closed"

    @property
    def state(self) -> str:
        """Get the current state of the circuit breaker."""
        if self._state == "open":
            if self.last_failure_time and time.time() - self.last_failure_time >= self.reset_timeout:
                self._state = "half-open"
        return self._state

    def __call__(self, func: Callable[..., T]) -> Callable[..., T]:
        @functools.wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            if self.state == "open":
                raise RetryError("Circuit breaker is open", self.failures)

            try:
                result = func(*args, **kwargs)
                self._on_success()
                return result
            except self.exceptions as e:
                self._on_failure()
                raise

        return wrapper

    def _on_success(self) -> None:
        """Handle successful call."""
        self.failures = 0
        self._state = "closed"

    def _on_failure(self) -> None:
        """Handle failed call."""
        self.failures += 1
        self.last_failure_time = time.time()

        if self.failures >= self.failure_threshold:
            self._state = "open"

    def reset(self) -> None:
        """Manually reset the circuit breaker."""
        self.failures = 0
        self.last_failure_time = None
        self._state = "closed"
