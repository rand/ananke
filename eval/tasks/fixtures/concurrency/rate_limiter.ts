class RateLimiter {
  private capacity: number;
  private refillRate: number; // tokens per second
  private availableTokens: number;
  private lastRefillTime: number;

  constructor(capacity: number, refillRate: number) {
    this.capacity = capacity;
    this.refillRate = refillRate;
    this.availableTokens = capacity;
    this.lastRefillTime = Date.now();
  }

  tryAcquire(tokens: number = 1): boolean {
    // Refill tokens based on time elapsed
    this.refill();

    // Check if we have enough tokens
    if (this.availableTokens >= tokens) {
      this.availableTokens -= tokens;
      return true;
    }

    return false;
  }

  private refill(): void {
    const now = Date.now();
    const timeElapsedSeconds = (now - this.lastRefillTime) / 1000;

    // Calculate tokens to add based on elapsed time
    const tokensToAdd = timeElapsedSeconds * this.refillRate;

    // Update available tokens, capped at capacity
    this.availableTokens = Math.min(
      this.capacity,
      this.availableTokens + tokensToAdd
    );

    // Update last refill time
    this.lastRefillTime = now;
  }
}

export { RateLimiter };
