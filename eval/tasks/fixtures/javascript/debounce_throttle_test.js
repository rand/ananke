const { debounce, throttle, debounceAsync, throttleAsync, once, memoize } = require('./debounce_throttle');

describe('debounce', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('delays execution', () => {
    const fn = jest.fn();
    const debounced = debounce(fn, 100);

    debounced();
    expect(fn).not.toHaveBeenCalled();

    jest.advanceTimersByTime(100);
    expect(fn).toHaveBeenCalledTimes(1);
  });

  test('only calls once for rapid calls', () => {
    const fn = jest.fn();
    const debounced = debounce(fn, 100);

    debounced(1);
    debounced(2);
    debounced(3);

    jest.advanceTimersByTime(100);
    expect(fn).toHaveBeenCalledTimes(1);
    expect(fn).toHaveBeenCalledWith(3);
  });

  test('leading option', () => {
    const fn = jest.fn();
    const debounced = debounce(fn, 100, { leading: true, trailing: false });

    debounced(1);
    expect(fn).toHaveBeenCalledWith(1);

    debounced(2);
    debounced(3);
    jest.advanceTimersByTime(100);

    expect(fn).toHaveBeenCalledTimes(1);
  });

  test('cancel stops pending execution', () => {
    const fn = jest.fn();
    const debounced = debounce(fn, 100);

    debounced();
    debounced.cancel();

    jest.advanceTimersByTime(100);
    expect(fn).not.toHaveBeenCalled();
  });

  test('flush triggers immediately', () => {
    const fn = jest.fn().mockReturnValue('result');
    const debounced = debounce(fn, 100);

    debounced();
    const result = debounced.flush();

    expect(fn).toHaveBeenCalledTimes(1);
    expect(result).toBe('result');
  });

  test('pending returns true when waiting', () => {
    const fn = jest.fn();
    const debounced = debounce(fn, 100);

    expect(debounced.pending()).toBe(false);
    debounced();
    expect(debounced.pending()).toBe(true);

    jest.advanceTimersByTime(100);
    expect(debounced.pending()).toBe(false);
  });

  test('maxWait option', () => {
    const fn = jest.fn();
    const debounced = debounce(fn, 100, { maxWait: 150 });

    debounced();
    jest.advanceTimersByTime(50);
    debounced();
    jest.advanceTimersByTime(50);
    debounced();
    jest.advanceTimersByTime(50);

    expect(fn).toHaveBeenCalledTimes(1);
  });
});

describe('throttle', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('calls immediately with leading: true', () => {
    const fn = jest.fn();
    const throttled = throttle(fn, 100);

    throttled();
    expect(fn).toHaveBeenCalledTimes(1);
  });

  test('limits calls to once per wait period', () => {
    const fn = jest.fn();
    const throttled = throttle(fn, 100);

    throttled(1);
    throttled(2);
    throttled(3);

    expect(fn).toHaveBeenCalledTimes(1);

    jest.advanceTimersByTime(100);
    expect(fn).toHaveBeenCalledTimes(2);
  });

  test('trailing: false skips trailing call', () => {
    const fn = jest.fn();
    const throttled = throttle(fn, 100, { trailing: false });

    throttled(1);
    throttled(2);

    jest.advanceTimersByTime(100);
    expect(fn).toHaveBeenCalledTimes(1);
    expect(fn).toHaveBeenCalledWith(1);
  });
});

describe('debounceAsync', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('returns promise that resolves after wait', async () => {
    const fn = jest.fn().mockResolvedValue('result');
    const debounced = debounceAsync(fn, 100);

    const promise = debounced();
    jest.advanceTimersByTime(100);

    await expect(promise).resolves.toBe('result');
  });

  test('multiple calls share same promise', async () => {
    const fn = jest.fn().mockResolvedValue('result');
    const debounced = debounceAsync(fn, 100);

    const p1 = debounced(1);
    const p2 = debounced(2);

    expect(p1).toBe(p2);

    jest.advanceTimersByTime(100);
    await p1;

    expect(fn).toHaveBeenCalledTimes(1);
    expect(fn).toHaveBeenCalledWith(2);
  });
});

describe('throttleAsync', () => {
  test('calls immediately first time', async () => {
    const fn = jest.fn().mockResolvedValue('result');
    const throttled = throttleAsync(fn, 100);

    await throttled();
    expect(fn).toHaveBeenCalledTimes(1);
  });

  test('limits calls over time', async () => {
    jest.useFakeTimers();
    const fn = jest.fn().mockResolvedValue('result');
    const throttled = throttleAsync(fn, 100);

    await throttled(1);
    const p2 = throttled(2);

    jest.advanceTimersByTime(100);
    await p2;

    expect(fn).toHaveBeenCalledTimes(2);
    jest.useRealTimers();
  });
});

describe('once', () => {
  test('calls function only once', () => {
    const fn = jest.fn().mockReturnValue('result');
    const onceFn = once(fn);

    expect(onceFn()).toBe('result');
    expect(onceFn()).toBe('result');
    expect(onceFn()).toBe('result');

    expect(fn).toHaveBeenCalledTimes(1);
  });

  test('preserves arguments from first call', () => {
    const fn = jest.fn((x) => x * 2);
    const onceFn = once(fn);

    expect(onceFn(5)).toBe(10);
    expect(onceFn(10)).toBe(10); // Still returns first result
  });
});

describe('memoize', () => {
  test('caches results', () => {
    const fn = jest.fn((x) => x * 2);
    const memoized = memoize(fn);

    expect(memoized(5)).toBe(10);
    expect(memoized(5)).toBe(10);
    expect(fn).toHaveBeenCalledTimes(1);

    expect(memoized(10)).toBe(20);
    expect(fn).toHaveBeenCalledTimes(2);
  });

  test('custom resolver', () => {
    const fn = jest.fn((a, b) => a + b);
    const memoized = memoize(fn, (a, b) => `${a}-${b}`);

    expect(memoized(1, 2)).toBe(3);
    expect(memoized(1, 2)).toBe(3);
    expect(fn).toHaveBeenCalledTimes(1);

    expect(memoized(2, 1)).toBe(3);
    expect(fn).toHaveBeenCalledTimes(2);
  });

  test('cache is accessible', () => {
    const fn = jest.fn((x) => x * 2);
    const memoized = memoize(fn);

    memoized(5);
    expect(memoized.cache.has(5)).toBe(true);
    expect(memoized.cache.get(5)).toBe(10);
  });
});
