/**
 * Debounce and Throttle Implementation
 * Demonstrates function rate limiting patterns
 */

function debounce(fn, wait, options = {}) {
  const { leading = false, trailing = true, maxWait } = options;
  let timeoutId = null;
  let lastCallTime = null;
  let lastInvokeTime = 0;
  let result;
  let lastArgs;
  let lastThis;

  function invokeFunc(time) {
    const args = lastArgs;
    const thisArg = lastThis;
    lastArgs = lastThis = undefined;
    lastInvokeTime = time;
    result = fn.apply(thisArg, args);
    return result;
  }

  function shouldInvoke(time) {
    const timeSinceLastCall = lastCallTime === null ? 0 : time - lastCallTime;
    const timeSinceLastInvoke = time - lastInvokeTime;

    return (
      lastCallTime === null ||
      timeSinceLastCall >= wait ||
      timeSinceLastCall < 0 ||
      (maxWait !== undefined && timeSinceLastInvoke >= maxWait)
    );
  }

  function trailingEdge(time) {
    timeoutId = null;
    if (trailing && lastArgs) {
      return invokeFunc(time);
    }
    lastArgs = lastThis = undefined;
    return result;
  }

  function leadingEdge(time) {
    lastInvokeTime = time;
    timeoutId = setTimeout(() => trailingEdge(Date.now()), wait);
    return leading ? invokeFunc(time) : result;
  }

  function remainingWait(time) {
    const timeSinceLastCall = time - lastCallTime;
    const timeSinceLastInvoke = time - lastInvokeTime;
    const timeWaiting = wait - timeSinceLastCall;

    return maxWait !== undefined
      ? Math.min(timeWaiting, maxWait - timeSinceLastInvoke)
      : timeWaiting;
  }

  function timerExpired() {
    const time = Date.now();
    if (shouldInvoke(time)) {
      return trailingEdge(time);
    }
    timeoutId = setTimeout(timerExpired, remainingWait(time));
  }

  function debounced(...args) {
    const time = Date.now();
    const isInvoking = shouldInvoke(time);

    lastArgs = args;
    lastThis = this;
    lastCallTime = time;

    if (isInvoking) {
      if (timeoutId === null) {
        return leadingEdge(time);
      }
      if (maxWait !== undefined) {
        timeoutId = setTimeout(timerExpired, wait);
        return invokeFunc(time);
      }
    }

    if (timeoutId === null) {
      timeoutId = setTimeout(timerExpired, wait);
    }

    return result;
  }

  debounced.cancel = function() {
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
    }
    lastInvokeTime = 0;
    lastArgs = lastCallTime = lastThis = timeoutId = null;
  };

  debounced.flush = function() {
    if (timeoutId === null) {
      return result;
    }
    return trailingEdge(Date.now());
  };

  debounced.pending = function() {
    return timeoutId !== null;
  };

  return debounced;
}

function throttle(fn, wait, options = {}) {
  const { leading = true, trailing = true } = options;
  return debounce(fn, wait, {
    leading,
    trailing,
    maxWait: wait
  });
}

function rafThrottle(fn) {
  let rafId = null;
  let lastArgs = null;

  function throttled(...args) {
    lastArgs = args;

    if (rafId === null) {
      rafId = requestAnimationFrame(() => {
        fn.apply(this, lastArgs);
        rafId = null;
      });
    }
  }

  throttled.cancel = function() {
    if (rafId !== null) {
      cancelAnimationFrame(rafId);
      rafId = null;
    }
  };

  return throttled;
}

function debounceAsync(fn, wait) {
  let timeoutId = null;
  let pendingPromise = null;
  let resolve = null;
  let reject = null;

  return function(...args) {
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
    }

    if (pendingPromise === null) {
      pendingPromise = new Promise((res, rej) => {
        resolve = res;
        reject = rej;
      });
    }

    timeoutId = setTimeout(async () => {
      try {
        const result = await fn.apply(this, args);
        resolve(result);
      } catch (error) {
        reject(error);
      } finally {
        pendingPromise = null;
        timeoutId = null;
      }
    }, wait);

    return pendingPromise;
  };
}

function throttleAsync(fn, wait) {
  let lastCallTime = 0;
  let pendingPromise = null;

  return async function(...args) {
    const now = Date.now();
    const remaining = wait - (now - lastCallTime);

    if (remaining <= 0) {
      lastCallTime = now;
      return fn.apply(this, args);
    }

    if (pendingPromise === null) {
      pendingPromise = new Promise((resolve) => {
        setTimeout(async () => {
          lastCallTime = Date.now();
          pendingPromise = null;
          resolve(fn.apply(this, args));
        }, remaining);
      });
    }

    return pendingPromise;
  };
}

function once(fn) {
  let called = false;
  let result;

  return function(...args) {
    if (!called) {
      called = true;
      result = fn.apply(this, args);
    }
    return result;
  };
}

function memoize(fn, resolver) {
  const cache = new Map();

  function memoized(...args) {
    const key = resolver ? resolver.apply(this, args) : args[0];

    if (cache.has(key)) {
      return cache.get(key);
    }

    const result = fn.apply(this, args);
    cache.set(key, result);
    return result;
  }

  memoized.cache = cache;
  return memoized;
}

module.exports = {
  debounce,
  throttle,
  rafThrottle,
  debounceAsync,
  throttleAsync,
  once,
  memoize
};
