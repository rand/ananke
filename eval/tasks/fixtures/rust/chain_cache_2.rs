//! LRU Cache Implementation (Chain Cache 2)
//! Demonstrates Least Recently Used cache eviction policy

use std::collections::HashMap;
use std::hash::Hash;

#[derive(Debug)]
struct Node<K, V> {
    key: K,
    value: V,
    prev: Option<usize>,
    next: Option<usize>,
}

pub struct LruCache<K, V> {
    capacity: usize,
    map: HashMap<K, usize>,
    nodes: Vec<Option<Node<K, V>>>,
    head: Option<usize>,
    tail: Option<usize>,
    free_list: Vec<usize>,
}

impl<K: Eq + Hash + Clone, V: Clone> LruCache<K, V> {
    pub fn new(capacity: usize) -> Self {
        assert!(capacity > 0, "Capacity must be greater than 0");
        LruCache {
            capacity,
            map: HashMap::new(),
            nodes: Vec::new(),
            head: None,
            tail: None,
            free_list: Vec::new(),
        }
    }

    pub fn capacity(&self) -> usize {
        self.capacity
    }

    pub fn len(&self) -> usize {
        self.map.len()
    }

    pub fn is_empty(&self) -> bool {
        self.map.is_empty()
    }

    pub fn get(&mut self, key: &K) -> Option<&V> {
        if let Some(&idx) = self.map.get(key) {
            self.move_to_front(idx);
            if let Some(ref node) = self.nodes[idx] {
                return Some(&node.value);
            }
        }
        None
    }

    pub fn peek(&self, key: &K) -> Option<&V> {
        if let Some(&idx) = self.map.get(key) {
            if let Some(ref node) = self.nodes[idx] {
                return Some(&node.value);
            }
        }
        None
    }

    pub fn put(&mut self, key: K, value: V) -> Option<V> {
        if let Some(&idx) = self.map.get(&key) {
            // Update existing
            let old_value = self.nodes[idx].as_ref().map(|n| n.value.clone());
            if let Some(ref mut node) = self.nodes[idx] {
                node.value = value;
            }
            self.move_to_front(idx);
            return old_value;
        }

        // Evict if at capacity
        if self.len() >= self.capacity {
            self.evict_lru();
        }

        // Insert new
        let idx = self.allocate_node(key.clone(), value);
        self.map.insert(key, idx);
        self.push_front(idx);
        None
    }

    pub fn remove(&mut self, key: &K) -> Option<V> {
        if let Some(idx) = self.map.remove(key) {
            self.unlink(idx);
            let node = self.nodes[idx].take();
            self.free_list.push(idx);
            return node.map(|n| n.value);
        }
        None
    }

    pub fn contains(&self, key: &K) -> bool {
        self.map.contains_key(key)
    }

    pub fn clear(&mut self) {
        self.map.clear();
        self.nodes.clear();
        self.head = None;
        self.tail = None;
        self.free_list.clear();
    }

    pub fn keys(&self) -> Vec<K> {
        let mut keys = Vec::new();
        let mut current = self.head;
        while let Some(idx) = current {
            if let Some(ref node) = self.nodes[idx] {
                keys.push(node.key.clone());
                current = node.next;
            } else {
                break;
            }
        }
        keys
    }

    fn allocate_node(&mut self, key: K, value: V) -> usize {
        let node = Node {
            key,
            value,
            prev: None,
            next: None,
        };

        if let Some(idx) = self.free_list.pop() {
            self.nodes[idx] = Some(node);
            idx
        } else {
            let idx = self.nodes.len();
            self.nodes.push(Some(node));
            idx
        }
    }

    fn push_front(&mut self, idx: usize) {
        if let Some(ref mut node) = self.nodes[idx] {
            node.prev = None;
            node.next = self.head;
        }

        if let Some(head_idx) = self.head {
            if let Some(ref mut head_node) = self.nodes[head_idx] {
                head_node.prev = Some(idx);
            }
        }

        self.head = Some(idx);

        if self.tail.is_none() {
            self.tail = Some(idx);
        }
    }

    fn unlink(&mut self, idx: usize) {
        let (prev, next) = if let Some(ref node) = self.nodes[idx] {
            (node.prev, node.next)
        } else {
            return;
        };

        if let Some(prev_idx) = prev {
            if let Some(ref mut prev_node) = self.nodes[prev_idx] {
                prev_node.next = next;
            }
        } else {
            self.head = next;
        }

        if let Some(next_idx) = next {
            if let Some(ref mut next_node) = self.nodes[next_idx] {
                next_node.prev = prev;
            }
        } else {
            self.tail = prev;
        }
    }

    fn move_to_front(&mut self, idx: usize) {
        if self.head == Some(idx) {
            return;
        }
        self.unlink(idx);
        self.push_front(idx);
    }

    fn evict_lru(&mut self) {
        if let Some(tail_idx) = self.tail {
            if let Some(ref node) = self.nodes[tail_idx] {
                let key = node.key.clone();
                self.map.remove(&key);
            }
            self.unlink(tail_idx);
            self.nodes[tail_idx] = None;
            self.free_list.push(tail_idx);
        }
    }
}

// LRU cache with TTL support
use std::time::{Duration, Instant};

pub struct TtlLruCache<K, V> {
    cache: LruCache<K, (V, Instant)>,
    ttl: Duration,
}

impl<K: Eq + Hash + Clone, V: Clone> TtlLruCache<K, V> {
    pub fn new(capacity: usize, ttl: Duration) -> Self {
        TtlLruCache {
            cache: LruCache::new(capacity),
            ttl,
        }
    }

    pub fn get(&mut self, key: &K) -> Option<&V> {
        // Check if expired
        if let Some((_, created)) = self.cache.peek(key) {
            if created.elapsed() > self.ttl {
                self.cache.remove(key);
                return None;
            }
        }

        self.cache.get(key).map(|(v, _)| v)
    }

    pub fn put(&mut self, key: K, value: V) {
        self.cache.put(key, (value, Instant::now()));
    }

    pub fn remove(&mut self, key: &K) -> Option<V> {
        self.cache.remove(key).map(|(v, _)| v)
    }

    pub fn len(&self) -> usize {
        self.cache.len()
    }

    pub fn is_empty(&self) -> bool {
        self.cache.is_empty()
    }
}
