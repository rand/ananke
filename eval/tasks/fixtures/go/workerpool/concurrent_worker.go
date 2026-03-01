// Package workerpool implements a concurrent worker pool pattern in Go
package workerpool

import (
	"fmt"
	"runtime/debug"
	"sync"
)

// Job represents a unit of work to be processed
type Job func() interface{}

// Result represents the output of a job
type Result struct {
	Value interface{}
	Err   error
}

// WorkerPool manages a pool of worker goroutines
type WorkerPool struct {
	numWorkers int
	jobs       chan Job
	results    chan Result
	wg         sync.WaitGroup
	once       sync.Once
	closed     bool
	mu         sync.Mutex
}

// NewWorkerPool creates a new worker pool with the specified number of workers
// and buffer size for the job queue
func NewWorkerPool(numWorkers int, bufferSize int) *WorkerPool {
	if numWorkers <= 0 {
		numWorkers = 1
	}
	if bufferSize < 0 {
		bufferSize = 0
	}

	wp := &WorkerPool{
		numWorkers: numWorkers,
		jobs:       make(chan Job, bufferSize),
		results:    make(chan Result, bufferSize),
	}

	// Start workers
	for i := 0; i < numWorkers; i++ {
		wp.wg.Add(1)
		go wp.worker(i)
	}

	return wp
}

// worker processes jobs from the job queue
func (wp *WorkerPool) worker(id int) {
	defer wp.wg.Done()

	for job := range wp.jobs {
		result := wp.safeExecute(job)
		wp.results <- result
	}
}

// safeExecute runs a job and recovers from panics
func (wp *WorkerPool) safeExecute(job Job) (result Result) {
	defer func() {
		if r := recover(); r != nil {
			result = Result{
				Err: fmt.Errorf("panic in worker: %v\n%s", r, debug.Stack()),
			}
		}
	}()

	value := job()
	return Result{Value: value}
}

// Submit adds a job to the worker pool
func (wp *WorkerPool) Submit(job Job) error {
	wp.mu.Lock()
	defer wp.mu.Unlock()

	if wp.closed {
		return fmt.Errorf("worker pool is closed")
	}

	wp.jobs <- job
	return nil
}

// Results returns the results channel for reading completed job results
func (wp *WorkerPool) Results() <-chan Result {
	return wp.results
}

// Wait closes the job queue and waits for all workers to finish
func (wp *WorkerPool) Wait() {
	wp.once.Do(func() {
		wp.mu.Lock()
		wp.closed = true
		wp.mu.Unlock()

		close(wp.jobs)
		wp.wg.Wait()
		close(wp.results)
	})
}

// SubmitAndWait submits multiple jobs and returns all results
func (wp *WorkerPool) SubmitAndWait(jobs []Job) []Result {
	for _, job := range jobs {
		wp.Submit(job)
	}

	go func() {
		wp.Wait()
	}()

	var results []Result
	for result := range wp.results {
		results = append(results, result)
	}
	return results
}

// NumWorkers returns the number of workers in the pool
func (wp *WorkerPool) NumWorkers() int {
	return wp.numWorkers
}

// IsClosed returns whether the pool is closed
func (wp *WorkerPool) IsClosed() bool {
	wp.mu.Lock()
	defer wp.mu.Unlock()
	return wp.closed
}
