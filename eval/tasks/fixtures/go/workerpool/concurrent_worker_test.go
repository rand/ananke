package workerpool

import (
	"sync/atomic"
	"testing"
	"time"
)

func TestNewWorkerPool(t *testing.T) {
	wp := NewWorkerPool(4, 10)
	defer wp.Wait()

	if wp.NumWorkers() != 4 {
		t.Errorf("Expected 4 workers, got %d", wp.NumWorkers())
	}
}

func TestNewWorkerPoolDefaults(t *testing.T) {
	wp := NewWorkerPool(0, -1)
	defer wp.Wait()

	if wp.NumWorkers() != 1 {
		t.Errorf("Expected 1 worker for invalid input, got %d", wp.NumWorkers())
	}
}

func TestSubmitJob(t *testing.T) {
	wp := NewWorkerPool(2, 10)

	err := wp.Submit(func() interface{} {
		return 42
	})
	if err != nil {
		t.Errorf("Submit should not return error: %v", err)
	}

	wp.Wait()
}

func TestResults(t *testing.T) {
	wp := NewWorkerPool(2, 10)

	wp.Submit(func() interface{} { return 1 })
	wp.Submit(func() interface{} { return 2 })
	wp.Submit(func() interface{} { return 3 })

	go wp.Wait()

	var sum int
	for result := range wp.Results() {
		if result.Err != nil {
			t.Errorf("Unexpected error: %v", result.Err)
		}
		sum += result.Value.(int)
	}

	if sum != 6 {
		t.Errorf("Expected sum 6, got %d", sum)
	}
}

func TestPanicRecovery(t *testing.T) {
	wp := NewWorkerPool(2, 10)

	wp.Submit(func() interface{} {
		panic("test panic")
	})

	go wp.Wait()

	result := <-wp.Results()
	if result.Err == nil {
		t.Error("Expected error from panic")
	}
}

func TestSubmitAfterClose(t *testing.T) {
	wp := NewWorkerPool(2, 10)
	wp.Wait()

	err := wp.Submit(func() interface{} { return 1 })
	if err == nil {
		t.Error("Expected error when submitting to closed pool")
	}
}

func TestConcurrentExecution(t *testing.T) {
	wp := NewWorkerPool(4, 100)

	var counter int64
	for i := 0; i < 100; i++ {
		wp.Submit(func() interface{} {
			atomic.AddInt64(&counter, 1)
			return nil
		})
	}

	wp.Wait()

	if counter != 100 {
		t.Errorf("Expected counter 100, got %d", counter)
	}
}

func TestSubmitAndWait(t *testing.T) {
	wp := NewWorkerPool(4, 10)

	jobs := []Job{
		func() interface{} { return 1 },
		func() interface{} { return 2 },
		func() interface{} { return 3 },
	}

	results := wp.SubmitAndWait(jobs)

	if len(results) != 3 {
		t.Errorf("Expected 3 results, got %d", len(results))
	}

	sum := 0
	for _, r := range results {
		sum += r.Value.(int)
	}
	if sum != 6 {
		t.Errorf("Expected sum 6, got %d", sum)
	}
}

func TestIsClosed(t *testing.T) {
	wp := NewWorkerPool(2, 10)

	if wp.IsClosed() {
		t.Error("Pool should not be closed initially")
	}

	wp.Wait()

	if !wp.IsClosed() {
		t.Error("Pool should be closed after Wait")
	}
}

func TestWorkerPoolWithDelay(t *testing.T) {
	wp := NewWorkerPool(2, 10)

	start := time.Now()

	for i := 0; i < 4; i++ {
		wp.Submit(func() interface{} {
			time.Sleep(50 * time.Millisecond)
			return nil
		})
	}

	wp.Wait()

	elapsed := time.Since(start)
	// With 2 workers and 4 jobs of 50ms each, should take ~100ms
	if elapsed > 200*time.Millisecond {
		t.Errorf("Jobs should run concurrently, took %v", elapsed)
	}
}

func TestMultipleWaitCalls(t *testing.T) {
	wp := NewWorkerPool(2, 10)

	wp.Submit(func() interface{} { return 1 })

	// Call Wait multiple times - should be safe
	wp.Wait()
	wp.Wait()
	wp.Wait()
}

func TestEmptyPool(t *testing.T) {
	wp := NewWorkerPool(2, 10)
	wp.Wait()

	// Should complete without blocking
	count := 0
	for range wp.Results() {
		count++
	}
	if count != 0 {
		t.Errorf("Expected 0 results, got %d", count)
	}
}
