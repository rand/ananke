const {
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
} = require('./deep_clone');

describe('deepClone', () => {
  test('clones primitives', () => {
    expect(deepClone(42)).toBe(42);
    expect(deepClone('hello')).toBe('hello');
    expect(deepClone(true)).toBe(true);
    expect(deepClone(null)).toBe(null);
    expect(deepClone(undefined)).toBe(undefined);
  });

  test('clones arrays', () => {
    const arr = [1, 2, [3, 4]];
    const clone = deepClone(arr);

    expect(clone).toEqual(arr);
    expect(clone).not.toBe(arr);
    expect(clone[2]).not.toBe(arr[2]);
  });

  test('clones objects', () => {
    const obj = { a: 1, b: { c: 2 } };
    const clone = deepClone(obj);

    expect(clone).toEqual(obj);
    expect(clone).not.toBe(obj);
    expect(clone.b).not.toBe(obj.b);
  });

  test('clones Date', () => {
    const date = new Date('2023-01-01');
    const clone = deepClone(date);

    expect(clone).toEqual(date);
    expect(clone).not.toBe(date);
    expect(clone.getTime()).toBe(date.getTime());
  });

  test('clones RegExp', () => {
    const regex = /test/gi;
    const clone = deepClone(regex);

    expect(clone).not.toBe(regex);
    expect(clone.source).toBe(regex.source);
    expect(clone.flags).toBe(regex.flags);
  });

  test('clones Map', () => {
    const map = new Map([['a', 1], ['b', { c: 2 }]]);
    const clone = deepClone(map);

    expect(clone).not.toBe(map);
    expect(clone.get('a')).toBe(1);
    expect(clone.get('b')).toEqual({ c: 2 });
    expect(clone.get('b')).not.toBe(map.get('b'));
  });

  test('clones Set', () => {
    const set = new Set([1, 2, 3]);
    const clone = deepClone(set);

    expect(clone).not.toBe(set);
    expect([...clone]).toEqual([1, 2, 3]);
  });

  test('handles circular references', () => {
    const obj = { a: 1 };
    obj.self = obj;

    const clone = deepClone(obj);

    expect(clone.a).toBe(1);
    expect(clone.self).toBe(clone);
  });

  test('preserves prototype', () => {
    class Custom {
      constructor(value) {
        this.value = value;
      }
    }

    const obj = new Custom(42);
    const clone = deepClone(obj);

    expect(clone.value).toBe(42);
    expect(Object.getPrototypeOf(clone)).toBe(Custom.prototype);
  });

  test('clones symbol properties', () => {
    const sym = Symbol('test');
    const obj = { [sym]: 'value' };
    const clone = deepClone(obj);

    expect(clone[sym]).toBe('value');
  });
});

describe('deepEqual', () => {
  test('compares primitives', () => {
    expect(deepEqual(1, 1)).toBe(true);
    expect(deepEqual(1, 2)).toBe(false);
    expect(deepEqual('a', 'a')).toBe(true);
    expect(deepEqual(null, null)).toBe(true);
    expect(deepEqual(null, undefined)).toBe(false);
  });

  test('compares arrays', () => {
    expect(deepEqual([1, 2], [1, 2])).toBe(true);
    expect(deepEqual([1, 2], [1, 3])).toBe(false);
    expect(deepEqual([1, [2]], [1, [2]])).toBe(true);
  });

  test('compares objects', () => {
    expect(deepEqual({ a: 1 }, { a: 1 })).toBe(true);
    expect(deepEqual({ a: 1 }, { a: 2 })).toBe(false);
    expect(deepEqual({ a: { b: 1 } }, { a: { b: 1 } })).toBe(true);
  });

  test('compares Date', () => {
    const d1 = new Date('2023-01-01');
    const d2 = new Date('2023-01-01');
    const d3 = new Date('2023-01-02');

    expect(deepEqual(d1, d2)).toBe(true);
    expect(deepEqual(d1, d3)).toBe(false);
  });

  test('compares Map', () => {
    const m1 = new Map([['a', 1]]);
    const m2 = new Map([['a', 1]]);
    const m3 = new Map([['a', 2]]);

    expect(deepEqual(m1, m2)).toBe(true);
    expect(deepEqual(m1, m3)).toBe(false);
  });

  test('handles circular references', () => {
    const a = { x: 1 };
    a.self = a;
    const b = { x: 1 };
    b.self = b;

    expect(deepEqual(a, b)).toBe(true);
  });
});

describe('deepMerge', () => {
  test('merges objects', () => {
    const a = { x: 1 };
    const b = { y: 2 };
    const result = deepMerge({}, a, b);

    expect(result).toEqual({ x: 1, y: 2 });
  });

  test('deep merges nested objects', () => {
    const a = { nested: { a: 1 } };
    const b = { nested: { b: 2 } };
    const result = deepMerge({}, a, b);

    expect(result).toEqual({ nested: { a: 1, b: 2 } });
  });

  test('overwrites non-object values', () => {
    const a = { x: 1 };
    const b = { x: 2 };
    const result = deepMerge({}, a, b);

    expect(result).toEqual({ x: 2 });
  });

  test('clones arrays', () => {
    const a = { arr: [1, 2] };
    const result = deepMerge({}, a);

    expect(result.arr).toEqual([1, 2]);
    expect(result.arr).not.toBe(a.arr);
  });
});

describe('deepFreeze', () => {
  test('freezes object', () => {
    const obj = { a: 1 };
    deepFreeze(obj);

    expect(Object.isFrozen(obj)).toBe(true);
  });

  test('freezes nested objects', () => {
    const obj = { nested: { a: 1 } };
    deepFreeze(obj);

    expect(Object.isFrozen(obj.nested)).toBe(true);
  });
});

describe('deepSeal', () => {
  test('seals object', () => {
    const obj = { a: 1 };
    deepSeal(obj);

    expect(Object.isSealed(obj)).toBe(true);
  });

  test('seals nested objects', () => {
    const obj = { nested: { a: 1 } };
    deepSeal(obj);

    expect(Object.isSealed(obj.nested)).toBe(true);
  });
});

describe('isPlainObject', () => {
  test('returns true for plain objects', () => {
    expect(isPlainObject({})).toBe(true);
    expect(isPlainObject({ a: 1 })).toBe(true);
    expect(isPlainObject(Object.create(null))).toBe(true);
  });

  test('returns false for non-plain objects', () => {
    expect(isPlainObject([])).toBe(false);
    expect(isPlainObject(new Date())).toBe(false);
    expect(isPlainObject(null)).toBe(false);
    expect(isPlainObject(42)).toBe(false);
  });
});

describe('pick', () => {
  test('picks specified keys', () => {
    const obj = { a: 1, b: 2, c: 3 };
    expect(pick(obj, ['a', 'c'])).toEqual({ a: 1, c: 3 });
  });

  test('ignores missing keys', () => {
    const obj = { a: 1 };
    expect(pick(obj, ['a', 'b'])).toEqual({ a: 1 });
  });
});

describe('omit', () => {
  test('omits specified keys', () => {
    const obj = { a: 1, b: 2, c: 3 };
    expect(omit(obj, ['b'])).toEqual({ a: 1, c: 3 });
  });
});

describe('get', () => {
  test('gets nested value', () => {
    const obj = { a: { b: { c: 42 } } };
    expect(get(obj, 'a.b.c')).toBe(42);
  });

  test('returns default for missing path', () => {
    const obj = { a: 1 };
    expect(get(obj, 'a.b.c', 'default')).toBe('default');
  });

  test('accepts array path', () => {
    const obj = { a: { b: 42 } };
    expect(get(obj, ['a', 'b'])).toBe(42);
  });
});

describe('set', () => {
  test('sets nested value', () => {
    const obj = {};
    set(obj, 'a.b.c', 42);
    expect(obj.a.b.c).toBe(42);
  });

  test('overwrites existing value', () => {
    const obj = { a: { b: 1 } };
    set(obj, 'a.b', 2);
    expect(obj.a.b).toBe(2);
  });

  test('accepts array path', () => {
    const obj = {};
    set(obj, ['a', 'b'], 42);
    expect(obj.a.b).toBe(42);
  });
});
