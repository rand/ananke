// Package sort implements external merge sort for large datasets
package sort

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// ExternalSorter sorts data that doesn't fit in memory
type ExternalSorter struct {
	tempDir     string
	chunkSize   int
	maxChunks   int
	tempFiles   []string
	comparator  func(a, b int64) int
}

// NewExternalSorter creates a new external sorter
func NewExternalSorter(tempDir string, chunkSize int) (*ExternalSorter, error) {
	if err := os.MkdirAll(tempDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create temp dir: %w", err)
	}

	return &ExternalSorter{
		tempDir:   tempDir,
		chunkSize: chunkSize,
		maxChunks: 16,
		comparator: func(a, b int64) int {
			if a < b {
				return -1
			}
			if a > b {
				return 1
			}
			return 0
		},
	}, nil
}

// SetComparator sets a custom comparator
func (es *ExternalSorter) SetComparator(cmp func(a, b int64) int) {
	es.comparator = cmp
}

// Sort performs external merge sort on the input
func (es *ExternalSorter) Sort(input []int64) ([]int64, error) {
	// If fits in memory, just sort in-place
	if len(input) <= es.chunkSize {
		result := make([]int64, len(input))
		copy(result, input)
		es.sortChunk(result)
		return result, nil
	}

	// Split into sorted chunks
	if err := es.createSortedChunks(input); err != nil {
		return nil, err
	}
	defer es.cleanup()

	// Merge all chunks
	return es.mergeAllChunks()
}

// SortFile sorts a file of int64 values
func (es *ExternalSorter) SortFile(inputPath, outputPath string) error {
	// Read input file
	input, err := es.readFile(inputPath)
	if err != nil {
		return err
	}

	// Sort
	result, err := es.Sort(input)
	if err != nil {
		return err
	}

	// Write output
	return es.writeFile(outputPath, result)
}

func (es *ExternalSorter) createSortedChunks(input []int64) error {
	for i := 0; i < len(input); i += es.chunkSize {
		end := i + es.chunkSize
		if end > len(input) {
			end = len(input)
		}

		chunk := make([]int64, end-i)
		copy(chunk, input[i:end])
		es.sortChunk(chunk)

		tempFile := filepath.Join(es.tempDir, fmt.Sprintf("chunk_%d.tmp", len(es.tempFiles)))
		if err := es.writeFile(tempFile, chunk); err != nil {
			return err
		}
		es.tempFiles = append(es.tempFiles, tempFile)
	}
	return nil
}

func (es *ExternalSorter) sortChunk(chunk []int64) {
	// Quicksort the chunk
	quicksortInt64(chunk, 0, len(chunk)-1, es.comparator)
}

func quicksortInt64(arr []int64, lo, hi int, cmp func(a, b int64) int) {
	if lo >= hi {
		return
	}

	pivot := arr[hi]
	i := lo - 1
	for j := lo; j < hi; j++ {
		if cmp(arr[j], pivot) <= 0 {
			i++
			arr[i], arr[j] = arr[j], arr[i]
		}
	}
	arr[i+1], arr[hi] = arr[hi], arr[i+1]
	pivotIdx := i + 1

	quicksortInt64(arr, lo, pivotIdx-1, cmp)
	quicksortInt64(arr, pivotIdx+1, hi, cmp)
}

func (es *ExternalSorter) mergeAllChunks() ([]int64, error) {
	// Iteratively merge until one chunk remains
	mergePass := 0
	for len(es.tempFiles) > 1 {
		var newFiles []string

		for i := 0; i < len(es.tempFiles); i += es.maxChunks {
			end := i + es.maxChunks
			if end > len(es.tempFiles) {
				end = len(es.tempFiles)
			}

			files := es.tempFiles[i:end]
			outputFile := filepath.Join(es.tempDir, fmt.Sprintf("merged_%d_%d.tmp", mergePass, len(newFiles)))

			if err := es.mergeFiles(files, outputFile); err != nil {
				return nil, err
			}

			// Remove merged files
			for _, f := range files {
				os.Remove(f)
			}

			newFiles = append(newFiles, outputFile)
		}

		es.tempFiles = newFiles
		mergePass++
	}

	// Read final result
	if len(es.tempFiles) == 0 {
		return nil, nil
	}

	return es.readFile(es.tempFiles[0])
}

func (es *ExternalSorter) mergeFiles(inputFiles []string, outputFile string) error {
	// Open all input files
	readers := make([]*chunkReader, 0, len(inputFiles))
	for _, f := range inputFiles {
		r, err := newChunkReader(f)
		if err != nil {
			for _, cr := range readers {
				cr.Close()
			}
			return err
		}
		readers = append(readers, r)
	}
	defer func() {
		for _, r := range readers {
			r.Close()
		}
	}()

	// Create output file
	out, err := os.Create(outputFile)
	if err != nil {
		return err
	}
	defer out.Close()

	writer := bufio.NewWriter(out)

	// K-way merge
	if err := es.kWayMerge(readers, writer); err != nil {
		return err
	}

	// Flush before closing
	return writer.Flush()
}

func (es *ExternalSorter) kWayMerge(readers []*chunkReader, writer *bufio.Writer) error {
	// Initialize heap with first element from each reader
	heap := &minHeap{
		items: make([]heapItem, 0),
		cmp:   es.comparator,
	}

	for i, r := range readers {
		if val, ok := r.Next(); ok {
			heap.Push(heapItem{value: val, index: i})
		}
	}

	for heap.Len() > 0 {
		// Get minimum
		min := heap.Pop()

		// Write to output
		if err := binary.Write(writer, binary.LittleEndian, min.value); err != nil {
			return err
		}

		// Get next from same reader
		if val, ok := readers[min.index].Next(); ok {
			heap.Push(heapItem{value: val, index: min.index})
		}
	}

	return nil
}

type heapItem struct {
	value int64
	index int
}

type minHeap struct {
	items []heapItem
	cmp   func(a, b int64) int
}

func (h *minHeap) Len() int { return len(h.items) }

func (h *minHeap) Push(item heapItem) {
	h.items = append(h.items, item)
	h.siftUp(len(h.items) - 1)
}

func (h *minHeap) Pop() heapItem {
	if len(h.items) == 0 {
		return heapItem{}
	}
	min := h.items[0]
	last := len(h.items) - 1
	h.items[0] = h.items[last]
	h.items = h.items[:last]
	if len(h.items) > 0 {
		h.siftDown(0)
	}
	return min
}

func (h *minHeap) siftUp(i int) {
	for i > 0 {
		parent := (i - 1) / 2
		if h.cmp(h.items[i].value, h.items[parent].value) >= 0 {
			break
		}
		h.items[i], h.items[parent] = h.items[parent], h.items[i]
		i = parent
	}
}

func (h *minHeap) siftDown(i int) {
	for {
		left := 2*i + 1
		right := 2*i + 2
		smallest := i

		if left < len(h.items) && h.cmp(h.items[left].value, h.items[smallest].value) < 0 {
			smallest = left
		}
		if right < len(h.items) && h.cmp(h.items[right].value, h.items[smallest].value) < 0 {
			smallest = right
		}

		if smallest == i {
			break
		}

		h.items[i], h.items[smallest] = h.items[smallest], h.items[i]
		i = smallest
	}
}

type chunkReader struct {
	file   *os.File
	reader *bufio.Reader
}

func newChunkReader(path string) (*chunkReader, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	return &chunkReader{
		file:   f,
		reader: bufio.NewReader(f),
	}, nil
}

func (cr *chunkReader) Next() (int64, bool) {
	var val int64
	err := binary.Read(cr.reader, binary.LittleEndian, &val)
	if err == io.EOF {
		return 0, false
	}
	if err != nil {
		return 0, false
	}
	return val, true
}

func (cr *chunkReader) Close() {
	cr.file.Close()
}

func (es *ExternalSorter) readFile(path string) ([]int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return nil, err
	}

	count := info.Size() / 8
	result := make([]int64, 0, count)

	reader := bufio.NewReader(f)
	for {
		var val int64
		err := binary.Read(reader, binary.LittleEndian, &val)
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		result = append(result, val)
	}

	return result, nil
}

func (es *ExternalSorter) writeFile(path string, data []int64) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()

	writer := bufio.NewWriter(f)

	for _, val := range data {
		if err := binary.Write(writer, binary.LittleEndian, val); err != nil {
			return err
		}
	}

	// Flush before file close
	return writer.Flush()
}

func (es *ExternalSorter) cleanup() {
	for _, f := range es.tempFiles {
		os.Remove(f)
	}
	es.tempFiles = nil
}

// Cleanup removes all temporary files
func (es *ExternalSorter) Cleanup() error {
	return os.RemoveAll(es.tempDir)
}
