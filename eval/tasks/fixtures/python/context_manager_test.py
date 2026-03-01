"""Tests for Context Manager Implementation"""

import pytest
import io
import time
from context_manager import (
    ResourceManager,
    Timer,
    Lock,
    SuppressExceptions,
    Transaction,
    Redirect,
    temporary_value,
    cleanup,
    NestedContextManager
)


class TestResourceManager:
    def test_acquires_and_releases_resource(self):
        acquired = []
        released = []

        with ResourceManager(
            acquire=lambda: acquired.append(1) or "resource",
            release=lambda r: released.append(r),
            name="test"
        ) as resource:
            assert resource == "resource"
            assert len(acquired) == 1

        assert len(released) == 1
        assert released[0] == "resource"

    def test_raises_on_double_acquire(self):
        manager = ResourceManager(
            acquire=lambda: "resource",
            release=lambda r: None
        )

        with manager:
            with pytest.raises(RuntimeError, match="already acquired"):
                manager.__enter__()

    def test_is_acquired_property(self):
        manager = ResourceManager(
            acquire=lambda: "resource",
            release=lambda r: None
        )

        assert not manager.is_acquired
        with manager:
            assert manager.is_acquired
        assert not manager.is_acquired


class TestTimer:
    def test_measures_elapsed_time(self):
        with Timer() as timer:
            time.sleep(0.01)

        assert timer.elapsed >= 0.01
        assert timer.elapsed < 0.1

    def test_stores_start_and_end_times(self):
        with Timer() as timer:
            pass

        assert timer.start_time > 0
        assert timer.end_time >= timer.start_time

    def test_timer_name(self):
        timer = Timer(name="my_timer")
        assert timer.name == "my_timer"


class TestLock:
    def test_acquires_and_releases_lock(self):
        lock = Lock()
        assert not lock.is_locked

        with lock:
            assert lock.is_locked
            assert lock.owner is not None

        assert not lock.is_locked

    def test_lock_owner_cleared_on_exit(self):
        lock = Lock()
        with lock:
            pass
        assert lock.owner is None


class TestSuppressExceptions:
    def test_suppresses_specified_exceptions(self):
        with SuppressExceptions(ValueError, TypeError) as ctx:
            raise ValueError("test error")

        assert ctx.suppressed
        assert isinstance(ctx.exception, ValueError)

    def test_does_not_suppress_other_exceptions(self):
        with pytest.raises(RuntimeError):
            with SuppressExceptions(ValueError):
                raise RuntimeError("not suppressed")

    def test_no_exception_case(self):
        with SuppressExceptions(ValueError) as ctx:
            pass

        assert not ctx.suppressed
        assert ctx.exception is None


class TestTransaction:
    def test_commits_on_success(self):
        results = []

        with Transaction() as tx:
            tx.add_operation(
                operation=lambda: results.append("op1"),
                rollback=lambda: results.remove("op1")
            )
            tx.add_operation(
                operation=lambda: results.append("op2"),
                rollback=lambda: results.remove("op2")
            )

        assert tx.is_committed
        assert results == ["op1", "op2"]

    def test_rolls_back_on_exception(self):
        results = []

        with pytest.raises(RuntimeError):
            with Transaction() as tx:
                tx.add_operation(
                    operation=lambda: results.append("op1"),
                    rollback=lambda: results.remove("op1")
                )
                raise RuntimeError("failure")

        assert not tx.is_committed
        assert results == []

    def test_rollback_order(self):
        rollback_order = []

        with pytest.raises(RuntimeError):
            with Transaction() as tx:
                tx.add_operation(
                    operation=lambda: None,
                    rollback=lambda: rollback_order.append(1)
                )
                tx.add_operation(
                    operation=lambda: None,
                    rollback=lambda: rollback_order.append(2)
                )
                raise RuntimeError("failure")

        assert rollback_order == [2, 1]  # Reverse order

    def test_cannot_add_to_committed_transaction(self):
        with Transaction() as tx:
            pass

        with pytest.raises(RuntimeError, match="committed"):
            tx.add_operation(lambda: None, lambda: None)


class TestRedirect:
    def test_redirects_output(self):
        buffer = io.StringIO()

        with Redirect(buffer):
            print("hello")

        assert buffer.getvalue() == "hello\n"

    def test_restores_original_stdout(self):
        import sys
        original = sys.stdout

        with Redirect(io.StringIO()):
            pass

        assert sys.stdout is original


class TestTemporaryValue:
    def test_temporarily_sets_value(self):
        class Obj:
            value = 1

        obj = Obj()
        assert obj.value == 1

        with temporary_value(obj, "value", 42):
            assert obj.value == 42

        assert obj.value == 1

    def test_restores_on_exception(self):
        class Obj:
            value = 1

        obj = Obj()

        with pytest.raises(RuntimeError):
            with temporary_value(obj, "value", 42):
                raise RuntimeError()

        assert obj.value == 1


class TestCleanup:
    def test_calls_cleanup_on_success(self):
        cleaned = []

        with cleanup(lambda: cleaned.append(True)):
            pass

        assert cleaned == [True]

    def test_calls_cleanup_on_exception(self):
        cleaned = []

        with pytest.raises(RuntimeError):
            with cleanup(lambda: cleaned.append(True)):
                raise RuntimeError()

        assert cleaned == [True]


class TestNestedContextManager:
    def test_enters_all_managers(self):
        class SimpleManager:
            def __init__(self, value):
                self.value = value

            def __enter__(self):
                return self.value

            def __exit__(self, *args):
                return False

        m1 = SimpleManager(1)
        m2 = SimpleManager(2)
        m3 = SimpleManager(3)

        with NestedContextManager(m1, m2, m3) as results:
            assert results == [1, 2, 3]

    def test_exits_in_reverse_order(self):
        exit_order = []

        class TrackingManager:
            def __init__(self, name):
                self.name = name

            def __enter__(self):
                return self.name

            def __exit__(self, *args):
                exit_order.append(self.name)
                return False

        m1 = TrackingManager("first")
        m2 = TrackingManager("second")
        m3 = TrackingManager("third")

        with NestedContextManager(m1, m2, m3):
            pass

        assert exit_order == ["third", "second", "first"]
