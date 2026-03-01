package sort

import (
	"math/rand"
	"os"
	"path/filepath"
	"testing"
)

func TestNewExternalSorter(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_test")
	defer os.RemoveAll(tempDir)

	sorter, err := NewExternalSorter(tempDir, 100)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}
	defer sorter.Cleanup()

	if sorter.chunkSize != 100 {
		t.Errorf("Expected chunk size 100, got %d", sorter.chunkSize)
	}
}

func TestExternalSorterSmallArray(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_small")
	defer os.RemoveAll(tempDir)

	sorter, err := NewExternalSorter(tempDir, 1000)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}
	defer sorter.Cleanup()

	input := []int64{5, 2, 8, 1, 9, 3, 7, 4, 6}
	result, err := sorter.Sort(input)
	if err != nil {
		t.Fatalf("Sort failed: %v", err)
	}

	expected := []int64{1, 2, 3, 4, 5, 6, 7, 8, 9}
	for i, v := range result {
		if v != expected[i] {
			t.Errorf("Result[%d] = %d, want %d", i, v, expected[i])
		}
	}
}

func TestExternalSorterLargeArray(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_large")
	defer os.RemoveAll(tempDir)

	sorter, err := NewExternalSorter(tempDir, 100)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}
	defer sorter.Cleanup()

	// Create array larger than chunk size
	input := make([]int64, 500)
	for i := range input {
		input[i] = int64(rand.Intn(10000))
	}

	result, err := sorter.Sort(input)
	if err != nil {
		t.Fatalf("Sort failed: %v", err)
	}

	if len(result) != len(input) {
		t.Errorf("Result length %d != input length %d", len(result), len(input))
	}

	// Check sorted
	for i := 1; i < len(result); i++ {
		if result[i] < result[i-1] {
			t.Errorf("Result not sorted at index %d", i)
		}
	}
}

func TestExternalSorterEmptyArray(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_empty")
	defer os.RemoveAll(tempDir)

	sorter, err := NewExternalSorter(tempDir, 100)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}
	defer sorter.Cleanup()

	result, err := sorter.Sort([]int64{})
	if err != nil {
		t.Fatalf("Sort failed: %v", err)
	}

	if len(result) != 0 {
		t.Errorf("Empty input should produce empty result")
	}
}

func TestExternalSorterSingleElement(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_single")
	defer os.RemoveAll(tempDir)

	sorter, err := NewExternalSorter(tempDir, 100)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}
	defer sorter.Cleanup()

	result, err := sorter.Sort([]int64{42})
	if err != nil {
		t.Fatalf("Sort failed: %v", err)
	}

	if len(result) != 1 || result[0] != 42 {
		t.Error("Single element should be unchanged")
	}
}

func TestExternalSorterDuplicates(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_dup")
	defer os.RemoveAll(tempDir)

	sorter, err := NewExternalSorter(tempDir, 10)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}
	defer sorter.Cleanup()

	input := []int64{3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3, 2, 3, 8, 4, 6, 2, 6, 4, 3, 3}
	result, err := sorter.Sort(input)
	if err != nil {
		t.Fatalf("Sort failed: %v", err)
	}

	// Check sorted
	for i := 1; i < len(result); i++ {
		if result[i] < result[i-1] {
			t.Errorf("Result not sorted at index %d", i)
		}
	}

	// Check count preserved
	if len(result) != len(input) {
		t.Errorf("Length mismatch: %d vs %d", len(result), len(input))
	}
}

func TestExternalSorterDescending(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_desc")
	defer os.RemoveAll(tempDir)

	sorter, err := NewExternalSorter(tempDir, 10)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}
	defer sorter.Cleanup()

	sorter.SetComparator(func(a, b int64) int {
		if a > b {
			return -1
		}
		if a < b {
			return 1
		}
		return 0
	})

	input := []int64{5, 2, 8, 1, 9, 3, 7, 4, 6, 10, 11, 12, 13, 14, 15}
	result, err := sorter.Sort(input)
	if err != nil {
		t.Fatalf("Sort failed: %v", err)
	}

	// Check descending order
	for i := 1; i < len(result); i++ {
		if result[i] > result[i-1] {
			t.Errorf("Result not sorted descending at index %d", i)
		}
	}
}

func TestExternalSorterFile(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_file")
	defer os.RemoveAll(tempDir)

	sorter, err := NewExternalSorter(tempDir, 10)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}
	defer sorter.Cleanup()

	// Create input file
	inputFile := filepath.Join(tempDir, "input.bin")
	input := []int64{5, 2, 8, 1, 9, 3, 7, 4, 6}
	if err := sorter.writeFile(inputFile, input); err != nil {
		t.Fatalf("Failed to write input: %v", err)
	}

	// Sort file
	outputFile := filepath.Join(tempDir, "output.bin")
	if err := sorter.SortFile(inputFile, outputFile); err != nil {
		t.Fatalf("SortFile failed: %v", err)
	}

	// Read and verify output
	result, err := sorter.readFile(outputFile)
	if err != nil {
		t.Fatalf("Failed to read output: %v", err)
	}

	expected := []int64{1, 2, 3, 4, 5, 6, 7, 8, 9}
	for i, v := range result {
		if v != expected[i] {
			t.Errorf("Result[%d] = %d, want %d", i, v, expected[i])
		}
	}
}

func TestMinHeap(t *testing.T) {
	h := &minHeap{
		items: make([]heapItem, 0),
		cmp:   func(a, b int64) int { return int(a - b) },
	}

	values := []int64{5, 2, 8, 1, 9, 3, 7, 4, 6}
	for i, v := range values {
		h.Push(heapItem{value: v, index: i})
	}

	if h.Len() != 9 {
		t.Errorf("Heap length should be 9, got %d", h.Len())
	}

	// Should pop in sorted order
	prev := int64(-1)
	for h.Len() > 0 {
		item := h.Pop()
		if item.value <= prev {
			t.Errorf("Heap order violated: %d <= %d", item.value, prev)
		}
		prev = item.value
	}
}

func TestMinHeapEmpty(t *testing.T) {
	h := &minHeap{
		items: make([]heapItem, 0),
		cmp:   func(a, b int64) int { return int(a - b) },
	}

	item := h.Pop()
	if item.value != 0 {
		t.Error("Pop from empty heap should return zero value")
	}
}

func TestExternalSorterMultipleChunks(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_multi")
	defer os.RemoveAll(tempDir)

	// Very small chunk size to test multi-chunk merging
	sorter, err := NewExternalSorter(tempDir, 5)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}
	defer sorter.Cleanup()

	input := make([]int64, 100)
	for i := range input {
		input[i] = int64(100 - i)
	}

	result, err := sorter.Sort(input)
	if err != nil {
		t.Fatalf("Sort failed: %v", err)
	}

	// Verify sorted
	for i := 1; i < len(result); i++ {
		if result[i] < result[i-1] {
			t.Errorf("Result not sorted at index %d: %d < %d", i, result[i], result[i-1])
		}
	}
}

func TestExternalSorterCleanup(t *testing.T) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_cleanup")

	sorter, err := NewExternalSorter(tempDir, 10)
	if err != nil {
		t.Fatalf("Failed to create sorter: %v", err)
	}

	// Create some data
	input := make([]int64, 50)
	for i := range input {
		input[i] = int64(i)
	}
	sorter.Sort(input)

	// Cleanup
	if err := sorter.Cleanup(); err != nil {
		t.Fatalf("Cleanup failed: %v", err)
	}

	// Directory should be removed
	if _, err := os.Stat(tempDir); !os.IsNotExist(err) {
		t.Error("Temp directory should be removed after cleanup")
	}
}

func BenchmarkExternalSort(b *testing.B) {
	tempDir := filepath.Join(os.TempDir(), "ext_sort_bench")
	defer os.RemoveAll(tempDir)

	input := make([]int64, 10000)
	for i := range input {
		input[i] = int64(rand.Intn(1000000))
	}

	for i := 0; i < b.N; i++ {
		sorter, _ := NewExternalSorter(filepath.Join(tempDir, string(rune(i))), 1000)
		sorter.Sort(input)
		sorter.Cleanup()
	}
}
