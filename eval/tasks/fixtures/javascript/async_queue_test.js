const {
  AsyncQueue,
  PriorityAsyncQueue,
  RateLimitedQueue,
  processInBatches,
  processWithRetry,
  timeout
} = require('./async_queue');

describe('AsyncQueue', () => {
  test('processes tasks sequentially with concurrency 1', async () => {
    const queue = new AsyncQueue(1);
    const order = [];

    const p1 = queue.enqueue(async () => {
      await delay(50);
      order.push(1);
      return 1;
    });

    const p2 = queue.enqueue(async () => {
      order.push(2);
      return 2;
    });

    await Promise.all([p1, p2]);
    expect(order).toEqual([1, 2]);
  });

  test('processes tasks concurrently with higher concurrency', async () => {
    const queue = new AsyncQueue(2);
    const results = [];

    const tasks = [1, 2, 3].map(n =>
      queue.enqueue(async () => {
        await delay(10);
        results.push(n);
        return n;
      })
    );

    await Promise.all(tasks);
    expect(results).toHaveLength(3);
  });

  test('handles task errors', async () => {
    const queue = new AsyncQueue(1);

    await expect(
      queue.enqueue(async () => { throw new Error('Task failed'); })
    ).rejects.toThrow('Task failed');
  });

  test('tracks size and pending', async () => {
    const queue = new AsyncQueue(1);

    expect(queue.size).toBe(0);
    expect(queue.pending).toBe(0);

    const p = queue.enqueue(async () => {
      await delay(50);
      return 'done';
    });

    queue.enqueue(async () => 'queued');

    await delay(10);
    expect(queue.pending).toBe(1);
    expect(queue.size).toBe(1);

    await p;
  });

  test('pause and resume', async () => {
    const queue = new AsyncQueue(1);
    const results = [];

    queue.enqueue(async () => {
      results.push(1);
      return 1;
    });

    queue.pause();
    expect(queue.isPaused).toBe(true);

    queue.enqueue(async () => {
      results.push(2);
      return 2;
    });

    await delay(50);
    expect(results.length).toBeLessThanOrEqual(1);

    queue.resume();
    expect(queue.isPaused).toBe(false);

    await delay(50);
    expect(results).toContain(2);
  });

  test('clear removes pending tasks', async () => {
    const queue = new AsyncQueue(1);

    queue.enqueue(async () => {
      await delay(100);
      return 1;
    });

    const p2 = queue.enqueue(async () => 2);
    const p3 = queue.enqueue(async () => 3);

    await delay(10);
    const cleared = queue.clear();

    expect(cleared).toBe(2);
    expect(queue.size).toBe(0);

    await expect(p2).rejects.toThrow('Queue cleared');
    await expect(p3).rejects.toThrow('Queue cleared');
  });
});

describe('PriorityAsyncQueue', () => {
  test('processes higher priority tasks first', async () => {
    const queue = new PriorityAsyncQueue(1);
    const order = [];

    // Start a long task to block the queue
    queue.enqueue(async () => {
      await delay(50);
      order.push('first');
    }, 0);

    // Queue tasks with different priorities
    queue.enqueue(async () => order.push('low'), 1);
    queue.enqueue(async () => order.push('high'), 10);
    queue.enqueue(async () => order.push('medium'), 5);

    await delay(200);

    expect(order).toEqual(['first', 'high', 'medium', 'low']);
  });
});

describe('RateLimitedQueue', () => {
  test('respects rate limit', async () => {
    const queue = new RateLimitedQueue(1, 50);
    const timestamps = [];

    await queue.enqueue(async () => {
      timestamps.push(Date.now());
    });

    await queue.enqueue(async () => {
      timestamps.push(Date.now());
    });

    const diff = timestamps[1] - timestamps[0];
    expect(diff).toBeGreaterThanOrEqual(45); // Allow some tolerance
  });
});

describe('processInBatches', () => {
  test('processes items in batches', async () => {
    const items = [1, 2, 3, 4, 5];
    const batches = [];

    const results = await processInBatches(items, 2, async (item) => {
      batches.push(item);
      return item * 2;
    });

    expect(results).toEqual([2, 4, 6, 8, 10]);
  });

  test('handles empty array', async () => {
    const results = await processInBatches([], 2, async (x) => x);
    expect(results).toEqual([]);
  });
});

describe('processWithRetry', () => {
  test('returns on success', async () => {
    const result = await processWithRetry(async () => 'success');
    expect(result).toBe('success');
  });

  test('retries on failure', async () => {
    let attempts = 0;

    const result = await processWithRetry(async () => {
      attempts++;
      if (attempts < 3) throw new Error('Fail');
      return 'success';
    }, 3, 10);

    expect(result).toBe('success');
    expect(attempts).toBe(3);
  });

  test('throws after max retries', async () => {
    await expect(
      processWithRetry(async () => { throw new Error('Always fails'); }, 2, 10)
    ).rejects.toThrow('Always fails');
  });
});

describe('timeout', () => {
  test('returns result if within timeout', async () => {
    const result = await timeout(
      Promise.resolve('fast'),
      100
    );
    expect(result).toBe('fast');
  });

  test('throws if timeout exceeded', async () => {
    await expect(
      timeout(delay(100).then(() => 'slow'), 10)
    ).rejects.toThrow('Operation timed out');
  });
});

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
