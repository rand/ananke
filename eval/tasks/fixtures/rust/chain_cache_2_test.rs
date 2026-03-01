#[path = "chain_cache_2.rs"]
mod chain_cache_2;

use chain_cache_2::*;

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn test_lru_cache_creation() {
        let cache: LruCache<i32, i32> = LruCache::new(10);
        assert_eq!(cache.capacity(), 10);
        assert!(cache.is_empty());
        assert_eq!(cache.len(), 0);
    }

    #[test]
    #[should_panic(expected = "Capacity must be greater than 0")]
    fn test_lru_cache_zero_capacity() {
        let _cache: LruCache<i32, i32> = LruCache::new(0);
    }

    #[test]
    fn test_lru_cache_put_get() {
        let mut cache = LruCache::new(10);
        cache.put("key1", "value1");
        cache.put("key2", "value2");

        assert_eq!(cache.get(&"key1"), Some(&"value1"));
        assert_eq!(cache.get(&"key2"), Some(&"value2"));
        assert_eq!(cache.get(&"key3"), None);
    }

    #[test]
    fn test_lru_cache_update() {
        let mut cache = LruCache::new(10);
        cache.put("key", "value1");
        let old = cache.put("key", "value2");

        assert_eq!(old, Some("value1"));
        assert_eq!(cache.get(&"key"), Some(&"value2"));
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn test_lru_cache_eviction() {
        let mut cache = LruCache::new(3);
        cache.put(1, "a");
        cache.put(2, "b");
        cache.put(3, "c");
        cache.put(4, "d"); // Should evict 1

        assert_eq!(cache.len(), 3);
        assert_eq!(cache.get(&1), None);
        assert_eq!(cache.get(&2), Some(&"b"));
        assert_eq!(cache.get(&3), Some(&"c"));
        assert_eq!(cache.get(&4), Some(&"d"));
    }

    #[test]
    fn test_lru_cache_access_updates_order() {
        let mut cache = LruCache::new(3);
        cache.put(1, "a");
        cache.put(2, "b");
        cache.put(3, "c");

        // Access 1, making it most recently used
        cache.get(&1);

        // Insert 4, should evict 2 (least recently used)
        cache.put(4, "d");

        assert_eq!(cache.get(&1), Some(&"a"));
        assert_eq!(cache.get(&2), None);
        assert_eq!(cache.get(&3), Some(&"c"));
        assert_eq!(cache.get(&4), Some(&"d"));
    }

    #[test]
    fn test_lru_cache_peek() {
        let mut cache = LruCache::new(3);
        cache.put(1, "a");
        cache.put(2, "b");
        cache.put(3, "c");

        // Peek should not update order
        assert_eq!(cache.peek(&1), Some(&"a"));

        // Insert 4, should still evict 1 since peek doesn't update
        cache.put(4, "d");

        assert_eq!(cache.peek(&1), None);
    }

    #[test]
    fn test_lru_cache_remove() {
        let mut cache = LruCache::new(10);
        cache.put("key", "value");

        assert!(cache.contains(&"key"));
        let removed = cache.remove(&"key");
        assert_eq!(removed, Some("value"));
        assert!(!cache.contains(&"key"));
    }

    #[test]
    fn test_lru_cache_clear() {
        let mut cache = LruCache::new(10);
        cache.put(1, "a");
        cache.put(2, "b");
        cache.put(3, "c");

        assert_eq!(cache.len(), 3);
        cache.clear();
        assert!(cache.is_empty());
        assert_eq!(cache.get(&1), None);
    }

    #[test]
    fn test_lru_cache_keys() {
        let mut cache = LruCache::new(10);
        cache.put(1, "a");
        cache.put(2, "b");
        cache.put(3, "c");

        let keys = cache.keys();
        // Most recently used first
        assert_eq!(keys, vec![3, 2, 1]);
    }

    #[test]
    fn test_lru_cache_keys_after_access() {
        let mut cache = LruCache::new(10);
        cache.put(1, "a");
        cache.put(2, "b");
        cache.put(3, "c");
        cache.get(&1); // Access 1

        let keys = cache.keys();
        assert_eq!(keys, vec![1, 3, 2]);
    }

    #[test]
    fn test_lru_cache_contains() {
        let mut cache = LruCache::new(10);
        cache.put("key", "value");

        assert!(cache.contains(&"key"));
        assert!(!cache.contains(&"other"));
    }

    #[test]
    fn test_ttl_lru_cache_creation() {
        let cache: TtlLruCache<i32, i32> = TtlLruCache::new(10, Duration::from_secs(60));
        assert!(cache.is_empty());
    }

    #[test]
    fn test_ttl_lru_cache_put_get() {
        let mut cache = TtlLruCache::new(10, Duration::from_secs(60));
        cache.put("key", "value");
        assert_eq!(cache.get(&"key"), Some(&"value"));
    }

    #[test]
    fn test_ttl_lru_cache_remove() {
        let mut cache = TtlLruCache::new(10, Duration::from_secs(60));
        cache.put("key", "value");
        let removed = cache.remove(&"key");
        assert_eq!(removed, Some("value"));
        assert_eq!(cache.get(&"key"), None);
    }

    #[test]
    fn test_lru_cache_stress() {
        let mut cache = LruCache::new(100);

        // Insert many items
        for i in 0..1000 {
            cache.put(i, i * 2);
        }

        // Only last 100 should remain
        assert_eq!(cache.len(), 100);

        for i in 0..900 {
            assert_eq!(cache.get(&i), None);
        }

        for i in 900..1000 {
            assert_eq!(cache.get(&i), Some(&(i * 2)));
        }
    }

    #[test]
    fn test_lru_cache_single_capacity() {
        let mut cache = LruCache::new(1);
        cache.put(1, "a");
        cache.put(2, "b");

        assert_eq!(cache.len(), 1);
        assert_eq!(cache.get(&1), None);
        assert_eq!(cache.get(&2), Some(&"b"));
    }
}
