#[path = "chain_cache_3.rs"]
mod chain_cache_3;

use chain_cache_3::*;

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn test_in_memory_cache_creation() {
        let cache: InMemoryCache<String, String> = InMemoryCache::new();
        assert!(cache.get(&"key".to_string()).unwrap().is_none());
    }

    #[test]
    fn test_in_memory_cache_set_get() {
        let cache: InMemoryCache<String, i32> = InMemoryCache::new();
        cache.set("key".to_string(), 42, None).unwrap();
        assert_eq!(cache.get(&"key".to_string()).unwrap(), Some(42));
    }

    #[test]
    fn test_in_memory_cache_delete() {
        let cache: InMemoryCache<String, i32> = InMemoryCache::new();
        cache.set("key".to_string(), 42, None).unwrap();
        assert!(cache.delete(&"key".to_string()).unwrap());
        assert!(cache.get(&"key".to_string()).unwrap().is_none());
    }

    #[test]
    fn test_in_memory_cache_exists() {
        let cache: InMemoryCache<String, i32> = InMemoryCache::new();
        cache.set("key".to_string(), 42, None).unwrap();
        assert!(cache.exists(&"key".to_string()).unwrap());
        assert!(!cache.exists(&"other".to_string()).unwrap());
    }

    #[test]
    fn test_in_memory_cache_clear() {
        let cache: InMemoryCache<String, i32> = InMemoryCache::new();
        cache.set("key1".to_string(), 1, None).unwrap();
        cache.set("key2".to_string(), 2, None).unwrap();
        cache.clear().unwrap();
        assert!(cache.get(&"key1".to_string()).unwrap().is_none());
        assert!(cache.get(&"key2".to_string()).unwrap().is_none());
    }

    #[test]
    fn test_in_memory_cache_ttl() {
        let cache: InMemoryCache<String, i32> = InMemoryCache::new();
        cache
            .set("key".to_string(), 42, Some(Duration::from_millis(50)))
            .unwrap();

        assert_eq!(cache.get(&"key".to_string()).unwrap(), Some(42));
        thread::sleep(Duration::from_millis(100));
        assert!(cache.get(&"key".to_string()).unwrap().is_none());
    }

    #[test]
    fn test_in_memory_cache_get_many() {
        let cache: InMemoryCache<String, i32> = InMemoryCache::new();
        cache.set("a".to_string(), 1, None).unwrap();
        cache.set("b".to_string(), 2, None).unwrap();
        cache.set("c".to_string(), 3, None).unwrap();

        let keys = vec!["a".to_string(), "b".to_string(), "d".to_string()];
        let result = cache.get_many(&keys).unwrap();

        assert_eq!(result.get(&"a".to_string()), Some(&1));
        assert_eq!(result.get(&"b".to_string()), Some(&2));
        assert!(result.get(&"d".to_string()).is_none());
    }

    #[test]
    fn test_in_memory_cache_set_many() {
        let cache: InMemoryCache<String, i32> = InMemoryCache::new();
        let mut entries = HashMap::new();
        entries.insert("a".to_string(), 1);
        entries.insert("b".to_string(), 2);

        cache.set_many(entries, None).unwrap();

        assert_eq!(cache.get(&"a".to_string()).unwrap(), Some(1));
        assert_eq!(cache.get(&"b".to_string()).unwrap(), Some(2));
    }

    #[test]
    fn test_sharded_cache_creation() {
        let cache: ShardedCache<String, i32> = ShardedCache::new(4);
        assert!(cache.get(&"key".to_string()).unwrap().is_none());
    }

    #[test]
    fn test_sharded_cache_set_get() {
        let cache: ShardedCache<String, i32> = ShardedCache::new(4);
        cache.set("key".to_string(), 42, None).unwrap();
        assert_eq!(cache.get(&"key".to_string()).unwrap(), Some(42));
    }

    #[test]
    fn test_sharded_cache_delete() {
        let cache: ShardedCache<String, i32> = ShardedCache::new(4);
        cache.set("key".to_string(), 42, None).unwrap();
        assert!(cache.delete(&"key".to_string()).unwrap());
        assert!(cache.get(&"key".to_string()).unwrap().is_none());
    }

    #[test]
    fn test_sharded_cache_many_keys() {
        let cache: ShardedCache<i32, i32> = ShardedCache::new(4);
        for i in 0..100 {
            cache.set(i, i * 2, None).unwrap();
        }

        for i in 0..100 {
            assert_eq!(cache.get(&i).unwrap(), Some(i * 2));
        }
    }

    #[test]
    fn test_sharded_cache_clear() {
        let cache: ShardedCache<i32, i32> = ShardedCache::new(4);
        for i in 0..10 {
            cache.set(i, i, None).unwrap();
        }
        cache.clear().unwrap();
        for i in 0..10 {
            assert!(cache.get(&i).unwrap().is_none());
        }
    }

    #[test]
    fn test_write_through_cache() {
        let primary: InMemoryCache<String, i32> = InMemoryCache::new();
        let backing: InMemoryCache<String, i32> = InMemoryCache::new();
        let cache = WriteThroughCache::new(primary, backing);

        cache.set("key".to_string(), 42, None).unwrap();
        assert_eq!(cache.get(&"key".to_string()).unwrap(), Some(42));
    }

    #[test]
    fn test_write_through_cache_fallback() {
        let primary: InMemoryCache<String, i32> = InMemoryCache::new();
        let backing: InMemoryCache<String, i32> = InMemoryCache::new();

        // Pre-populate backing
        backing.set("key".to_string(), 42, None).unwrap();

        let cache = WriteThroughCache::new(primary, backing);

        // Should find in backing and populate primary
        assert_eq!(cache.get(&"key".to_string()).unwrap(), Some(42));
    }

    #[test]
    fn test_write_through_cache_delete() {
        let primary: InMemoryCache<String, i32> = InMemoryCache::new();
        let backing: InMemoryCache<String, i32> = InMemoryCache::new();
        let cache = WriteThroughCache::new(primary, backing);

        cache.set("key".to_string(), 42, None).unwrap();
        assert!(cache.delete(&"key".to_string()).unwrap());
        assert!(cache.get(&"key".to_string()).unwrap().is_none());
    }

    #[test]
    fn test_cache_error_display() {
        let err = CacheError::NotFound;
        assert_eq!(err.to_string(), "Key not found");

        let err = CacheError::ConnectionError("timeout".to_string());
        assert!(err.to_string().contains("Connection error"));

        let err = CacheError::SerializationError("invalid json".to_string());
        assert!(err.to_string().contains("Serialization error"));

        let err = CacheError::Timeout;
        assert!(err.to_string().contains("timed out"));

        let err = CacheError::InvalidKey;
        assert!(err.to_string().contains("Invalid key"));
    }

    #[test]
    fn test_sharded_cache_concurrent() {
        use std::sync::Arc;

        let cache = Arc::new(ShardedCache::<i32, i32>::new(8));
        let mut handles = vec![];

        for t in 0..4 {
            let cache = cache.clone();
            let handle = thread::spawn(move || {
                for i in 0..100 {
                    let key = t * 100 + i;
                    cache.set(key, key * 2, None).unwrap();
                }
            });
            handles.push(handle);
        }

        for handle in handles {
            handle.join().unwrap();
        }

        for t in 0..4 {
            for i in 0..100 {
                let key = t * 100 + i;
                assert_eq!(cache.get(&key).unwrap(), Some(key * 2));
            }
        }
    }

    #[test]
    fn test_distributed_cache_trait_object() {
        let cache: Box<dyn DistributedCache<String, i32>> =
            Box::new(InMemoryCache::<String, i32>::new());
        cache.set("key".to_string(), 42, None).unwrap();
        assert_eq!(cache.get(&"key".to_string()).unwrap(), Some(42));
    }
}
