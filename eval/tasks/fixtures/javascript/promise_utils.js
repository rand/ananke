/**
 * Promise Utilities Implementation
 * Demonstrates advanced Promise patterns
 */

function promiseAll(promises) {
  return new Promise((resolve, reject) => {
    if (!Array.isArray(promises)) {
      return reject(new TypeError('Argument must be an array'));
    }

    if (promises.length === 0) {
      return resolve([]);
    }

    const results = new Array(promises.length);
    let completed = 0;

    promises.forEach((promise, index) => {
      Promise.resolve(promise)
        .then(value => {
          results[index] = value;
          completed++;
          if (completed === promises.length) {
            resolve(results);
          }
        })
        .catch(reject);
    });
  });
}

function promiseRace(promises) {
  return new Promise((resolve, reject) => {
    if (!Array.isArray(promises)) {
      return reject(new TypeError('Argument must be an array'));
    }

    if (promises.length === 0) {
      // Race with empty array never settles
      return;
    }

    for (const promise of promises) {
      Promise.resolve(promise).then(resolve, reject);
    }
  });
}

function promiseAllSettled(promises) {
  return new Promise((resolve, reject) => {
    if (!Array.isArray(promises)) {
      return reject(new TypeError('Argument must be an array'));
    }

    if (promises.length === 0) {
      return resolve([]);
    }

    const results = new Array(promises.length);
    let completed = 0;

    promises.forEach((promise, index) => {
      Promise.resolve(promise)
        .then(value => {
          results[index] = { status: 'fulfilled', value };
        })
        .catch(reason => {
          results[index] = { status: 'rejected', reason };
        })
        .finally(() => {
          completed++;
          if (completed === promises.length) {
            resolve(results);
          }
        });
    });
  });
}

function promiseAny(promises) {
  return new Promise((resolve, reject) => {
    if (!Array.isArray(promises)) {
      return reject(new TypeError('Argument must be an array'));
    }

    if (promises.length === 0) {
      return reject(new AggregateError([], 'All promises were rejected'));
    }

    const errors = new Array(promises.length);
    let rejected = 0;

    promises.forEach((promise, index) => {
      Promise.resolve(promise)
        .then(resolve)
        .catch(error => {
          errors[index] = error;
          rejected++;
          if (rejected === promises.length) {
            reject(new AggregateError(errors, 'All promises were rejected'));
          }
        });
    });
  });
}

function delay(ms, value) {
  return new Promise(resolve => setTimeout(() => resolve(value), ms));
}

function timeout(promise, ms, errorMessage = 'Operation timed out') {
  return Promise.race([
    promise,
    delay(ms).then(() => {
      throw new Error(errorMessage);
    })
  ]);
}

function retry(fn, options = {}) {
  const { retries = 3, delay: delayMs = 1000, backoff = 1 } = options;

  return new Promise((resolve, reject) => {
    let attempt = 0;

    function tryOnce() {
      let result;
      try {
        result = fn();
      } catch (error) {
        handleError(error);
        return;
      }

      Promise.resolve(result)
        .then(resolve)
        .catch(handleError);
    }

    function handleError(error) {
      attempt++;
      if (attempt > retries) {
        reject(error);
      } else {
        const waitTime = delayMs * Math.pow(backoff, attempt - 1);
        setTimeout(tryOnce, waitTime);
      }
    }

    tryOnce();
  });
}

function promiseMap(items, mapper, options = {}) {
  const { concurrency = Infinity } = options;

  return new Promise((resolve, reject) => {
    const results = new Array(items.length);
    let running = 0;
    let nextIndex = 0;
    let completed = 0;
    let hasError = false;

    function runNext() {
      if (hasError || nextIndex >= items.length) return;

      const index = nextIndex++;
      running++;

      Promise.resolve(mapper(items[index], index))
        .then(result => {
          if (hasError) return;
          results[index] = result;
          completed++;
          running--;

          if (completed === items.length) {
            resolve(results);
          } else {
            runNext();
          }
        })
        .catch(error => {
          if (hasError) return;
          hasError = true;
          reject(error);
        });
    }

    const initialCount = Math.min(concurrency, items.length);
    for (let i = 0; i < initialCount; i++) {
      runNext();
    }

    if (items.length === 0) {
      resolve([]);
    }
  });
}

function promiseFilter(items, predicate, options = {}) {
  return promiseMap(
    items,
    async (item, index) => {
      const keep = await predicate(item, index);
      return { item, keep };
    },
    options
  ).then(results => results.filter(r => r.keep).map(r => r.item));
}

function promiseReduce(items, reducer, initialValue) {
  return items.reduce(
    (acc, item, index) => acc.then(result => reducer(result, item, index)),
    Promise.resolve(initialValue)
  );
}

function deferred() {
  let resolve, reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

function promisify(fn) {
  return function(...args) {
    return new Promise((resolve, reject) => {
      fn(...args, (error, result) => {
        if (error) {
          reject(error);
        } else {
          resolve(result);
        }
      });
    });
  };
}

function callbackify(fn) {
  return function(...args) {
    const callback = args.pop();
    Promise.resolve(fn(...args))
      .then(result => callback(null, result))
      .catch(error => callback(error));
  };
}

function sequence(fns) {
  return fns.reduce(
    (promise, fn) => promise.then(fn),
    Promise.resolve()
  );
}

function parallel(fns) {
  return Promise.all(fns.map(fn => fn()));
}

module.exports = {
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
};
