package circuitbreaker

import (
	"errors"
	"testing"
	"time"
)

func TestStateString(t *testing.T) {
	tests := []struct {
		state    State
		expected string
	}{
		{StateClosed, "closed"},
		{StateOpen, "open"},
		{StateHalfOpen, "half-open"},
		{State(99), "unknown"},
	}

	for _, tt := range tests {
		if tt.state.String() != tt.expected {
			t.Errorf("State(%d).String() = %s, want %s", tt.state, tt.state.String(), tt.expected)
		}
	}
}

func TestDefaultConfig(t *testing.T) {
	config := DefaultConfig()
	if config.MaxFailures != 5 {
		t.Errorf("Expected MaxFailures 5, got %d", config.MaxFailures)
	}
	if config.HalfOpenMax != 3 {
		t.Errorf("Expected HalfOpenMax 3, got %d", config.HalfOpenMax)
	}
}

func TestNewCircuitBreaker(t *testing.T) {
	cb := New(DefaultConfig())
	if cb.State() != StateClosed {
		t.Errorf("Expected initial state closed, got %s", cb.State())
	}
}

func TestCircuitBreakerSuccess(t *testing.T) {
	cb := New(DefaultConfig())

	err := cb.Execute(func() error {
		return nil
	})

	if err != nil {
		t.Errorf("Expected no error, got %v", err)
	}
	if cb.State() != StateClosed {
		t.Errorf("Expected state closed, got %s", cb.State())
	}
}

func TestCircuitBreakerOpensAfterFailures(t *testing.T) {
	config := Config{
		MaxFailures:     3,
		Timeout:         time.Second,
		HalfOpenMax:     2,
		SuccessRequired: 2,
	}
	cb := New(config)

	testErr := errors.New("test error")

	for i := 0; i < 3; i++ {
		cb.Execute(func() error {
			return testErr
		})
	}

	if cb.State() != StateOpen {
		t.Errorf("Expected state open after 3 failures, got %s", cb.State())
	}
}

func TestCircuitBreakerRejectsWhenOpen(t *testing.T) {
	config := Config{
		MaxFailures: 1,
		Timeout:     time.Hour, // Long timeout
	}
	cb := New(config)

	// Trigger opening
	cb.Execute(func() error {
		return errors.New("fail")
	})

	err := cb.Execute(func() error {
		return nil
	})

	if !errors.Is(err, ErrCircuitOpen) {
		t.Errorf("Expected ErrCircuitOpen, got %v", err)
	}
}

func TestCircuitBreakerTransitionsToHalfOpen(t *testing.T) {
	config := Config{
		MaxFailures: 1,
		Timeout:     10 * time.Millisecond,
	}
	cb := New(config)

	// Trigger opening
	cb.Execute(func() error {
		return errors.New("fail")
	})

	if cb.State() != StateOpen {
		t.Errorf("Expected state open, got %s", cb.State())
	}

	// Wait for timeout
	time.Sleep(20 * time.Millisecond)

	if cb.State() != StateHalfOpen {
		t.Errorf("Expected state half-open, got %s", cb.State())
	}
}

func TestCircuitBreakerClosesAfterSuccessInHalfOpen(t *testing.T) {
	config := Config{
		MaxFailures:     1,
		Timeout:         10 * time.Millisecond,
		HalfOpenMax:     5,
		SuccessRequired: 2,
	}
	cb := New(config)

	// Trigger opening
	cb.Execute(func() error { return errors.New("fail") })
	time.Sleep(20 * time.Millisecond)

	// Should be half-open now
	if cb.State() != StateHalfOpen {
		t.Errorf("Expected half-open, got %s", cb.State())
	}

	// Two successes should close it
	cb.Execute(func() error { return nil })
	cb.Execute(func() error { return nil })

	if cb.State() != StateClosed {
		t.Errorf("Expected closed after successes, got %s", cb.State())
	}
}

func TestCircuitBreakerReopensOnFailureInHalfOpen(t *testing.T) {
	config := Config{
		MaxFailures:     1,
		Timeout:         10 * time.Millisecond,
		HalfOpenMax:     5,
		SuccessRequired: 2,
	}
	cb := New(config)

	// Trigger opening
	cb.Execute(func() error { return errors.New("fail") })
	time.Sleep(20 * time.Millisecond)

	// Success then failure
	cb.Execute(func() error { return nil })
	cb.Execute(func() error { return errors.New("fail") })

	if cb.State() != StateOpen {
		t.Errorf("Expected open after failure in half-open, got %s", cb.State())
	}
}

func TestCircuitBreakerHalfOpenLimit(t *testing.T) {
	config := Config{
		MaxFailures:     1,
		Timeout:         10 * time.Millisecond,
		HalfOpenMax:     2,
		SuccessRequired: 5, // Higher than HalfOpenMax so circuit stays half-open
	}
	cb := New(config)

	// Trigger opening
	cb.Execute(func() error { return errors.New("fail") })
	time.Sleep(20 * time.Millisecond)

	// First two should be allowed
	cb.Execute(func() error { return nil })
	cb.Execute(func() error { return nil })

	// Third should be rejected
	err := cb.Execute(func() error { return nil })
	if !errors.Is(err, ErrTooManyRequests) {
		t.Errorf("Expected ErrTooManyRequests, got %v", err)
	}
}

func TestCircuitBreakerReset(t *testing.T) {
	config := Config{MaxFailures: 1}
	cb := New(config)

	// Trigger opening
	cb.Execute(func() error { return errors.New("fail") })
	if cb.State() != StateOpen {
		t.Errorf("Expected open, got %s", cb.State())
	}

	cb.Reset()

	if cb.State() != StateClosed {
		t.Errorf("Expected closed after reset, got %s", cb.State())
	}
}

func TestCircuitBreakerStats(t *testing.T) {
	config := Config{MaxFailures: 5}
	cb := New(config)

	cb.Execute(func() error { return errors.New("fail") })
	cb.Execute(func() error { return errors.New("fail") })

	stats := cb.Stats()
	if stats.State != StateClosed {
		t.Errorf("Expected closed, got %s", stats.State)
	}
	if stats.Failures != 2 {
		t.Errorf("Expected 2 failures, got %d", stats.Failures)
	}
}

func TestCircuitBreakerFailures(t *testing.T) {
	config := Config{MaxFailures: 5}
	cb := New(config)

	cb.Execute(func() error { return errors.New("fail") })
	cb.Execute(func() error { return errors.New("fail") })

	if cb.Failures() != 2 {
		t.Errorf("Expected 2 failures, got %d", cb.Failures())
	}
}

func TestCircuitBreakerSuccessResetsFailures(t *testing.T) {
	config := Config{MaxFailures: 5}
	cb := New(config)

	cb.Execute(func() error { return errors.New("fail") })
	cb.Execute(func() error { return errors.New("fail") })
	cb.Execute(func() error { return nil })

	if cb.Failures() != 0 {
		t.Errorf("Expected 0 failures after success, got %d", cb.Failures())
	}
}

func TestCircuitBreakerGroup(t *testing.T) {
	group := NewGroup(DefaultConfig())

	cb1 := group.Get("service1")
	cb2 := group.Get("service2")

	if cb1 == cb2 {
		t.Error("Different keys should return different breakers")
	}

	cb1Again := group.Get("service1")
	if cb1 != cb1Again {
		t.Error("Same key should return same breaker")
	}
}

func TestCircuitBreakerGroupExecute(t *testing.T) {
	group := NewGroup(Config{MaxFailures: 1})

	err := group.Execute("service1", func() error {
		return errors.New("fail")
	})
	if err == nil {
		t.Error("Expected error from failing function")
	}

	err = group.Execute("service1", func() error {
		return nil
	})
	if !errors.Is(err, ErrCircuitOpen) {
		t.Errorf("Expected ErrCircuitOpen, got %v", err)
	}

	// Different service should still work
	err = group.Execute("service2", func() error {
		return nil
	})
	if err != nil {
		t.Errorf("Expected no error for service2, got %v", err)
	}
}

func TestCircuitBreakerGroupResetAll(t *testing.T) {
	group := NewGroup(Config{MaxFailures: 1})

	group.Execute("s1", func() error { return errors.New("fail") })
	group.Execute("s2", func() error { return errors.New("fail") })

	group.ResetAll()

	// Should work now
	err := group.Execute("s1", func() error { return nil })
	if err != nil {
		t.Errorf("Expected no error after reset, got %v", err)
	}
}

func TestCircuitBreakerGroupRemove(t *testing.T) {
	group := NewGroup(Config{MaxFailures: 1})

	group.Execute("service", func() error { return errors.New("fail") })
	group.Remove("service")

	// Should get a fresh breaker
	err := group.Execute("service", func() error { return nil })
	if err != nil {
		t.Errorf("Expected no error after remove, got %v", err)
	}
}
