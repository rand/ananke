// Package sort implements sorting with custom comparators
package sort

// Comparator returns negative if a < b, zero if a == b, positive if a > b
type Comparator[T any] func(a, b T) int

// SortFunc sorts a slice using a custom comparator
func SortFunc[T any](arr []T, cmp Comparator[T]) {
	if len(arr) <= 1 {
		return
	}
	quickSortFunc(arr, 0, len(arr)-1, cmp)
}

func quickSortFunc[T any](arr []T, lo, hi int, cmp Comparator[T]) {
	if lo >= hi {
		return
	}

	if hi-lo < 10 {
		insertionSortFunc(arr, lo, hi, cmp)
		return
	}

	pivot := partitionFunc(arr, lo, hi, cmp)
	quickSortFunc(arr, lo, pivot-1, cmp)
	quickSortFunc(arr, pivot+1, hi, cmp)
}

func partitionFunc[T any](arr []T, lo, hi int, cmp Comparator[T]) int {
	pivot := arr[hi]
	i := lo - 1

	for j := lo; j < hi; j++ {
		if cmp(arr[j], pivot) <= 0 {
			i++
			arr[i], arr[j] = arr[j], arr[i]
		}
	}
	arr[i+1], arr[hi] = arr[hi], arr[i+1]
	return i + 1
}

func insertionSortFunc[T any](arr []T, lo, hi int, cmp Comparator[T]) {
	for i := lo + 1; i <= hi; i++ {
		key := arr[i]
		j := i - 1
		for j >= lo && cmp(arr[j], key) > 0 {
			arr[j+1] = arr[j]
			j--
		}
		arr[j+1] = key
	}
}

// MergeSortFunc returns a sorted copy using a custom comparator
func MergeSortFunc[T any](arr []T, cmp Comparator[T]) []T {
	if len(arr) <= 1 {
		result := make([]T, len(arr))
		copy(result, arr)
		return result
	}

	mid := len(arr) / 2
	left := MergeSortFunc(arr[:mid], cmp)
	right := MergeSortFunc(arr[mid:], cmp)

	return mergeFunc(left, right, cmp)
}

func mergeFunc[T any](left, right []T, cmp Comparator[T]) []T {
	result := make([]T, 0, len(left)+len(right))
	i, j := 0, 0

	for i < len(left) && j < len(right) {
		if cmp(left[i], right[j]) <= 0 {
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

// StableSortFunc performs a stable sort using a custom comparator
func StableSortFunc[T any](arr []T, cmp Comparator[T]) {
	// Merge sort is stable
	result := MergeSortFunc(arr, cmp)
	copy(arr, result)
}

// IsSortedFunc checks if a slice is sorted according to a comparator
func IsSortedFunc[T any](arr []T, cmp Comparator[T]) bool {
	for i := 1; i < len(arr); i++ {
		if cmp(arr[i-1], arr[i]) > 0 {
			return false
		}
	}
	return true
}

// Reverse reverses a slice in-place
func Reverse[T any](arr []T) {
	for i, j := 0, len(arr)-1; i < j; i, j = i+1, j-1 {
		arr[i], arr[j] = arr[j], arr[i]
	}
}

// SortBy sorts a slice by a key extractor function
func SortBy[T any, K comparable](arr []T, keyFn func(T) K, keyOrder []K) {
	orderMap := make(map[K]int)
	for i, k := range keyOrder {
		orderMap[k] = i
	}

	SortFunc(arr, func(a, b T) int {
		orderA := orderMap[keyFn(a)]
		orderB := orderMap[keyFn(b)]
		if orderA < orderB {
			return -1
		}
		if orderA > orderB {
			return 1
		}
		return 0
	})
}

// SortByKey sorts a slice by extracting a comparable key
func SortByKey[T any, K interface{ ~int | ~string | ~float64 }](arr []T, keyFn func(T) K) {
	SortFunc(arr, func(a, b T) int {
		ka, kb := keyFn(a), keyFn(b)
		if ka < kb {
			return -1
		}
		if ka > kb {
			return 1
		}
		return 0
	})
}

// MultiSort sorts by multiple keys in order of priority
type SortKey[T any] struct {
	Cmp        Comparator[T]
	Descending bool
}

func MultiSort[T any](arr []T, keys []SortKey[T]) {
	SortFunc(arr, func(a, b T) int {
		for _, key := range keys {
			result := key.Cmp(a, b)
			if key.Descending {
				result = -result
			}
			if result != 0 {
				return result
			}
		}
		return 0
	})
}

// PartialSort partially sorts to get top-k elements
func PartialSort[T any](arr []T, k int, cmp Comparator[T]) {
	if k <= 0 || k >= len(arr) {
		SortFunc(arr, cmp)
		return
	}
	partialQuickSort(arr, 0, len(arr)-1, k, cmp)
}

func partialQuickSort[T any](arr []T, lo, hi, k int, cmp Comparator[T]) {
	if lo >= hi {
		return
	}

	pivot := partitionFunc(arr, lo, hi, cmp)

	partialQuickSort(arr, lo, pivot-1, k, cmp)
	if pivot < k-1 {
		partialQuickSort(arr, pivot+1, hi, k, cmp)
	}
}

// TopK returns the top k elements (not necessarily sorted)
func TopK[T any](arr []T, k int, cmp Comparator[T]) []T {
	if k <= 0 {
		return nil
	}
	if k >= len(arr) {
		result := make([]T, len(arr))
		copy(result, arr)
		return result
	}

	// Copy to avoid modifying original
	tmp := make([]T, len(arr))
	copy(tmp, arr)

	quickSelect(tmp, 0, len(tmp)-1, k-1, cmp)

	result := make([]T, k)
	copy(result, tmp[:k])
	return result
}

func quickSelect[T any](arr []T, lo, hi, k int, cmp Comparator[T]) {
	if lo >= hi {
		return
	}

	pivot := partitionFunc(arr, lo, hi, cmp)

	if pivot == k {
		return
	} else if pivot < k {
		quickSelect(arr, pivot+1, hi, k, cmp)
	} else {
		quickSelect(arr, lo, pivot-1, k, cmp)
	}
}
