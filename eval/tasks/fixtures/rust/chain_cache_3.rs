//! Distributed Cache Interface (Chain Cache 3)
//! Demonstrates cache abstraction for distributed systems

use std::collections::HashMap;
use std::fmt;
use std::hash::Hash;
use std::sync::{Arc, RwLock};
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub enum CacheError {
    NotFound,
    ConnectionError(String),
    SerializationError(String),
    Timeout,
    InvalidKey,
}

impl fmt::Display for CacheError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CacheError::NotFound => write!(f, "Key not found"),
            CacheError::ConnectionError(msg) => write!(f, "Connection error: {}", msg),
            CacheError::SerializationError(msg) => write!(f, "Serialization error: {}", msg),
            CacheError::Timeout => write!(f, "Operation timed out"),
            CacheError::InvalidKey => write!(f, "Invalid key"),
        }
    }
}

impl std::error::Error for CacheError {}

pub type CacheResult<T> = Result<T, CacheError>;

pub trait DistributedCache<K, V>: Send + Sync {
    fn get(&self, key: &K) -> CacheResult<Option<V>>;
    fn set(&self, key: K, value: V, ttl: Option<Duration>) -> CacheResult<()>;
    fn delete(&self, key: &K) -> CacheResult<bool>;
    fn exists(&self, key: &K) -> CacheResult<bool>;
    fn clear(&self) -> CacheResult<()>;

    fn get_many(&self, keys: &[K]) -> CacheResult<HashMap<K, V>>
    where
        K: Clone + Eq + Hash,
        V: Clone;

    fn set_many(&self, entries: HashMap<K, V>, ttl: Option<Duration>) -> CacheResult<()>
    where
        K: Clone;
}

// In-memory implementation for testing
struct CacheEntry<V> {
    value: V,
    expires_at: Option<Instant>,
}

impl<V> CacheEntry<V> {
    fn is_expired(&self) -> bool {
        self.expires_at.map(|e| Instant::now() > e).unwrap_or(false)
    }
}

pub struct InMemoryCache<K, V> {
    data: Arc<RwLock<HashMap<K, CacheEntry<V>>>>,
}

impl<K: Eq + Hash + Clone, V: Clone> InMemoryCache<K, V> {
    pub fn new() -> Self {
        InMemoryCache {
            data: Arc::new(RwLock::new(HashMap::new())),
        }
    }
}

impl<K: Eq + Hash + Clone, V: Clone> Default for InMemoryCache<K, V> {
    fn default() -> Self {
        Self::new()
    }
}

impl<K: Eq + Hash + Clone + Send + Sync, V: Clone + Send + Sync> DistributedCache<K, V>
    for InMemoryCache<K, V>
{
    fn get(&self, key: &K) -> CacheResult<Option<V>> {
        let data = self.data.read().unwrap();
        match data.get(key) {
            Some(entry) if !entry.is_expired() => Ok(Some(entry.value.clone())),
            Some(_) => Ok(None), // Expired
            None => Ok(None),
        }
    }

    fn set(&self, key: K, value: V, ttl: Option<Duration>) -> CacheResult<()> {
        let mut data = self.data.write().unwrap();
        let expires_at = ttl.map(|d| Instant::now() + d);
        data.insert(key, CacheEntry { value, expires_at });
        Ok(())
    }

    fn delete(&self, key: &K) -> CacheResult<bool> {
        let mut data = self.data.write().unwrap();
        Ok(data.remove(key).is_some())
    }

    fn exists(&self, key: &K) -> CacheResult<bool> {
        let data = self.data.read().unwrap();
        match data.get(key) {
            Some(entry) => Ok(!entry.is_expired()),
            None => Ok(false),
        }
    }

    fn clear(&self) -> CacheResult<()> {
        let mut data = self.data.write().unwrap();
        data.clear();
        Ok(())
    }

    fn get_many(&self, keys: &[K]) -> CacheResult<HashMap<K, V>> {
        let data = self.data.read().unwrap();
        let mut result = HashMap::new();
        for key in keys {
            if let Some(entry) = data.get(key) {
                if !entry.is_expired() {
                    result.insert(key.clone(), entry.value.clone());
                }
            }
        }
        Ok(result)
    }

    fn set_many(&self, entries: HashMap<K, V>, ttl: Option<Duration>) -> CacheResult<()> {
        let mut data = self.data.write().unwrap();
        let expires_at = ttl.map(|d| Instant::now() + d);
        for (key, value) in entries {
            data.insert(key, CacheEntry { value, expires_at });
        }
        Ok(())
    }
}

// Cache with sharding for better concurrency
pub struct ShardedCache<K, V> {
    shards: Vec<Arc<RwLock<HashMap<K, CacheEntry<V>>>>>,
    num_shards: usize,
}

impl<K: Eq + Hash + Clone, V: Clone> ShardedCache<K, V> {
    pub fn new(num_shards: usize) -> Self {
        let shards = (0..num_shards)
            .map(|_| Arc::new(RwLock::new(HashMap::new())))
            .collect();
        ShardedCache { shards, num_shards }
    }

    fn shard_index(&self, key: &K) -> usize
    where
        K: Hash,
    {
        use std::hash::Hasher;
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        key.hash(&mut hasher);
        (hasher.finish() as usize) % self.num_shards
    }
}

impl<K: Eq + Hash + Clone + Send + Sync, V: Clone + Send + Sync> DistributedCache<K, V>
    for ShardedCache<K, V>
{
    fn get(&self, key: &K) -> CacheResult<Option<V>> {
        let idx = self.shard_index(key);
        let shard = self.shards[idx].read().unwrap();
        match shard.get(key) {
            Some(entry) if !entry.is_expired() => Ok(Some(entry.value.clone())),
            _ => Ok(None),
        }
    }

    fn set(&self, key: K, value: V, ttl: Option<Duration>) -> CacheResult<()> {
        let idx = self.shard_index(&key);
        let mut shard = self.shards[idx].write().unwrap();
        let expires_at = ttl.map(|d| Instant::now() + d);
        shard.insert(key, CacheEntry { value, expires_at });
        Ok(())
    }

    fn delete(&self, key: &K) -> CacheResult<bool> {
        let idx = self.shard_index(key);
        let mut shard = self.shards[idx].write().unwrap();
        Ok(shard.remove(key).is_some())
    }

    fn exists(&self, key: &K) -> CacheResult<bool> {
        let idx = self.shard_index(key);
        let shard = self.shards[idx].read().unwrap();
        match shard.get(key) {
            Some(entry) => Ok(!entry.is_expired()),
            None => Ok(false),
        }
    }

    fn clear(&self) -> CacheResult<()> {
        for shard in &self.shards {
            shard.write().unwrap().clear();
        }
        Ok(())
    }

    fn get_many(&self, keys: &[K]) -> CacheResult<HashMap<K, V>> {
        let mut result = HashMap::new();
        for key in keys {
            if let Ok(Some(value)) = self.get(key) {
                result.insert(key.clone(), value);
            }
        }
        Ok(result)
    }

    fn set_many(&self, entries: HashMap<K, V>, ttl: Option<Duration>) -> CacheResult<()> {
        for (key, value) in entries {
            self.set(key, value, ttl)?;
        }
        Ok(())
    }
}

// Write-through cache decorator
pub struct WriteThroughCache<K, V, P, B>
where
    P: DistributedCache<K, V>,
    B: DistributedCache<K, V>,
{
    primary: P,
    backing: B,
    _phantom: std::marker::PhantomData<(K, V)>,
}

impl<K, V, P, B> WriteThroughCache<K, V, P, B>
where
    P: DistributedCache<K, V>,
    B: DistributedCache<K, V>,
{
    pub fn new(primary: P, backing: B) -> Self {
        WriteThroughCache {
            primary,
            backing,
            _phantom: std::marker::PhantomData,
        }
    }
}

impl<K, V, P, B> DistributedCache<K, V> for WriteThroughCache<K, V, P, B>
where
    K: Eq + Hash + Clone + Send + Sync,
    V: Clone + Send + Sync,
    P: DistributedCache<K, V>,
    B: DistributedCache<K, V>,
{
    fn get(&self, key: &K) -> CacheResult<Option<V>> {
        // Try primary first
        if let Ok(Some(value)) = self.primary.get(key) {
            return Ok(Some(value));
        }
        // Fall back to backing
        if let Ok(Some(value)) = self.backing.get(key) {
            // Populate primary
            let _ = self.primary.set(key.clone(), value.clone(), None);
            return Ok(Some(value));
        }
        Ok(None)
    }

    fn set(&self, key: K, value: V, ttl: Option<Duration>) -> CacheResult<()> {
        // Write to both
        self.primary.set(key.clone(), value.clone(), ttl)?;
        self.backing.set(key, value, ttl)?;
        Ok(())
    }

    fn delete(&self, key: &K) -> CacheResult<bool> {
        let p = self.primary.delete(key)?;
        let b = self.backing.delete(key)?;
        Ok(p || b)
    }

    fn exists(&self, key: &K) -> CacheResult<bool> {
        Ok(self.primary.exists(key)? || self.backing.exists(key)?)
    }

    fn clear(&self) -> CacheResult<()> {
        self.primary.clear()?;
        self.backing.clear()?;
        Ok(())
    }

    fn get_many(&self, keys: &[K]) -> CacheResult<HashMap<K, V>> {
        let mut result = self.primary.get_many(keys)?;
        let missing: Vec<K> = keys
            .iter()
            .filter(|k| !result.contains_key(*k))
            .cloned()
            .collect();
        if !missing.is_empty() {
            let from_backing = self.backing.get_many(&missing)?;
            result.extend(from_backing);
        }
        Ok(result)
    }

    fn set_many(&self, entries: HashMap<K, V>, ttl: Option<Duration>) -> CacheResult<()> {
        self.primary.set_many(entries.clone(), ttl)?;
        self.backing.set_many(entries, ttl)?;
        Ok(())
    }
}
