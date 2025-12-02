/**
 * Binary search implementation
 * Finds the index of a target value in a sorted array
 * @param arr - Sorted array of numbers in ascending order
 * @param target - Value to search for
 * @returns Index of target if found, -1 otherwise
 */
export function binarySearch(arr: number[], target: number): number {
  let left = 0;
  let right = arr.length - 1;

  while (left <= right) {
    const mid = Math.floor((left + right) / 2);

    if (arr[mid] === target) {
      return mid;
    } else if (arr[mid] < target) {
      left = mid + 1;
    } else {
      right = mid - 1;
    }
  }

  return -1;
}
