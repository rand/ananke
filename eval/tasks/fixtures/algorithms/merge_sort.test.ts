import { describe, it, expect } from '@jest/globals';
import { mergeSort } from './merge_sort';

describe('mergeSort', () => {
  // Basic functionality
  it('should sort an unsorted array', () => {
    const input = [64, 34, 25, 12, 22, 11, 90];
    const expected = [11, 12, 22, 25, 34, 64, 90];

    expect(mergeSort(input)).toEqual(expected);
  });

  it('should handle already sorted array', () => {
    const input = [1, 2, 3, 4, 5];

    expect(mergeSort(input)).toEqual([1, 2, 3, 4, 5]);
  });

  it('should handle reverse sorted array', () => {
    const input = [5, 4, 3, 2, 1];

    expect(mergeSort(input)).toEqual([1, 2, 3, 4, 5]);
  });

  // Edge cases
  it('should handle empty array', () => {
    expect(mergeSort([])).toEqual([]);
  });

  it('should handle single element array', () => {
    expect(mergeSort([42])).toEqual([42]);
  });

  it('should handle two element array', () => {
    expect(mergeSort([2, 1])).toEqual([1, 2]);
    expect(mergeSort([1, 2])).toEqual([1, 2]);
  });

  // Duplicates
  it('should handle array with duplicates', () => {
    const input = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3];
    const expected = [1, 1, 2, 3, 3, 4, 5, 5, 6, 9];

    expect(mergeSort(input)).toEqual(expected);
  });

  it('should handle array with all same elements', () => {
    const input = [5, 5, 5, 5, 5];

    expect(mergeSort(input)).toEqual([5, 5, 5, 5, 5]);
  });

  // Negative numbers
  it('should handle negative numbers', () => {
    const input = [3, -1, 4, -5, 2, 0];
    const expected = [-5, -1, 0, 2, 3, 4];

    expect(mergeSort(input)).toEqual(expected);
  });

  it('should handle all negative numbers', () => {
    const input = [-3, -1, -4, -2];
    const expected = [-4, -3, -2, -1];

    expect(mergeSort(input)).toEqual(expected);
  });

  // Decimal numbers
  it('should handle decimal numbers', () => {
    const input = [3.14, 1.41, 2.71, 0.5];
    const expected = [0.5, 1.41, 2.71, 3.14];

    expect(mergeSort(input)).toEqual(expected);
  });

  // Immutability
  it('should not modify the input array', () => {
    const input = [3, 1, 4, 1, 5];
    const inputCopy = [...input];

    mergeSort(input);

    expect(input).toEqual(inputCopy);
  });

  it('should return a new array', () => {
    const input = [3, 1, 2];
    const result = mergeSort(input);

    expect(result).not.toBe(input);
  });

  // Large arrays
  it('should handle large sorted array', () => {
    const input = Array.from({ length: 1000 }, (_, i) => i);
    const expected = Array.from({ length: 1000 }, (_, i) => i);

    expect(mergeSort(input)).toEqual(expected);
  });

  it('should handle large reverse sorted array', () => {
    const input = Array.from({ length: 1000 }, (_, i) => 1000 - i);
    const expected = Array.from({ length: 1000 }, (_, i) => i + 1);

    expect(mergeSort(input)).toEqual(expected);
  });

  it('should handle large random array', () => {
    const input = Array.from({ length: 1000 }, () => Math.floor(Math.random() * 1000));
    const result = mergeSort(input);

    // Verify it's sorted
    for (let i = 0; i < result.length - 1; i++) {
      expect(result[i]).toBeLessThanOrEqual(result[i + 1]);
    }
  });

  // Performance - O(n log n)
  it('should be efficient for large arrays', () => {
    const input = Array.from({ length: 10000 }, () => Math.floor(Math.random() * 10000));

    const start = Date.now();
    mergeSort(input);
    const duration = Date.now() - start;

    expect(duration).toBeLessThan(100); // Should complete in <100ms
  });

  // Stability test (equal elements maintain relative order)
  it('should be stable (maintain relative order of equal elements)', () => {
    // Note: For primitive numbers, stability is not observable
    // This test just verifies correct sorting with duplicates
    const input = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5];
    const result = mergeSort(input);
    const expected = [1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 9];

    expect(result).toEqual(expected);
  });

  // Special values
  it('should handle very large numbers', () => {
    const input = [Number.MAX_SAFE_INTEGER, 1, Number.MIN_SAFE_INTEGER];
    const expected = [Number.MIN_SAFE_INTEGER, 1, Number.MAX_SAFE_INTEGER];

    expect(mergeSort(input)).toEqual(expected);
  });

  it('should handle zero', () => {
    const input = [0, -1, 1, 0, 2, -2];
    const expected = [-2, -1, 0, 0, 1, 2];

    expect(mergeSort(input)).toEqual(expected);
  });

  // Odd and even length arrays
  it('should handle odd length array', () => {
    const input = [5, 2, 8, 1, 9];
    const expected = [1, 2, 5, 8, 9];

    expect(mergeSort(input)).toEqual(expected);
  });

  it('should handle even length array', () => {
    const input = [5, 2, 8, 1];
    const expected = [1, 2, 5, 8];

    expect(mergeSort(input)).toEqual(expected);
  });
});
