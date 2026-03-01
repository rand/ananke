package sort

import (
	"math/rand"
	"testing"
)

func TestQuickSortInts(t *testing.T) {
	arr := []int{5, 2, 8, 1, 9, 3, 7, 4, 6}
	QuickSort(arr)

	if !IsSorted(arr) {
		t.Errorf("QuickSort failed: %v", arr)
	}
}

func TestQuickSortStrings(t *testing.T) {
	arr := []string{"banana", "apple", "cherry", "date"}
	QuickSort(arr)

	expected := []string{"apple", "banana", "cherry", "date"}
	for i, v := range arr {
		if v != expected[i] {
			t.Errorf("QuickSort strings failed at %d: got %s, want %s", i, v, expected[i])
		}
	}
}

func TestQuickSortEmpty(t *testing.T) {
	arr := []int{}
	QuickSort(arr) // Should not panic
}

func TestQuickSortSingleElement(t *testing.T) {
	arr := []int{42}
	QuickSort(arr)
	if arr[0] != 42 {
		t.Error("Single element should remain unchanged")
	}
}

func TestQuickSortAlreadySorted(t *testing.T) {
	arr := []int{1, 2, 3, 4, 5}
	QuickSort(arr)
	if !IsSorted(arr) {
		t.Error("Already sorted array should remain sorted")
	}
}

func TestQuickSortReverseSorted(t *testing.T) {
	arr := []int{5, 4, 3, 2, 1}
	QuickSort(arr)
	if !IsSorted(arr) {
		t.Error("Reverse sorted array should be sorted")
	}
}

func TestQuickSortDuplicates(t *testing.T) {
	arr := []int{3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5}
	QuickSort(arr)
	if !IsSorted(arr) {
		t.Error("Array with duplicates should be sorted")
	}
}

func TestMergeSortInts(t *testing.T) {
	arr := []int{5, 2, 8, 1, 9, 3, 7, 4, 6}
	result := MergeSort(arr)

	if !IsSorted(result) {
		t.Errorf("MergeSort failed: %v", result)
	}

	// Original should be unchanged
	if arr[0] != 5 {
		t.Error("MergeSort should not modify original")
	}
}

func TestMergeSortFloats(t *testing.T) {
	arr := []float64{3.14, 1.41, 2.71, 1.73}
	result := MergeSort(arr)

	if !IsSorted(result) {
		t.Error("MergeSort floats failed")
	}
}

func TestMergeSortEmpty(t *testing.T) {
	arr := []int{}
	result := MergeSort(arr)
	if len(result) != 0 {
		t.Error("Empty input should return empty result")
	}
}

func TestMergeSortSingleElement(t *testing.T) {
	arr := []int{42}
	result := MergeSort(arr)
	if len(result) != 1 || result[0] != 42 {
		t.Error("Single element should return same element")
	}
}

func TestInsertionSortInts(t *testing.T) {
	arr := []int{5, 2, 8, 1, 9}
	InsertionSort(arr)

	if !IsSorted(arr) {
		t.Errorf("InsertionSort failed: %v", arr)
	}
}

func TestInsertionSortSmall(t *testing.T) {
	arr := []int{3, 1, 2}
	InsertionSort(arr)
	expected := []int{1, 2, 3}
	for i, v := range arr {
		if v != expected[i] {
			t.Errorf("InsertionSort failed at %d", i)
		}
	}
}

func TestHeapSortInts(t *testing.T) {
	arr := []int{5, 2, 8, 1, 9, 3, 7, 4, 6}
	HeapSort(arr)

	if !IsSorted(arr) {
		t.Errorf("HeapSort failed: %v", arr)
	}
}

func TestHeapSortEmpty(t *testing.T) {
	arr := []int{}
	HeapSort(arr) // Should not panic
}

func TestHeapSortSingleElement(t *testing.T) {
	arr := []int{42}
	HeapSort(arr)
	if arr[0] != 42 {
		t.Error("Single element should remain unchanged")
	}
}

func TestBubbleSortInts(t *testing.T) {
	arr := []int{5, 2, 8, 1, 9}
	BubbleSort(arr)

	if !IsSorted(arr) {
		t.Errorf("BubbleSort failed: %v", arr)
	}
}

func TestBubbleSortOptimization(t *testing.T) {
	// Already sorted - should exit early
	arr := []int{1, 2, 3, 4, 5}
	BubbleSort(arr)
	if !IsSorted(arr) {
		t.Error("BubbleSort should handle sorted input")
	}
}

func TestSelectionSortInts(t *testing.T) {
	arr := []int{5, 2, 8, 1, 9}
	SelectionSort(arr)

	if !IsSorted(arr) {
		t.Errorf("SelectionSort failed: %v", arr)
	}
}

func TestIsSorted(t *testing.T) {
	sorted := []int{1, 2, 3, 4, 5}
	if !IsSorted(sorted) {
		t.Error("IsSorted should return true for sorted array")
	}

	unsorted := []int{1, 3, 2, 4, 5}
	if IsSorted(unsorted) {
		t.Error("IsSorted should return false for unsorted array")
	}

	empty := []int{}
	if !IsSorted(empty) {
		t.Error("IsSorted should return true for empty array")
	}

	single := []int{42}
	if !IsSorted(single) {
		t.Error("IsSorted should return true for single element")
	}
}

func TestQuickSortLarge(t *testing.T) {
	arr := make([]int, 10000)
	for i := range arr {
		arr[i] = rand.Intn(100000)
	}
	QuickSort(arr)
	if !IsSorted(arr) {
		t.Error("QuickSort failed on large array")
	}
}

func TestMergeSortLarge(t *testing.T) {
	arr := make([]int, 10000)
	for i := range arr {
		arr[i] = rand.Intn(100000)
	}
	result := MergeSort(arr)
	if !IsSorted(result) {
		t.Error("MergeSort failed on large array")
	}
}

func TestHeapSortLarge(t *testing.T) {
	arr := make([]int, 10000)
	for i := range arr {
		arr[i] = rand.Intn(100000)
	}
	HeapSort(arr)
	if !IsSorted(arr) {
		t.Error("HeapSort failed on large array")
	}
}

func BenchmarkQuickSort(b *testing.B) {
	for i := 0; i < b.N; i++ {
		arr := make([]int, 1000)
		for j := range arr {
			arr[j] = rand.Intn(10000)
		}
		QuickSort(arr)
	}
}

func BenchmarkMergeSort(b *testing.B) {
	for i := 0; i < b.N; i++ {
		arr := make([]int, 1000)
		for j := range arr {
			arr[j] = rand.Intn(10000)
		}
		MergeSort(arr)
	}
}
