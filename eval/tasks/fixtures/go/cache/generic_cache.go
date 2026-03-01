// Package cache implements a generic type-safe cache using Go generics
package cache

import (
	"sync"
	"time"
)

// Entry represents a cached item with optional expiration
type Entry[V any] struct {
	Value     V
	ExpiresAt time.Time
	HasExpiry bool
}

// IsExpired checks if the entry has expired
func (e Entry[V]) IsExpired() bool {
	if !e.HasExpiry {
		return false
	}
	return time.Now().After(e.ExpiresAt)
}

// Cache is a generic thread-safe cache
type Cache[K comparable, V any] struct {
	data       map[K]Entry[V]
	mu         sync.RWMutex
	defaultTTL time.Duration
}

// New creates a new cache with optional default TTL
func New[K comparable, V any](defaultTTL time.Duration) *Cache[K, V] {
	return &Cache[K, V]{
		data:       make(map[K]Entry[V]),
		defaultTTL: defaultTTL,
	}
}

// Get retrieves a value from the cache
func (c *Cache[K, V]) Get(key K) (V, bool) {
	c.mu.RLock()
	entry, ok := c.data[key]
	c.mu.RUnlock()

	if !ok {
		var zero V
		return zero, false
	}

	if entry.IsExpired() {
		c.Delete(key)
		var zero V
		return zero, false
	}

	return entry.Value, true
}

// Set stores a value in the cache with the default TTL
func (c *Cache[K, V]) Set(key K, value V) {
	c.SetWithTTL(key, value, c.defaultTTL)
}

// SetWithTTL stores a value with a specific TTL
func (c *Cache[K, V]) SetWithTTL(key K, value V, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()

	entry := Entry[V]{Value: value}
	if ttl > 0 {
		entry.ExpiresAt = time.Now().Add(ttl)
		entry.HasExpiry = true
	}
	c.data[key] = entry
}

// Delete removes a key from the cache
func (c *Cache[K, V]) Delete(key K) bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	_, ok := c.data[key]
	delete(c.data, key)
	return ok
}

// Has checks if a key exists and is not expired
func (c *Cache[K, V]) Has(key K) bool {
	c.mu.RLock()
	entry, ok := c.data[key]
	c.mu.RUnlock()

	if !ok {
		return false
	}

	if entry.IsExpired() {
		c.Delete(key)
		return false
	}

	return true
}

// Clear removes all entries
func (c *Cache[K, V]) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = make(map[K]Entry[V])
}

// Len returns the number of entries (including expired)
func (c *Cache[K, V]) Len() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return len(c.data)
}

// Keys returns all non-expired keys
func (c *Cache[K, V]) Keys() []K {
	c.mu.RLock()
	defer c.mu.RUnlock()

	keys := make([]K, 0, len(c.data))
	for k, v := range c.data {
		if !v.IsExpired() {
			keys = append(keys, k)
		}
	}
	return keys
}

// GetOrSet retrieves existing value or sets and returns new value
func (c *Cache[K, V]) GetOrSet(key K, factory func() V) V {
	if value, ok := c.Get(key); ok {
		return value
	}

	value := factory()
	c.Set(key, value)
	return value
}

// Cleanup removes all expired entries
func (c *Cache[K, V]) Cleanup() int {
	c.mu.Lock()
	defer c.mu.Unlock()

	removed := 0
	for k, v := range c.data {
		if v.IsExpired() {
			delete(c.data, k)
			removed++
		}
	}
	return removed
}

// LoaderFunc is a function that loads a value for a key
type LoaderFunc[K comparable, V any] func(key K) (V, error)

// LoadingCache extends Cache with automatic loading
type LoadingCache[K comparable, V any] struct {
	*Cache[K, V]
	loader LoaderFunc[K, V]
}

// NewLoadingCache creates a cache that automatically loads missing values
func NewLoadingCache[K comparable, V any](defaultTTL time.Duration, loader LoaderFunc[K, V]) *LoadingCache[K, V] {
	return &LoadingCache[K, V]{
		Cache:  New[K, V](defaultTTL),
		loader: loader,
	}
}

// Get retrieves from cache or loads if missing
func (lc *LoadingCache[K, V]) Get(key K) (V, error) {
	if value, ok := lc.Cache.Get(key); ok {
		return value, nil
	}

	value, err := lc.loader(key)
	if err != nil {
		var zero V
		return zero, err
	}

	lc.Set(key, value)
	return value, nil
}

// MultiCache provides namespace-based caching
type MultiCache[K comparable, V any] struct {
	caches map[string]*Cache[K, V]
	mu     sync.RWMutex
	ttl    time.Duration
}

// NewMultiCache creates a multi-namespace cache
func NewMultiCache[K comparable, V any](defaultTTL time.Duration) *MultiCache[K, V] {
	return &MultiCache[K, V]{
		caches: make(map[string]*Cache[K, V]),
		ttl:    defaultTTL,
	}
}

// Namespace returns or creates a cache for the namespace
func (mc *MultiCache[K, V]) Namespace(name string) *Cache[K, V] {
	mc.mu.RLock()
	if cache, ok := mc.caches[name]; ok {
		mc.mu.RUnlock()
		return cache
	}
	mc.mu.RUnlock()

	mc.mu.Lock()
	defer mc.mu.Unlock()

	if cache, ok := mc.caches[name]; ok {
		return cache
	}

	cache := New[K, V](mc.ttl)
	mc.caches[name] = cache
	return cache
}

// ClearAll clears all namespaces
func (mc *MultiCache[K, V]) ClearAll() {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	for _, cache := range mc.caches {
		cache.Clear()
	}
}

// Namespaces returns all namespace names
func (mc *MultiCache[K, V]) Namespaces() []string {
	mc.mu.RLock()
	defer mc.mu.RUnlock()

	names := make([]string, 0, len(mc.caches))
	for name := range mc.caches {
		names = append(names, name)
	}
	return names
}
