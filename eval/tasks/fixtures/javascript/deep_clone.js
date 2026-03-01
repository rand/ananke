/**
 * Deep Clone Implementation
 * Demonstrates deep copying of JavaScript objects
 */

function deepClone(value, seen = new WeakMap()) {
  // Handle primitives and null
  if (value === null || typeof value !== 'object') {
    return value;
  }

  // Handle circular references
  if (seen.has(value)) {
    return seen.get(value);
  }

  // Handle Date
  if (value instanceof Date) {
    return new Date(value.getTime());
  }

  // Handle RegExp
  if (value instanceof RegExp) {
    return new RegExp(value.source, value.flags);
  }

  // Handle Map
  if (value instanceof Map) {
    const clone = new Map();
    seen.set(value, clone);
    for (const [key, val] of value) {
      clone.set(deepClone(key, seen), deepClone(val, seen));
    }
    return clone;
  }

  // Handle Set
  if (value instanceof Set) {
    const clone = new Set();
    seen.set(value, clone);
    for (const val of value) {
      clone.add(deepClone(val, seen));
    }
    return clone;
  }

  // Handle Array
  if (Array.isArray(value)) {
    const clone = [];
    seen.set(value, clone);
    for (let i = 0; i < value.length; i++) {
      clone[i] = deepClone(value[i], seen);
    }
    return clone;
  }

  // Handle ArrayBuffer
  if (value instanceof ArrayBuffer) {
    return value.slice(0);
  }

  // Handle TypedArrays
  if (ArrayBuffer.isView(value) && !(value instanceof DataView)) {
    return new value.constructor(value);
  }

  // Handle DataView
  if (value instanceof DataView) {
    return new DataView(value.buffer.slice(0), value.byteOffset, value.byteLength);
  }

  // Handle plain objects
  const clone = Object.create(Object.getPrototypeOf(value));
  seen.set(value, clone);

  // Copy symbol properties
  const symbolKeys = Object.getOwnPropertySymbols(value);
  for (const sym of symbolKeys) {
    const descriptor = Object.getOwnPropertyDescriptor(value, sym);
    if (descriptor) {
      if ('value' in descriptor) {
        descriptor.value = deepClone(descriptor.value, seen);
      }
      Object.defineProperty(clone, sym, descriptor);
    }
  }

  // Copy string properties
  for (const key of Object.keys(value)) {
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (descriptor) {
      if ('value' in descriptor) {
        descriptor.value = deepClone(descriptor.value, seen);
      }
      Object.defineProperty(clone, key, descriptor);
    }
  }

  return clone;
}

function deepEqual(a, b, seen = new WeakMap()) {
  // Handle primitives
  if (a === b) return true;
  if (a === null || b === null) return false;
  if (typeof a !== 'object' || typeof b !== 'object') return false;

  // Handle circular references
  if (seen.has(a)) {
    return seen.get(a) === b;
  }
  seen.set(a, b);

  // Handle Date
  if (a instanceof Date && b instanceof Date) {
    return a.getTime() === b.getTime();
  }

  // Handle RegExp
  if (a instanceof RegExp && b instanceof RegExp) {
    return a.source === b.source && a.flags === b.flags;
  }

  // Handle Map
  if (a instanceof Map && b instanceof Map) {
    if (a.size !== b.size) return false;
    for (const [key, val] of a) {
      if (!b.has(key) || !deepEqual(val, b.get(key), seen)) {
        return false;
      }
    }
    return true;
  }

  // Handle Set
  if (a instanceof Set && b instanceof Set) {
    if (a.size !== b.size) return false;
    for (const val of a) {
      if (!b.has(val)) return false;
    }
    return true;
  }

  // Handle Array
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (!deepEqual(a[i], b[i], seen)) return false;
    }
    return true;
  }

  // Handle objects
  const keysA = Object.keys(a);
  const keysB = Object.keys(b);

  if (keysA.length !== keysB.length) return false;

  for (const key of keysA) {
    if (!keysB.includes(key) || !deepEqual(a[key], b[key], seen)) {
      return false;
    }
  }

  return true;
}

function deepMerge(target, ...sources) {
  if (!sources.length) return target;
  const source = sources.shift();

  if (isPlainObject(target) && isPlainObject(source)) {
    for (const key in source) {
      if (Object.prototype.hasOwnProperty.call(source, key)) {
        if (isPlainObject(source[key])) {
          if (!target[key]) {
            target[key] = {};
          }
          deepMerge(target[key], source[key]);
        } else if (Array.isArray(source[key])) {
          target[key] = deepClone(source[key]);
        } else {
          target[key] = source[key];
        }
      }
    }
  }

  return deepMerge(target, ...sources);
}

function isPlainObject(value) {
  if (value === null || typeof value !== 'object') return false;
  const proto = Object.getPrototypeOf(value);
  return proto === null || proto === Object.prototype;
}

function deepFreeze(obj) {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }

  Object.freeze(obj);

  for (const key of Object.keys(obj)) {
    const value = obj[key];
    if (typeof value === 'object' && value !== null && !Object.isFrozen(value)) {
      deepFreeze(value);
    }
  }

  return obj;
}

function deepSeal(obj) {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }

  Object.seal(obj);

  for (const key of Object.keys(obj)) {
    const value = obj[key];
    if (typeof value === 'object' && value !== null && !Object.isSealed(value)) {
      deepSeal(value);
    }
  }

  return obj;
}

function pick(obj, keys) {
  const result = {};
  for (const key of keys) {
    if (key in obj) {
      result[key] = obj[key];
    }
  }
  return result;
}

function omit(obj, keys) {
  const result = {};
  const keysToOmit = new Set(keys);
  for (const key in obj) {
    if (Object.prototype.hasOwnProperty.call(obj, key) && !keysToOmit.has(key)) {
      result[key] = obj[key];
    }
  }
  return result;
}

function get(obj, path, defaultValue) {
  const keys = typeof path === 'string' ? path.split('.') : path;
  let result = obj;

  for (const key of keys) {
    if (result === null || result === undefined) {
      return defaultValue;
    }
    result = result[key];
  }

  return result === undefined ? defaultValue : result;
}

function set(obj, path, value) {
  const keys = typeof path === 'string' ? path.split('.') : path;
  let current = obj;

  for (let i = 0; i < keys.length - 1; i++) {
    const key = keys[i];
    if (!(key in current) || typeof current[key] !== 'object') {
      current[key] = {};
    }
    current = current[key];
  }

  current[keys[keys.length - 1]] = value;
  return obj;
}

module.exports = {
  deepClone,
  deepEqual,
  deepMerge,
  deepFreeze,
  deepSeal,
  isPlainObject,
  pick,
  omit,
  get,
  set
};
