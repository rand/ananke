import { LRUCache } from './lru_cache';

describe('LRUCache', () => {
  describe('basic operations', () => {
    it('should store and retrieve a single value', () => {
      const cache = new LRUCache(2);

      cache.put(1, 100);
      expect(cache.get(1)).toBe(100);
    });

    it('should return null for non-existent key', () => {
      const cache = new LRUCache(2);

      expect(cache.get(1)).toBeNull();
    });

    it('should update existing key value', () => {
      const cache = new LRUCache(2);

      cache.put(1, 100);
      cache.put(1, 200);

      expect(cache.get(1)).toBe(200);
    });

    it('should handle capacity of 1', () => {
      const cache = new LRUCache(1);

      cache.put(1, 100);
      expect(cache.get(1)).toBe(100);

      cache.put(2, 200);
      expect(cache.get(2)).toBe(200);
      expect(cache.get(1)).toBeNull(); // evicted
    });
  });

  describe('eviction policy', () => {
    it('should evict least recently used item when capacity is exceeded', () => {
      const cache = new LRUCache(2);

      cache.put(1, 100);
      cache.put(2, 200);
      cache.put(3, 300); // Should evict key 1

      expect(cache.get(1)).toBeNull();
      expect(cache.get(2)).toBe(200);
      expect(cache.get(3)).toBe(300);
    });

    it('should not evict when updating existing key', () => {
      const cache = new LRUCache(2);

      cache.put(1, 100);
      cache.put(2, 200);
      cache.put(1, 150); // Update, not new insertion

      expect(cache.get(1)).toBe(150);
      expect(cache.get(2)).toBe(200);
    });

    it('should evict correctly with multiple operations', () => {
      const cache = new LRUCache(3);

      cache.put(1, 100);
      cache.put(2, 200);
      cache.put(3, 300);
      cache.put(4, 400); // Evict 1

      expect(cache.get(1)).toBeNull();
      expect(cache.get(2)).toBe(200);
      expect(cache.get(3)).toBe(300);
      expect(cache.get(4)).toBe(400);
    });
  });

  describe('recently used tracking', () => {
    it('should mark accessed key as recently used', () => {
      const cache = new LRUCache(2);

      cache.put(1, 100);
      cache.put(2, 200);
      cache.get(1); // Make 1 recently used
      cache.put(3, 300); // Should evict 2, not 1

      expect(cache.get(1)).toBe(100);
      expect(cache.get(2)).toBeNull();
      expect(cache.get(3)).toBe(300);
    });

    it('should mark updated key as recently used', () => {
      const cache = new LRUCache(2);

      cache.put(1, 100);
      cache.put(2, 200);
      cache.put(1, 150); // Update makes 1 recently used
      cache.put(3, 300); // Should evict 2

      expect(cache.get(1)).toBe(150);
      expect(cache.get(2)).toBeNull();
      expect(cache.get(3)).toBe(300);
    });

    it('should handle complex access patterns', () => {
      const cache = new LRUCache(3);

      cache.put(1, 100);
      cache.put(2, 200);
      cache.put(3, 300);

      cache.get(1); // Access order: 2, 3, 1
      cache.get(2); // Access order: 3, 1, 2

      cache.put(4, 400); // Should evict 3

      expect(cache.get(3)).toBeNull();
      expect(cache.get(1)).toBe(100);
      expect(cache.get(2)).toBe(200);
      expect(cache.get(4)).toBe(400);
    });
  });

  describe('larger capacity', () => {
    it('should handle capacity of 10', () => {
      const cache = new LRUCache(10);

      for (let i = 1; i <= 10; i++) {
        cache.put(i, i * 100);
      }

      for (let i = 1; i <= 10; i++) {
        expect(cache.get(i)).toBe(i * 100);
      }

      cache.put(11, 1100); // Should evict 1

      expect(cache.get(1)).toBeNull();
      expect(cache.get(11)).toBe(1100);
    });

    it('should maintain correct eviction order with many operations', () => {
      const cache = new LRUCache(5);

      // Fill cache
      cache.put(1, 100);
      cache.put(2, 200);
      cache.put(3, 300);
      cache.put(4, 400);
      cache.put(5, 500);

      // Access some keys
      cache.get(1);
      cache.get(3);
      cache.get(5);

      // Add two more (should evict 2 and 4)
      cache.put(6, 600);
      cache.put(7, 700);

      expect(cache.get(2)).toBeNull();
      expect(cache.get(4)).toBeNull();
      expect(cache.get(1)).toBe(100);
      expect(cache.get(3)).toBe(300);
      expect(cache.get(5)).toBe(500);
      expect(cache.get(6)).toBe(600);
      expect(cache.get(7)).toBe(700);
    });
  });

  describe('edge cases', () => {
    it('should handle repeated get on same key', () => {
      const cache = new LRUCache(2);

      cache.put(1, 100);
      expect(cache.get(1)).toBe(100);
      expect(cache.get(1)).toBe(100);
      expect(cache.get(1)).toBe(100);
    });

    it('should handle repeated put on same key', () => {
      const cache = new LRUCache(2);

      cache.put(1, 100);
      cache.put(1, 200);
      cache.put(1, 300);

      expect(cache.get(1)).toBe(300);
    });

    it('should handle alternating operations', () => {
      const cache = new LRUCache(2);

      cache.put(1, 100);
      expect(cache.get(1)).toBe(100);
      cache.put(2, 200);
      expect(cache.get(2)).toBe(200);
      cache.put(3, 300);
      expect(cache.get(1)).toBeNull();
      expect(cache.get(2)).toBe(200);
      expect(cache.get(3)).toBe(300);
    });

    it('should handle zero and negative keys/values', () => {
      const cache = new LRUCache(3);

      cache.put(0, 0);
      cache.put(-1, -100);
      cache.put(-2, -200);

      expect(cache.get(0)).toBe(0);
      expect(cache.get(-1)).toBe(-100);
      expect(cache.get(-2)).toBe(-200);
    });
  });

  describe('LeetCode test cases', () => {
    it('should pass LeetCode example 1', () => {
      const cache = new LRUCache(2);

      cache.put(1, 1);
      cache.put(2, 2);
      expect(cache.get(1)).toBe(1);
      cache.put(3, 3);
      expect(cache.get(2)).toBeNull();
      cache.put(4, 4);
      expect(cache.get(1)).toBeNull();
      expect(cache.get(3)).toBe(3);
      expect(cache.get(4)).toBe(4);
    });

    it('should pass LeetCode example 2', () => {
      const cache = new LRUCache(2);

      cache.put(2, 1);
      cache.put(1, 1);
      cache.put(2, 3);
      cache.put(4, 1);
      expect(cache.get(1)).toBeNull();
      expect(cache.get(2)).toBe(3);
    });

    it('should pass LeetCode example 3', () => {
      const cache = new LRUCache(2);

      cache.put(2, 1);
      cache.put(3, 2);
      expect(cache.get(3)).toBe(2);
      expect(cache.get(2)).toBe(1);
      cache.put(4, 3);
      expect(cache.get(2)).toBe(1);
      expect(cache.get(3)).toBeNull();
      expect(cache.get(4)).toBe(3);
    });
  });

  describe('performance characteristics', () => {
    it('should handle many operations efficiently', () => {
      const cache = new LRUCache(1000);
      const start = Date.now();

      for (let i = 0; i < 10000; i++) {
        cache.put(i, i * 100);
        if (i % 10 === 0) {
          cache.get(i);
        }
      }

      const duration = Date.now() - start;

      // Should complete quickly (under 100ms)
      expect(duration).toBeLessThan(100);
    });

    it('should maintain O(1) operations', () => {
      const cache = new LRUCache(1000);

      // Warm up
      for (let i = 0; i < 1000; i++) {
        cache.put(i, i);
      }

      // Measure single operations
      const start = Date.now();
      for (let i = 0; i < 1000; i++) {
        cache.get(i % 1000);
        cache.put(i + 1000, i);
      }
      const duration = Date.now() - start;

      // Should be very fast (under 10ms for 2000 operations)
      expect(duration).toBeLessThan(10);
    });
  });
});
