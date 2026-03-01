// Package circuitbreaker implements the circuit breaker pattern
package circuitbreaker

import (
	"errors"
	"sync"
	"time"
)

// State represents the circuit breaker state
type State int

const (
	StateClosed State = iota
	StateOpen
	StateHalfOpen
)

func (s State) String() string {
	switch s {
	case StateClosed:
		return "closed"
	case StateOpen:
		return "open"
	case StateHalfOpen:
		return "half-open"
	default:
		return "unknown"
	}
}

// Errors
var (
	ErrCircuitOpen     = errors.New("circuit breaker is open")
	ErrTooManyRequests = errors.New("too many requests in half-open state")
)

// Config configures the circuit breaker
type Config struct {
	MaxFailures     int           // Failures before opening
	Timeout         time.Duration // Time in open state before half-open
	HalfOpenMax     int           // Max requests in half-open state
	SuccessRequired int           // Successes in half-open to close
}

// DefaultConfig returns sensible defaults
func DefaultConfig() Config {
	return Config{
		MaxFailures:     5,
		Timeout:         30 * time.Second,
		HalfOpenMax:     3,
		SuccessRequired: 2,
	}
}

// CircuitBreaker implements the circuit breaker pattern
type CircuitBreaker struct {
	config Config

	mu              sync.Mutex
	state           State
	failures        int
	successes       int
	halfOpenCount   int
	lastFailureTime time.Time
}

// New creates a new circuit breaker with the given config
func New(config Config) *CircuitBreaker {
	if config.MaxFailures <= 0 {
		config.MaxFailures = 5
	}
	if config.Timeout <= 0 {
		config.Timeout = 30 * time.Second
	}
	if config.HalfOpenMax <= 0 {
		config.HalfOpenMax = 3
	}
	if config.SuccessRequired <= 0 {
		config.SuccessRequired = 2
	}

	return &CircuitBreaker{
		config: config,
		state:  StateClosed,
	}
}

// Execute runs the given function if the circuit allows it
func (cb *CircuitBreaker) Execute(fn func() error) error {
	if err := cb.beforeRequest(); err != nil {
		return err
	}

	err := fn()
	cb.afterRequest(err == nil)
	return err
}

// State returns the current state
func (cb *CircuitBreaker) State() State {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	cb.checkStateTransition()
	return cb.state
}

// Failures returns the current failure count
func (cb *CircuitBreaker) Failures() int {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	return cb.failures
}

// Reset resets the circuit breaker to closed state
func (cb *CircuitBreaker) Reset() {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	cb.state = StateClosed
	cb.failures = 0
	cb.successes = 0
	cb.halfOpenCount = 0
}

func (cb *CircuitBreaker) beforeRequest() error {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.checkStateTransition()

	switch cb.state {
	case StateClosed:
		return nil
	case StateOpen:
		return ErrCircuitOpen
	case StateHalfOpen:
		if cb.halfOpenCount >= cb.config.HalfOpenMax {
			return ErrTooManyRequests
		}
		cb.halfOpenCount++
		return nil
	}

	return nil
}

func (cb *CircuitBreaker) afterRequest(success bool) {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	switch cb.state {
	case StateClosed:
		if success {
			cb.failures = 0
		} else {
			cb.failures++
			cb.lastFailureTime = time.Now()
			if cb.failures >= cb.config.MaxFailures {
				cb.state = StateOpen
			}
		}
	case StateHalfOpen:
		if success {
			cb.successes++
			if cb.successes >= cb.config.SuccessRequired {
				cb.state = StateClosed
				cb.failures = 0
				cb.successes = 0
				cb.halfOpenCount = 0
			}
		} else {
			cb.state = StateOpen
			cb.lastFailureTime = time.Now()
			cb.successes = 0
			cb.halfOpenCount = 0
		}
	}
}

func (cb *CircuitBreaker) checkStateTransition() {
	if cb.state == StateOpen {
		if time.Since(cb.lastFailureTime) >= cb.config.Timeout {
			cb.state = StateHalfOpen
			cb.halfOpenCount = 0
			cb.successes = 0
		}
	}
}

// Stats contains circuit breaker statistics
type Stats struct {
	State       State
	Failures    int
	Successes   int
	HalfOpenReq int
}

// Stats returns current statistics
func (cb *CircuitBreaker) Stats() Stats {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	return Stats{
		State:       cb.state,
		Failures:    cb.failures,
		Successes:   cb.successes,
		HalfOpenReq: cb.halfOpenCount,
	}
}

// CircuitBreakerGroup manages multiple circuit breakers by key
type CircuitBreakerGroup struct {
	config   Config
	breakers map[string]*CircuitBreaker
	mu       sync.RWMutex
}

// NewGroup creates a group of circuit breakers
func NewGroup(config Config) *CircuitBreakerGroup {
	return &CircuitBreakerGroup{
		config:   config,
		breakers: make(map[string]*CircuitBreaker),
	}
}

// Get returns the circuit breaker for the given key
func (g *CircuitBreakerGroup) Get(key string) *CircuitBreaker {
	g.mu.RLock()
	if cb, ok := g.breakers[key]; ok {
		g.mu.RUnlock()
		return cb
	}
	g.mu.RUnlock()

	g.mu.Lock()
	defer g.mu.Unlock()

	// Double-check after acquiring write lock
	if cb, ok := g.breakers[key]; ok {
		return cb
	}

	cb := New(g.config)
	g.breakers[key] = cb
	return cb
}

// Execute runs the function with the circuit breaker for the given key
func (g *CircuitBreakerGroup) Execute(key string, fn func() error) error {
	return g.Get(key).Execute(fn)
}

// ResetAll resets all circuit breakers
func (g *CircuitBreakerGroup) ResetAll() {
	g.mu.Lock()
	defer g.mu.Unlock()
	for _, cb := range g.breakers {
		cb.Reset()
	}
}

// Remove removes a circuit breaker by key
func (g *CircuitBreakerGroup) Remove(key string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	delete(g.breakers, key)
}
