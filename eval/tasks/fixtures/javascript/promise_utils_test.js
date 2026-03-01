const {
  promiseAll,
  promiseRace,
  promiseAllSettled,
  promiseAny,
  delay,
  timeout,
  retry,
  promiseMap,
  promiseFilter,
  promiseReduce,
  deferred,
  promisify,
  callbackify,
  sequence,
  parallel
} = require('./promise_utils');

describe('promiseAll', () => {
  test('resolves with all values', async () => {
    const result = await promiseAll([
      Promise.resolve(1),
      Promise.resolve(2),
      Promise.resolve(3)
    ]);
    expect(result).toEqual([1, 2, 3]);
  });

  test('rejects if any promise rejects', async () => {
    await expect(
      promiseAll([
        Promise.resolve(1),
        Promise.reject(new Error('fail')),
        Promise.resolve(3)
      ])
    ).rejects.toThrow('fail');
  });

  test('handles empty array', async () => {
    const result = await promiseAll([]);
    expect(result).toEqual([]);
  });

  test('handles non-promise values', async () => {
    const result = await promiseAll([1, 2, 3]);
    expect(result).toEqual([1, 2, 3]);
  });
});

describe('promiseRace', () => {
  test('resolves with first resolved value', async () => {
    const result = await promiseRace([
      delay(50, 'slow'),
      delay(10, 'fast')
    ]);
    expect(result).toBe('fast');
  });

  test('rejects with first rejection', async () => {
    await expect(
      promiseRace([
        delay(50, 'slow'),
        delay(10).then(() => { throw new Error('fail'); })
      ])
    ).rejects.toThrow('fail');
  });
});

describe('promiseAllSettled', () => {
  test('returns all results', async () => {
    const results = await promiseAllSettled([
      Promise.resolve(1),
      Promise.reject(new Error('fail')),
      Promise.resolve(3)
    ]);

    expect(results[0]).toEqual({ status: 'fulfilled', value: 1 });
    expect(results[1].status).toBe('rejected');
    expect(results[1].reason.message).toBe('fail');
    expect(results[2]).toEqual({ status: 'fulfilled', value: 3 });
  });

  test('handles empty array', async () => {
    const results = await promiseAllSettled([]);
    expect(results).toEqual([]);
  });
});

describe('promiseAny', () => {
  test('resolves with first fulfilled value', async () => {
    const result = await promiseAny([
      Promise.reject(new Error('fail1')),
      Promise.resolve('success'),
      Promise.reject(new Error('fail2'))
    ]);
    expect(result).toBe('success');
  });

  test('rejects with AggregateError if all reject', async () => {
    await expect(
      promiseAny([
        Promise.reject(new Error('fail1')),
        Promise.reject(new Error('fail2'))
      ])
    ).rejects.toThrow(AggregateError);
  });

  test('rejects with empty array', async () => {
    await expect(promiseAny([])).rejects.toThrow(AggregateError);
  });
});

describe('delay', () => {
  test('resolves after specified time', async () => {
    const start = Date.now();
    await delay(50);
    const elapsed = Date.now() - start;
    expect(elapsed).toBeGreaterThanOrEqual(45);
  });

  test('resolves with value', async () => {
    const result = await delay(10, 'value');
    expect(result).toBe('value');
  });
});

describe('timeout', () => {
  test('resolves if within timeout', async () => {
    const result = await timeout(delay(10, 'success'), 100);
    expect(result).toBe('success');
  });

  test('rejects if timeout exceeded', async () => {
    await expect(timeout(delay(100), 10)).rejects.toThrow('Operation timed out');
  });

  test('uses custom error message', async () => {
    await expect(timeout(delay(100), 10, 'Custom timeout')).rejects.toThrow('Custom timeout');
  });
});

describe('retry', () => {
  test('resolves on success', async () => {
    const result = await retry(() => Promise.resolve('success'));
    expect(result).toBe('success');
  });

  test('retries on failure', async () => {
    let attempts = 0;
    const result = await retry(
      () => {
        attempts++;
        if (attempts < 3) throw new Error('fail');
        return 'success';
      },
      { retries: 3, delay: 10 }
    );
    expect(result).toBe('success');
    expect(attempts).toBe(3);
  });

  test('rejects after max retries', async () => {
    await expect(
      retry(() => Promise.reject(new Error('always fails')), { retries: 2, delay: 10 })
    ).rejects.toThrow('always fails');
  });
});

describe('promiseMap', () => {
  test('maps over items', async () => {
    const results = await promiseMap([1, 2, 3], x => Promise.resolve(x * 2));
    expect(results).toEqual([2, 4, 6]);
  });

  test('respects concurrency', async () => {
    let concurrent = 0;
    let maxConcurrent = 0;

    await promiseMap(
      [1, 2, 3, 4],
      async x => {
        concurrent++;
        maxConcurrent = Math.max(maxConcurrent, concurrent);
        await delay(20);
        concurrent--;
        return x;
      },
      { concurrency: 2 }
    );

    expect(maxConcurrent).toBeLessThanOrEqual(2);
  });

  test('handles empty array', async () => {
    const results = await promiseMap([], x => x);
    expect(results).toEqual([]);
  });
});

describe('promiseFilter', () => {
  test('filters items', async () => {
    const results = await promiseFilter([1, 2, 3, 4], x => Promise.resolve(x % 2 === 0));
    expect(results).toEqual([2, 4]);
  });
});

describe('promiseReduce', () => {
  test('reduces items', async () => {
    const result = await promiseReduce(
      [1, 2, 3],
      (acc, x) => Promise.resolve(acc + x),
      0
    );
    expect(result).toBe(6);
  });
});

describe('deferred', () => {
  test('creates deferred promise', async () => {
    const d = deferred();
    setTimeout(() => d.resolve('value'), 10);
    const result = await d.promise;
    expect(result).toBe('value');
  });

  test('can be rejected', async () => {
    const d = deferred();
    setTimeout(() => d.reject(new Error('fail')), 10);
    await expect(d.promise).rejects.toThrow('fail');
  });
});

describe('promisify', () => {
  test('converts callback to promise', async () => {
    const callbackFn = (x, callback) => {
      setTimeout(() => callback(null, x * 2), 10);
    };

    const promiseFn = promisify(callbackFn);
    const result = await promiseFn(5);
    expect(result).toBe(10);
  });

  test('rejects on error', async () => {
    const callbackFn = (x, callback) => {
      callback(new Error('fail'));
    };

    const promiseFn = promisify(callbackFn);
    await expect(promiseFn(5)).rejects.toThrow('fail');
  });
});

describe('callbackify', () => {
  test('converts promise to callback', done => {
    const promiseFn = x => Promise.resolve(x * 2);
    const callbackFn = callbackify(promiseFn);

    callbackFn(5, (err, result) => {
      expect(err).toBeNull();
      expect(result).toBe(10);
      done();
    });
  });

  test('passes error to callback', done => {
    const promiseFn = () => Promise.reject(new Error('fail'));
    const callbackFn = callbackify(promiseFn);

    callbackFn((err) => {
      expect(err.message).toBe('fail');
      done();
    });
  });
});

describe('sequence', () => {
  test('runs functions in sequence', async () => {
    const order = [];
    await sequence([
      () => { order.push(1); return Promise.resolve(); },
      () => { order.push(2); return Promise.resolve(); },
      () => { order.push(3); return Promise.resolve(); }
    ]);
    expect(order).toEqual([1, 2, 3]);
  });
});

describe('parallel', () => {
  test('runs functions in parallel', async () => {
    const results = await parallel([
      () => Promise.resolve(1),
      () => Promise.resolve(2),
      () => Promise.resolve(3)
    ]);
    expect(results).toEqual([1, 2, 3]);
  });
});
