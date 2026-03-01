/**
 * Async Queue Implementation
 * Demonstrates async/await patterns with queue processing
 */

class AsyncQueue {
  constructor(concurrency = 1) {
    this.concurrency = concurrency;
    this.queue = [];
    this.running = 0;
    this.paused = false;
    this.results = [];
  }

  async enqueue(task) {
    return new Promise((resolve, reject) => {
      this.queue.push({ task, resolve, reject });
      this._process();
    });
  }

  async _process() {
    if (this.paused) return;
    if (this.running >= this.concurrency) return;
    if (this.queue.length === 0) return;

    const { task, resolve, reject } = this.queue.shift();
    this.running++;

    try {
      const result = await task();
      this.results.push({ success: true, value: result });
      resolve(result);
    } catch (error) {
      this.results.push({ success: false, error });
      reject(error);
    } finally {
      this.running--;
      this._process();
    }
  }

  pause() {
    this.paused = true;
  }

  resume() {
    this.paused = false;
    // Start processing queued items
    for (let i = 0; i < this.concurrency; i++) {
      this._process();
    }
  }

  clear() {
    const cleared = this.queue.length;
    this.queue.forEach(({ reject }) => reject(new Error('Queue cleared')));
    this.queue = [];
    return cleared;
  }

  get size() {
    return this.queue.length;
  }

  get pending() {
    return this.running;
  }

  get isPaused() {
    return this.paused;
  }
}

class PriorityAsyncQueue extends AsyncQueue {
  constructor(concurrency = 1) {
    super(concurrency);
  }

  async enqueue(task, priority = 0) {
    return new Promise((resolve, reject) => {
      const item = { task, resolve, reject, priority };

      // Insert in priority order (higher priority first)
      const index = this.queue.findIndex(q => q.priority < priority);
      if (index === -1) {
        this.queue.push(item);
      } else {
        this.queue.splice(index, 0, item);
      }

      this._process();
    });
  }
}

class RateLimitedQueue extends AsyncQueue {
  constructor(concurrency = 1, rateLimit = 1000) {
    super(concurrency);
    this.rateLimit = rateLimit;
    this.lastRun = 0;
  }

  async _process() {
    if (this.paused) return;
    if (this.running >= this.concurrency) return;
    if (this.queue.length === 0) return;

    const now = Date.now();
    const timeSinceLastRun = now - this.lastRun;

    if (timeSinceLastRun < this.rateLimit) {
      setTimeout(() => this._process(), this.rateLimit - timeSinceLastRun);
      return;
    }

    const { task, resolve, reject } = this.queue.shift();
    this.running++;
    this.lastRun = Date.now();

    try {
      const result = await task();
      this.results.push({ success: true, value: result });
      resolve(result);
    } catch (error) {
      this.results.push({ success: false, error });
      reject(error);
    } finally {
      this.running--;
      this._process();
    }
  }
}

async function processInBatches(items, batchSize, processor) {
  const results = [];

  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchResults = await Promise.all(batch.map(processor));
    results.push(...batchResults);
  }

  return results;
}

async function processWithRetry(task, maxRetries = 3, delay = 1000) {
  let lastError;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await task();
    } catch (error) {
      lastError = error;
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, delay * Math.pow(2, attempt)));
      }
    }
  }

  throw lastError;
}

async function timeout(promise, ms) {
  let timeoutId;

  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => reject(new Error('Operation timed out')), ms);
  });

  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    clearTimeout(timeoutId);
  }
}

module.exports = {
  AsyncQueue,
  PriorityAsyncQueue,
  RateLimitedQueue,
  processInBatches,
  processWithRetry,
  timeout
};
