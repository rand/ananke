"""
Context Manager Implementation
Resource management with __enter__ and __exit__ protocols
"""

from typing import TypeVar, Generic, Optional, Callable, Any
from contextlib import contextmanager
import time
import threading


T = TypeVar('T')


class ResourceManager(Generic[T]):
    """Generic resource manager with acquisition and release."""

    def __init__(
        self,
        acquire: Callable[[], T],
        release: Callable[[T], None],
        name: str = "resource"
    ):
        self._acquire = acquire
        self._release = release
        self._name = name
        self._resource: Optional[T] = None
        self._acquired = False

    def __enter__(self) -> T:
        if self._acquired:
            raise RuntimeError(f"{self._name} already acquired")
        self._resource = self._acquire()
        self._acquired = True
        return self._resource

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        if self._acquired and self._resource is not None:
            self._release(self._resource)
            self._acquired = False
            self._resource = None
        return False  # Don't suppress exceptions

    @property
    def is_acquired(self) -> bool:
        return self._acquired


class Timer:
    """Context manager for timing code blocks."""

    def __init__(self, name: str = "timer"):
        self.name = name
        self.start_time: float = 0
        self.end_time: float = 0
        self.elapsed: float = 0

    def __enter__(self) -> "Timer":
        self.start_time = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        self.end_time = time.perf_counter()
        self.elapsed = self.end_time - self.start_time
        return False


class Lock:
    """Context manager for thread-safe locking."""

    def __init__(self):
        self._lock = threading.Lock()
        self._owner: Optional[int] = None

    def __enter__(self) -> "Lock":
        self._lock.acquire()
        self._owner = threading.get_ident()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        self._owner = None
        self._lock.release()
        return False

    @property
    def is_locked(self) -> bool:
        return self._lock.locked()

    @property
    def owner(self) -> Optional[int]:
        return self._owner


class SuppressExceptions:
    """Context manager that suppresses specified exception types."""

    def __init__(self, *exception_types: type):
        self.exception_types = exception_types
        self.exception: Optional[BaseException] = None
        self.suppressed = False

    def __enter__(self) -> "SuppressExceptions":
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        if exc_type is not None and issubclass(exc_type, self.exception_types):
            self.exception = exc_val
            self.suppressed = True
            return True  # Suppress the exception
        return False


class Transaction:
    """Context manager for transactional operations with rollback."""

    def __init__(self):
        self._operations: list = []
        self._rollbacks: list = []
        self._committed = False

    def add_operation(self, operation: Callable[[], Any], rollback: Callable[[], None]) -> None:
        """Add an operation with its rollback function."""
        if self._committed:
            raise RuntimeError("Cannot add operations to committed transaction")
        result = operation()
        self._operations.append(result)
        self._rollbacks.append(rollback)

    def __enter__(self) -> "Transaction":
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        if exc_type is not None:
            # Rollback in reverse order
            for rollback in reversed(self._rollbacks):
                try:
                    rollback()
                except Exception:
                    pass  # Best effort rollback
            return False
        self._committed = True
        return False

    @property
    def is_committed(self) -> bool:
        return self._committed


class Redirect:
    """Context manager for redirecting output."""

    def __init__(self, target):
        self.target = target
        self._original = None

    def __enter__(self) -> "Redirect":
        import sys
        self._original = sys.stdout
        sys.stdout = self.target
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        import sys
        sys.stdout = self._original
        return False


@contextmanager
def temporary_value(obj: Any, attr: str, value: Any):
    """Temporarily set an attribute to a value."""
    original = getattr(obj, attr)
    setattr(obj, attr, value)
    try:
        yield
    finally:
        setattr(obj, attr, original)


@contextmanager
def cleanup(cleanup_func: Callable[[], None]):
    """Ensure cleanup function is called on exit."""
    try:
        yield
    finally:
        cleanup_func()


class NestedContextManager:
    """Context manager that manages multiple nested contexts."""

    def __init__(self, *managers):
        self.managers = list(managers)
        self._entered: list = []

    def __enter__(self) -> list:
        results = []
        for manager in self.managers:
            result = manager.__enter__()
            self._entered.append(manager)
            results.append(result)
        return results

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        exceptions = []
        # Exit in reverse order
        for manager in reversed(self._entered):
            try:
                manager.__exit__(exc_type, exc_val, exc_tb)
            except Exception as e:
                exceptions.append(e)
        self._entered.clear()

        if exceptions:
            raise exceptions[0]
        return False
