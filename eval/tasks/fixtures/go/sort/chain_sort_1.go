// Package sort implements basic sorting algorithms with Go generics
package sort

import (
	"golang.org/x/exp/constraints"
)

// QuickSort sorts a slice in-place using quicksort with median-of-three pivot
func QuickSort[T constraints.Ordered](arr []T) {
	if len(arr) <= 1 {
		return
	}
	quicksortHelper(arr, 0, len(arr)-1)
}

func quicksortHelper[T constraints.Ordered](arr []T, lo, hi int) {
	if lo >= hi {
		return
	}

	// Use insertion sort for small subarrays
	if hi-lo < 10 {
		insertionSortRange(arr, lo, hi)
		return
	}

	pivot := partition(arr, lo, hi)
	quicksortHelper(arr, lo, pivot-1)
	quicksortHelper(arr, pivot+1, hi)
}

func partition[T constraints.Ordered](arr []T, lo, hi int) int {
	// Median-of-three pivot selection
	mid := lo + (hi-lo)/2
	if arr[mid] < arr[lo] {
		arr[lo], arr[mid] = arr[mid], arr[lo]
	}
	if arr[hi] < arr[lo] {
		arr[lo], arr[hi] = arr[hi], arr[lo]
	}
	if arr[hi] < arr[mid] {
		arr[mid], arr[hi] = arr[hi], arr[mid]
	}
	// Move median to hi-1
	arr[mid], arr[hi-1] = arr[hi-1], arr[mid]
	pivot := arr[hi-1]

	i := lo
	j := hi - 1
	for {
		for i++; arr[i] < pivot; i++ {
		}
		for j--; j > lo && arr[j] > pivot; j-- {
		}
		if i >= j {
			break
		}
		arr[i], arr[j] = arr[j], arr[i]
	}
	arr[i], arr[hi-1] = arr[hi-1], arr[i]
	return i
}

func insertionSortRange[T constraints.Ordered](arr []T, lo, hi int) {
	for i := lo + 1; i <= hi; i++ {
		key := arr[i]
		j := i - 1
		for j >= lo && arr[j] > key {
			arr[j+1] = arr[j]
			j--
		}
		arr[j+1] = key
	}
}

// InsertionSort sorts a slice in-place using insertion sort
func InsertionSort[T constraints.Ordered](arr []T) {
	for i := 1; i < len(arr); i++ {
		key := arr[i]
		j := i - 1
		for j >= 0 && arr[j] > key {
			arr[j+1] = arr[j]
			j--
		}
		arr[j+1] = key
	}
}

// MergeSort returns a new sorted slice using mergesort
func MergeSort[T constraints.Ordered](arr []T) []T {
	if len(arr) <= 1 {
		result := make([]T, len(arr))
		copy(result, arr)
		return result
	}

	mid := len(arr) / 2
	left := MergeSort(arr[:mid])
	right := MergeSort(arr[mid:])

	return merge(left, right)
}

func merge[T constraints.Ordered](left, right []T) []T {
	result := make([]T, 0, len(left)+len(right))
	i, j := 0, 0

	for i < len(left) && j < len(right) {
		if left[i] <= right[j] {
			result = append(result, left[i])
			i++
		} else {
			result = append(result, right[j])
			j++
		}
	}

	result = append(result, left[i:]...)
	result = append(result, right[j:]...)
	return result
}

// HeapSort sorts a slice in-place using heapsort
func HeapSort[T constraints.Ordered](arr []T) {
	n := len(arr)

	// Build max heap
	for i := n/2 - 1; i >= 0; i-- {
		heapify(arr, n, i)
	}

	// Extract elements from heap
	for i := n - 1; i > 0; i-- {
		arr[0], arr[i] = arr[i], arr[0]
		heapify(arr, i, 0)
	}
}

func heapify[T constraints.Ordered](arr []T, n, i int) {
	largest := i
	left := 2*i + 1
	right := 2*i + 2

	if left < n && arr[left] > arr[largest] {
		largest = left
	}
	if right < n && arr[right] > arr[largest] {
		largest = right
	}
	if largest != i {
		arr[i], arr[largest] = arr[largest], arr[i]
		heapify(arr, n, largest)
	}
}

// IsSorted checks if a slice is sorted in ascending order
func IsSorted[T constraints.Ordered](arr []T) bool {
	for i := 1; i < len(arr); i++ {
		if arr[i] < arr[i-1] {
			return false
		}
	}
	return true
}

// BubbleSort sorts a slice in-place using bubble sort
func BubbleSort[T constraints.Ordered](arr []T) {
	n := len(arr)
	for i := 0; i < n-1; i++ {
		swapped := false
		for j := 0; j < n-i-1; j++ {
			if arr[j] > arr[j+1] {
				arr[j], arr[j+1] = arr[j+1], arr[j]
				swapped = true
			}
		}
		if !swapped {
			break
		}
	}
}

// SelectionSort sorts a slice in-place using selection sort
func SelectionSort[T constraints.Ordered](arr []T) {
	n := len(arr)
	for i := 0; i < n-1; i++ {
		minIdx := i
		for j := i + 1; j < n; j++ {
			if arr[j] < arr[minIdx] {
				minIdx = j
			}
		}
		arr[i], arr[minIdx] = arr[minIdx], arr[i]
	}
}
