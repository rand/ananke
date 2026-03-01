//! Memoization Cache Implementation (Chain Cache 1)
//! Demonstrates basic function memoization in Rust

use std::collections::HashMap;
use std::hash::Hash;

pub struct Memoize<K, V> {
    cache: HashMap<K, V>,
}

impl<K: Eq + Hash + Clone, V: Clone> Memoize<K, V> {
    pub fn new() -> Self {
        Memoize {
            cache: HashMap::new(),
        }
    }

    pub fn call<F>(&mut self, key: K, compute: F) -> V
    where
        F: FnOnce() -> V,
    {
        if let Some(value) = self.cache.get(&key) {
            return value.clone();
        }
        let value = compute();
        self.cache.insert(key, value.clone());
        value
    }

    pub fn get(&self, key: &K) -> Option<&V> {
        self.cache.get(key)
    }

    pub fn contains(&self, key: &K) -> bool {
        self.cache.contains_key(key)
    }

    pub fn invalidate(&mut self, key: &K) -> Option<V> {
        self.cache.remove(key)
    }

    pub fn clear(&mut self) {
        self.cache.clear();
    }

    pub fn len(&self) -> usize {
        self.cache.len()
    }

    pub fn is_empty(&self) -> bool {
        self.cache.is_empty()
    }
}

impl<K: Eq + Hash + Clone, V: Clone> Default for Memoize<K, V> {
    fn default() -> Self {
        Self::new()
    }
}

// Helper function for memoizing recursive functions
pub fn memoize_recursive<K, V, F>(cache: &mut HashMap<K, V>, key: K, compute: F) -> V
where
    K: Eq + Hash + Clone,
    V: Clone,
    F: FnOnce(&mut HashMap<K, V>) -> V,
{
    if let Some(value) = cache.get(&key) {
        return value.clone();
    }
    let value = compute(cache);
    cache.insert(key, value.clone());
    value
}

// Example: Memoized Fibonacci
pub fn fib_memoized(n: u64, cache: &mut HashMap<u64, u64>) -> u64 {
    if n <= 1 {
        return n;
    }
    if let Some(&value) = cache.get(&n) {
        return value;
    }
    let result = fib_memoized(n - 1, cache) + fib_memoized(n - 2, cache);
    cache.insert(n, result);
    result
}

// Example: Memoized factorial
pub fn factorial_memoized(n: u64, cache: &mut HashMap<u64, u64>) -> u64 {
    if n <= 1 {
        return 1;
    }
    if let Some(&value) = cache.get(&n) {
        return value;
    }
    let result = n * factorial_memoized(n - 1, cache);
    cache.insert(n, result);
    result
}

// Multi-argument memoization
pub struct Memoize2<K1, K2, V> {
    cache: HashMap<(K1, K2), V>,
}

impl<K1: Eq + Hash + Clone, K2: Eq + Hash + Clone, V: Clone> Memoize2<K1, K2, V> {
    pub fn new() -> Self {
        Memoize2 {
            cache: HashMap::new(),
        }
    }

    pub fn call<F>(&mut self, key1: K1, key2: K2, compute: F) -> V
    where
        F: FnOnce() -> V,
    {
        let key = (key1, key2);
        if let Some(value) = self.cache.get(&key) {
            return value.clone();
        }
        let value = compute();
        self.cache.insert(key, value.clone());
        value
    }

    pub fn get(&self, key1: &K1, key2: &K2) -> Option<&V> {
        self.cache.get(&(key1.clone(), key2.clone()))
    }

    pub fn len(&self) -> usize {
        self.cache.len()
    }

    pub fn is_empty(&self) -> bool {
        self.cache.is_empty()
    }

    pub fn clear(&mut self) {
        self.cache.clear();
    }
}

impl<K1: Eq + Hash + Clone, K2: Eq + Hash + Clone, V: Clone> Default for Memoize2<K1, K2, V> {
    fn default() -> Self {
        Self::new()
    }
}

// Binomial coefficient with memoization
pub fn binomial(n: u64, k: u64, cache: &mut HashMap<(u64, u64), u64>) -> u64 {
    if k == 0 || k == n {
        return 1;
    }
    let key = (n, k);
    if let Some(&value) = cache.get(&key) {
        return value;
    }
    let result = binomial(n - 1, k - 1, cache) + binomial(n - 1, k, cache);
    cache.insert(key, result);
    result
}
