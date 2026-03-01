package cache

import (
	"errors"
	"testing"
	"time"
)

func TestEntryIsExpired(t *testing.T) {
	// No expiry
	entry := Entry[int]{Value: 42, HasExpiry: false}
	if entry.IsExpired() {
		t.Error("Entry without expiry should not be expired")
	}

	// Future expiry
	entry = Entry[int]{Value: 42, ExpiresAt: time.Now().Add(time.Hour), HasExpiry: true}
	if entry.IsExpired() {
		t.Error("Entry with future expiry should not be expired")
	}

	// Past expiry
	entry = Entry[int]{Value: 42, ExpiresAt: time.Now().Add(-time.Hour), HasExpiry: true}
	if !entry.IsExpired() {
		t.Error("Entry with past expiry should be expired")
	}
}

func TestNewCache(t *testing.T) {
	cache := New[string, int](time.Minute)
	if cache == nil {
		t.Error("New should return non-nil cache")
	}
}

func TestCacheSetGet(t *testing.T) {
	cache := New[string, int](0)

	cache.Set("key", 42)
	value, ok := cache.Get("key")

	if !ok {
		t.Error("Expected key to exist")
	}
	if value != 42 {
		t.Errorf("Expected 42, got %d", value)
	}
}

func TestCacheGetMissing(t *testing.T) {
	cache := New[string, int](0)

	value, ok := cache.Get("missing")
	if ok {
		t.Error("Expected missing key to return false")
	}
	if value != 0 {
		t.Errorf("Expected zero value, got %d", value)
	}
}

func TestCacheExpiration(t *testing.T) {
	cache := New[string, int](50 * time.Millisecond)

	cache.Set("key", 42)

	// Should exist initially
	if _, ok := cache.Get("key"); !ok {
		t.Error("Key should exist immediately after set")
	}

	// Wait for expiration
	time.Sleep(60 * time.Millisecond)

	// Should be expired
	if _, ok := cache.Get("key"); ok {
		t.Error("Key should be expired")
	}
}

func TestCacheSetWithTTL(t *testing.T) {
	cache := New[string, int](time.Hour)

	cache.SetWithTTL("short", 42, 50*time.Millisecond)
	cache.Set("long", 43)

	time.Sleep(60 * time.Millisecond)

	if _, ok := cache.Get("short"); ok {
		t.Error("Short TTL key should be expired")
	}
	if _, ok := cache.Get("long"); !ok {
		t.Error("Long TTL key should still exist")
	}
}

func TestCacheDelete(t *testing.T) {
	cache := New[string, int](0)

	cache.Set("key", 42)
	deleted := cache.Delete("key")

	if !deleted {
		t.Error("Delete should return true for existing key")
	}
	if _, ok := cache.Get("key"); ok {
		t.Error("Key should not exist after delete")
	}

	deleted = cache.Delete("missing")
	if deleted {
		t.Error("Delete should return false for missing key")
	}
}

func TestCacheHas(t *testing.T) {
	cache := New[string, int](0)

	cache.Set("key", 42)

	if !cache.Has("key") {
		t.Error("Has should return true for existing key")
	}
	if cache.Has("missing") {
		t.Error("Has should return false for missing key")
	}
}

func TestCacheClear(t *testing.T) {
	cache := New[string, int](0)

	cache.Set("a", 1)
	cache.Set("b", 2)
	cache.Set("c", 3)

	cache.Clear()

	if cache.Len() != 0 {
		t.Errorf("Expected length 0 after clear, got %d", cache.Len())
	}
}

func TestCacheLen(t *testing.T) {
	cache := New[string, int](0)

	if cache.Len() != 0 {
		t.Error("New cache should have length 0")
	}

	cache.Set("a", 1)
	cache.Set("b", 2)

	if cache.Len() != 2 {
		t.Errorf("Expected length 2, got %d", cache.Len())
	}
}

func TestCacheKeys(t *testing.T) {
	cache := New[string, int](0)

	cache.Set("a", 1)
	cache.Set("b", 2)
	cache.Set("c", 3)

	keys := cache.Keys()
	if len(keys) != 3 {
		t.Errorf("Expected 3 keys, got %d", len(keys))
	}
}

func TestCacheKeysExcludesExpired(t *testing.T) {
	cache := New[string, int](0)

	cache.SetWithTTL("short", 1, 10*time.Millisecond)
	cache.Set("long", 2)

	time.Sleep(20 * time.Millisecond)

	keys := cache.Keys()
	if len(keys) != 1 {
		t.Errorf("Expected 1 key, got %d", len(keys))
	}
}

func TestCacheGetOrSet(t *testing.T) {
	cache := New[string, int](0)

	called := 0
	factory := func() int {
		called++
		return 42
	}

	// First call should invoke factory
	value := cache.GetOrSet("key", factory)
	if value != 42 {
		t.Errorf("Expected 42, got %d", value)
	}
	if called != 1 {
		t.Errorf("Factory should be called once, got %d", called)
	}

	// Second call should use cached value
	value = cache.GetOrSet("key", factory)
	if value != 42 {
		t.Errorf("Expected 42, got %d", value)
	}
	if called != 1 {
		t.Error("Factory should not be called again")
	}
}

func TestCacheCleanup(t *testing.T) {
	cache := New[string, int](0)

	cache.SetWithTTL("a", 1, 10*time.Millisecond)
	cache.SetWithTTL("b", 2, 10*time.Millisecond)
	cache.Set("c", 3)

	time.Sleep(20 * time.Millisecond)

	removed := cache.Cleanup()
	if removed != 2 {
		t.Errorf("Expected 2 removed, got %d", removed)
	}
	if cache.Len() != 1 {
		t.Errorf("Expected 1 remaining, got %d", cache.Len())
	}
}

func TestLoadingCache(t *testing.T) {
	loadCount := 0
	loader := func(key string) (int, error) {
		loadCount++
		return len(key), nil
	}

	cache := NewLoadingCache[string, int](0, loader)

	// First get should load
	value, err := cache.Get("hello")
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}
	if value != 5 {
		t.Errorf("Expected 5, got %d", value)
	}
	if loadCount != 1 {
		t.Errorf("Expected 1 load, got %d", loadCount)
	}

	// Second get should use cache
	value, err = cache.Get("hello")
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}
	if loadCount != 1 {
		t.Error("Should not reload")
	}
}

func TestLoadingCacheError(t *testing.T) {
	expectedErr := errors.New("load error")
	loader := func(key string) (int, error) {
		return 0, expectedErr
	}

	cache := NewLoadingCache[string, int](0, loader)

	_, err := cache.Get("key")
	if !errors.Is(err, expectedErr) {
		t.Errorf("Expected load error, got %v", err)
	}
}

func TestMultiCache(t *testing.T) {
	mc := NewMultiCache[string, int](0)

	users := mc.Namespace("users")
	products := mc.Namespace("products")

	users.Set("alice", 1)
	products.Set("widget", 100)

	if _, ok := users.Get("widget"); ok {
		t.Error("Users namespace should not have widget")
	}
	if _, ok := products.Get("alice"); ok {
		t.Error("Products namespace should not have alice")
	}
}

func TestMultiCacheSameNamespace(t *testing.T) {
	mc := NewMultiCache[string, int](0)

	ns1 := mc.Namespace("test")
	ns2 := mc.Namespace("test")

	if ns1 != ns2 {
		t.Error("Same namespace should return same cache")
	}
}

func TestMultiCacheClearAll(t *testing.T) {
	mc := NewMultiCache[string, int](0)

	mc.Namespace("a").Set("key", 1)
	mc.Namespace("b").Set("key", 2)

	mc.ClearAll()

	if _, ok := mc.Namespace("a").Get("key"); ok {
		t.Error("Namespace a should be cleared")
	}
	if _, ok := mc.Namespace("b").Get("key"); ok {
		t.Error("Namespace b should be cleared")
	}
}

func TestMultiCacheNamespaces(t *testing.T) {
	mc := NewMultiCache[string, int](0)

	mc.Namespace("a")
	mc.Namespace("b")
	mc.Namespace("c")

	names := mc.Namespaces()
	if len(names) != 3 {
		t.Errorf("Expected 3 namespaces, got %d", len(names))
	}
}

func TestCacheThreadSafety(t *testing.T) {
	cache := New[int, int](0)
	done := make(chan bool)

	// Concurrent writes
	for i := 0; i < 10; i++ {
		go func(n int) {
			for j := 0; j < 100; j++ {
				cache.Set(n*100+j, j)
			}
			done <- true
		}(i)
	}

	// Concurrent reads
	for i := 0; i < 10; i++ {
		go func() {
			for j := 0; j < 100; j++ {
				cache.Get(j)
			}
			done <- true
		}()
	}

	// Wait for all goroutines
	for i := 0; i < 20; i++ {
		<-done
	}
}
