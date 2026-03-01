package sort

import (
	"strings"
	"testing"
)

type Person struct {
	Name string
	Age  int
}

func TestSortFuncInts(t *testing.T) {
	arr := []int{5, 2, 8, 1, 9}
	SortFunc(arr, func(a, b int) int {
		return a - b
	})

	expected := []int{1, 2, 5, 8, 9}
	for i, v := range arr {
		if v != expected[i] {
			t.Errorf("SortFunc failed at %d: got %d, want %d", i, v, expected[i])
		}
	}
}

func TestSortFuncDescending(t *testing.T) {
	arr := []int{5, 2, 8, 1, 9}
	SortFunc(arr, func(a, b int) int {
		return b - a // Descending
	})

	expected := []int{9, 8, 5, 2, 1}
	for i, v := range arr {
		if v != expected[i] {
			t.Errorf("Descending sort failed at %d", i)
		}
	}
}

func TestSortFuncStrings(t *testing.T) {
	arr := []string{"banana", "Apple", "cherry", "Date"}
	SortFunc(arr, func(a, b string) int {
		return strings.Compare(strings.ToLower(a), strings.ToLower(b))
	})

	expected := []string{"Apple", "banana", "cherry", "Date"}
	for i, v := range arr {
		if v != expected[i] {
			t.Errorf("Case-insensitive sort failed at %d", i)
		}
	}
}

func TestSortFuncStructs(t *testing.T) {
	people := []Person{
		{"Alice", 30},
		{"Bob", 25},
		{"Charlie", 35},
	}

	SortFunc(people, func(a, b Person) int {
		return a.Age - b.Age
	})

	if people[0].Name != "Bob" || people[1].Name != "Alice" || people[2].Name != "Charlie" {
		t.Error("Struct sort by age failed")
	}
}

func TestSortFuncEmpty(t *testing.T) {
	arr := []int{}
	SortFunc(arr, func(a, b int) int { return a - b })
	// Should not panic
}

func TestMergeSortFunc(t *testing.T) {
	arr := []int{5, 2, 8, 1, 9}
	result := MergeSortFunc(arr, func(a, b int) int {
		return a - b
	})

	if !IsSortedFunc(result, func(a, b int) int { return a - b }) {
		t.Error("MergeSortFunc failed")
	}

	// Original unchanged
	if arr[0] != 5 {
		t.Error("MergeSortFunc should not modify original")
	}
}

func TestStableSortFunc(t *testing.T) {
	type Item struct {
		Key   int
		Value string
	}

	items := []Item{
		{1, "a"},
		{2, "b"},
		{1, "c"},
		{2, "d"},
		{1, "e"},
	}

	StableSortFunc(items, func(a, b Item) int {
		return a.Key - b.Key
	})

	// Items with same key should maintain relative order
	key1Items := []string{}
	for _, item := range items {
		if item.Key == 1 {
			key1Items = append(key1Items, item.Value)
		}
	}

	if key1Items[0] != "a" || key1Items[1] != "c" || key1Items[2] != "e" {
		t.Error("Stable sort did not maintain relative order")
	}
}

func TestIsSortedFunc(t *testing.T) {
	cmp := func(a, b int) int { return a - b }

	sorted := []int{1, 2, 3, 4, 5}
	if !IsSortedFunc(sorted, cmp) {
		t.Error("IsSortedFunc should return true for sorted")
	}

	unsorted := []int{1, 3, 2}
	if IsSortedFunc(unsorted, cmp) {
		t.Error("IsSortedFunc should return false for unsorted")
	}
}

func TestReverse(t *testing.T) {
	arr := []int{1, 2, 3, 4, 5}
	Reverse(arr)

	expected := []int{5, 4, 3, 2, 1}
	for i, v := range arr {
		if v != expected[i] {
			t.Errorf("Reverse failed at %d", i)
		}
	}
}

func TestReverseEmpty(t *testing.T) {
	arr := []int{}
	Reverse(arr) // Should not panic
}

func TestReverseSingle(t *testing.T) {
	arr := []int{42}
	Reverse(arr)
	if arr[0] != 42 {
		t.Error("Single element should be unchanged")
	}
}

func TestSortByKey(t *testing.T) {
	people := []Person{
		{"Alice", 30},
		{"Bob", 25},
		{"Charlie", 35},
	}

	SortByKey(people, func(p Person) int { return p.Age })

	if people[0].Name != "Bob" {
		t.Error("SortByKey failed")
	}
}

func TestMultiSort(t *testing.T) {
	people := []Person{
		{"Alice", 30},
		{"Bob", 30},
		{"Charlie", 25},
		{"David", 25},
	}

	keys := []SortKey[Person]{
		{
			Cmp: func(a, b Person) int { return a.Age - b.Age },
		},
		{
			Cmp: func(a, b Person) int { return strings.Compare(a.Name, b.Name) },
		},
	}

	MultiSort(people, keys)

	// Should be: Charlie(25), David(25), Alice(30), Bob(30)
	expected := []string{"Charlie", "David", "Alice", "Bob"}
	for i, p := range people {
		if p.Name != expected[i] {
			t.Errorf("MultiSort failed at %d: got %s, want %s", i, p.Name, expected[i])
		}
	}
}

func TestMultiSortDescending(t *testing.T) {
	people := []Person{
		{"Alice", 30},
		{"Bob", 25},
	}

	keys := []SortKey[Person]{
		{
			Cmp:        func(a, b Person) int { return a.Age - b.Age },
			Descending: true,
		},
	}

	MultiSort(people, keys)

	if people[0].Name != "Alice" {
		t.Error("Descending multi-sort failed")
	}
}

func TestPartialSort(t *testing.T) {
	arr := []int{9, 5, 2, 8, 1, 7, 3, 6, 4}
	cmp := func(a, b int) int { return a - b }

	PartialSort(arr, 3, cmp)

	// First 3 should be smallest
	for i := 0; i < 3; i++ {
		if arr[i] > 3 {
			t.Errorf("PartialSort: position %d has %d, expected <= 3", i, arr[i])
		}
	}
}

func TestPartialSortK0(t *testing.T) {
	arr := []int{3, 1, 2}
	cmp := func(a, b int) int { return a - b }
	PartialSort(arr, 0, cmp)
	// Should fully sort
	if !IsSortedFunc(arr, cmp) {
		t.Error("PartialSort with k=0 should fully sort")
	}
}

func TestPartialSortKLarge(t *testing.T) {
	arr := []int{3, 1, 2}
	cmp := func(a, b int) int { return a - b }
	PartialSort(arr, 100, cmp)
	// Should fully sort
	if !IsSortedFunc(arr, cmp) {
		t.Error("PartialSort with k>len should fully sort")
	}
}

func TestTopK(t *testing.T) {
	arr := []int{9, 5, 2, 8, 1, 7, 3, 6, 4}
	cmp := func(a, b int) int { return a - b }

	top := TopK(arr, 3, cmp)

	if len(top) != 3 {
		t.Errorf("TopK should return 3 elements, got %d", len(top))
	}

	// All elements should be <= 3
	for _, v := range top {
		if v > 3 {
			t.Errorf("TopK element %d is > 3", v)
		}
	}
}

func TestTopKZero(t *testing.T) {
	arr := []int{3, 1, 2}
	cmp := func(a, b int) int { return a - b }

	top := TopK(arr, 0, cmp)
	if top != nil {
		t.Error("TopK with k=0 should return nil")
	}
}

func TestTopKAll(t *testing.T) {
	arr := []int{3, 1, 2}
	cmp := func(a, b int) int { return a - b }

	top := TopK(arr, 100, cmp)
	if len(top) != 3 {
		t.Errorf("TopK with k>len should return all elements")
	}
}

func TestSortFuncLarge(t *testing.T) {
	arr := make([]int, 10000)
	for i := range arr {
		arr[i] = 10000 - i
	}

	SortFunc(arr, func(a, b int) int { return a - b })

	if !IsSortedFunc(arr, func(a, b int) int { return a - b }) {
		t.Error("SortFunc failed on large array")
	}
}
