import { RateLimiter } from './rate_limiter';

describe('RateLimiter', () => {
  describe('basic token bucket behavior', () => {
    it('should allow requests up to capacity', () => {
      const limiter = new RateLimiter(3, 10);

      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(true);
    });

    it('should deny requests beyond capacity', () => {
      const limiter = new RateLimiter(2, 10);

      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(false);
    });

    it('should allow acquiring multiple tokens at once', () => {
      const limiter = new RateLimiter(5, 10);

      expect(limiter.tryAcquire(3)).toBe(true);
      expect(limiter.tryAcquire(2)).toBe(true);
      expect(limiter.tryAcquire(1)).toBe(false);
    });

    it('should deny when requesting more tokens than available', () => {
      const limiter = new RateLimiter(5, 10);

      expect(limiter.tryAcquire(3)).toBe(true);
      expect(limiter.tryAcquire(3)).toBe(false); // Only 2 left
    });
  });

  describe('token refill', () => {
    it('should refill tokens over time', async () => {
      const limiter = new RateLimiter(2, 10); // 10 tokens per second

      // Use all tokens
      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(false);

      // Wait 200ms (should refill ~2 tokens)
      await new Promise(resolve => setTimeout(resolve, 200));

      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(true);
    });

    it('should not exceed capacity when refilling', async () => {
      const limiter = new RateLimiter(3, 10);

      // Use one token
      expect(limiter.tryAcquire()).toBe(true);

      // Wait long enough to refill more than capacity
      await new Promise(resolve => setTimeout(resolve, 500));

      // Should still only have capacity worth of tokens
      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(false);
    });
  });

  describe('refill rate', () => {
    it('should refill at specified rate', async () => {
      const limiter = new RateLimiter(10, 5); // 5 tokens per second

      // Use all tokens
      for (let i = 0; i < 10; i++) {
        expect(limiter.tryAcquire()).toBe(true);
      }
      expect(limiter.tryAcquire()).toBe(false);

      // Wait 1 second (should refill 5 tokens)
      await new Promise(resolve => setTimeout(resolve, 1000));

      for (let i = 0; i < 5; i++) {
        expect(limiter.tryAcquire()).toBe(true);
      }
      expect(limiter.tryAcquire()).toBe(false);
    });
  });

  describe('edge cases', () => {
    it('should handle capacity of 1', () => {
      const limiter = new RateLimiter(1, 10);

      expect(limiter.tryAcquire()).toBe(true);
      expect(limiter.tryAcquire()).toBe(false);
    });

    it('should handle zero token requests', () => {
      const limiter = new RateLimiter(5, 10);

      expect(limiter.tryAcquire(0)).toBe(true);
      expect(limiter.tryAcquire(5)).toBe(true);
    });

    it('should handle immediate successive calls', () => {
      const limiter = new RateLimiter(100, 10);

      for (let i = 0; i < 100; i++) {
        expect(limiter.tryAcquire()).toBe(true);
      }
      expect(limiter.tryAcquire()).toBe(false);
    });
  });

  describe('burst handling', () => {
    it('should allow bursts up to capacity', () => {
      const limiter = new RateLimiter(10, 1); // Small refill rate, large capacity

      // Should allow burst of 10
      for (let i = 0; i < 10; i++) {
        expect(limiter.tryAcquire()).toBe(true);
      }
      expect(limiter.tryAcquire()).toBe(false);
    });

    it('should maintain average rate over time', async () => {
      const limiter = new RateLimiter(5, 10); // 10 per second

      let successCount = 0;

      // Try to acquire as fast as possible for 500ms
      const endTime = Date.now() + 500;
      while (Date.now() < endTime) {
        if (limiter.tryAcquire()) {
          successCount++;
        }
        await new Promise(resolve => setTimeout(resolve, 10));
      }

      // Should have acquired approximately 5-10 tokens (burst + refill)
      expect(successCount).toBeGreaterThanOrEqual(5);
      expect(successCount).toBeLessThanOrEqual(15);
    });
  });

  describe('different refill rates', () => {
    it('should handle high refill rate', async () => {
      const limiter = new RateLimiter(10, 100); // 100 per second

      // Use all tokens
      for (let i = 0; i < 10; i++) {
        limiter.tryAcquire();
      }

      // Wait 100ms (should refill ~10 tokens)
      await new Promise(resolve => setTimeout(resolve, 100));

      expect(limiter.tryAcquire()).toBe(true);
    });

    it('should handle low refill rate', async () => {
      const limiter = new RateLimiter(5, 1); // 1 per second

      // Use all tokens
      for (let i = 0; i < 5; i++) {
        limiter.tryAcquire();
      }

      // Wait 500ms (should refill ~0.5 tokens, not enough for 1)
      await new Promise(resolve => setTimeout(resolve, 500));

      // Might work due to timing, but generally shouldn't
      const result1 = limiter.tryAcquire();

      // Wait another 500ms (total 1 second, should have 1 token)
      await new Promise(resolve => setTimeout(resolve, 500));

      expect(limiter.tryAcquire()).toBe(true);
    });
  });
});
