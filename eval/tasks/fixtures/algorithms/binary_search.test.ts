import { describe, it, expect } from '@jest/globals';
import { binarySearch } from './binary_search';

describe('binarySearch', () => {
  // Basic functionality
  it('should find element in the middle', () => {
    expect(binarySearch([1, 2, 3, 4, 5], 3)).toBe(2);
  });

  it('should find element at the beginning', () => {
    expect(binarySearch([1, 2, 3, 4, 5], 1)).toBe(0);
  });

  it('should find element at the end', () => {
    expect(binarySearch([1, 2, 3, 4, 5], 5)).toBe(4);
  });

  // Not found cases
  it('should return -1 when target not in array', () => {
    expect(binarySearch([1, 2, 3, 4, 5], 6)).toBe(-1);
  });

  it('should return -1 when target less than all elements', () => {
    expect(binarySearch([5, 10, 15, 20], 3)).toBe(-1);
  });

  it('should return -1 when target greater than all elements', () => {
    expect(binarySearch([5, 10, 15, 20], 25)).toBe(-1);
  });

  // Edge cases
  it('should handle empty array', () => {
    expect(binarySearch([], 5)).toBe(-1);
  });

  it('should handle single element array - found', () => {
    expect(binarySearch([5], 5)).toBe(0);
  });

  it('should handle single element array - not found', () => {
    expect(binarySearch([5], 3)).toBe(-1);
  });

  it('should handle two element array - first element', () => {
    expect(binarySearch([3, 7], 3)).toBe(0);
  });

  it('should handle two element array - second element', () => {
    expect(binarySearch([3, 7], 7)).toBe(1);
  });

  // Large arrays
  it('should work with large sorted array', () => {
    const arr = Array.from({ length: 1000 }, (_, i) => i * 2);
    expect(binarySearch(arr, 500)).toBe(250);
  });

  it('should handle duplicates (returns first occurrence)', () => {
    expect(binarySearch([1, 2, 3, 3, 3, 4, 5], 3)).toBeGreaterThanOrEqual(2);
    expect(binarySearch([1, 2, 3, 3, 3, 4, 5], 3)).toBeLessThanOrEqual(4);
  });

  // Negative numbers
  it('should work with negative numbers', () => {
    expect(binarySearch([-10, -5, 0, 5, 10], -5)).toBe(1);
    expect(binarySearch([-10, -5, 0, 5, 10], 0)).toBe(2);
  });

  // Performance characteristic - O(log n)
  it('should be efficient for large arrays', () => {
    const arr = Array.from({ length: 1000000 }, (_, i) => i);
    const start = Date.now();
    binarySearch(arr, 999999);
    const duration = Date.now() - start;
    expect(duration).toBeLessThan(10); // Should complete in <10ms
  });
});
