package config

import (
	"log"
	"sync"
	"time"
)

// Task represents a work item to be processed by the pool
type Task struct {
	ID      int
	Payload interface{}
	Handler func(interface{})
}

// WorkerPool is a bounded worker pool with buffered channel
type WorkerPool struct {
	taskChan    chan *Task
	workerCount int
	wg          sync.WaitGroup
	closed      bool
	mu          sync.Mutex
}

// NewWorkerPool creates a new worker pool with the specified number of workers and buffer size
func NewWorkerPool(workerCount, bufferSize int) *WorkerPool {
	pool := &WorkerPool{
		taskChan:    make(chan *Task, bufferSize),
		workerCount: workerCount,
	}

	// Start worker goroutines
	for i := 0; i < workerCount; i++ {
		pool.wg.Add(1)
		go pool.worker(i)
	}

	log.Printf("📦 Worker pool initialized with %d workers, buffer size %d", workerCount, bufferSize)
	return pool
}

// worker is the main loop for each worker goroutine
func (p *WorkerPool) worker(id int) {
	defer p.wg.Done()

	for task := range p.taskChan {
		if task != nil && task.Handler != nil {
			// Recover from panics to prevent worker crash
			defer func() {
				if r := recover(); r != nil {
					log.Printf("⚠️  Worker %d recovered from panic: %v", id, r)
				}
			}()
			task.Handler(task.Payload)
		}
	}
}

// Submit adds a task to the pool's work queue
// Returns false if the pool is closed or the buffer is full (non-blocking)
func (p *WorkerPool) Submit(handler func(interface{}), payload interface{}) bool {
	p.mu.Lock()
	if p.closed {
		p.mu.Unlock()
		return false
	}
	p.mu.Unlock()

	select {
	case p.taskChan <- &Task{Payload: payload, Handler: handler}:
		return true
	default:
		// Buffer is full - backpressure applied
		log.Printf("⚠️  Worker pool buffer full, task rejected (backpressure)")
		return false
	}
}

// Close gracefully shuts down the worker pool
func (p *WorkerPool) Close() {
	p.mu.Lock()
	if p.closed {
		p.mu.Unlock()
		return
	}
	p.closed = true
	close(p.taskChan)
	p.mu.Unlock()

	p.wg.Wait()
	log.Println("📦 Worker pool closed")
}

// PendingTasks returns the number of pending tasks in the buffer
func (p *WorkerPool) PendingTasks() int {
	return len(p.taskChan)
}

// Global worker pools for different operation types
var (
	// MessagePersistencePool handles message saves (buffer: 1000, workers: 10)
	MessagePersistencePool *WorkerPool

	// ReadReceiptPool handles read receipt updates (buffer: 500, workers: 5)
	ReadReceiptPool *WorkerPool
)

// InitWorkerPools initializes global worker pools
func InitWorkerPools() {
	MessagePersistencePool = NewWorkerPool(10, 1000)
	ReadReceiptPool = NewWorkerPool(5, 500)
	log.Println("✅ Global worker pools initialized")
}

// CloseWorkerPools closes all global worker pools
func CloseWorkerPools() {
	if MessagePersistencePool != nil {
		MessagePersistencePool.Close()
	}
	if ReadReceiptPool != nil {
		ReadReceiptPool.Close()
	}
}

// TaskWithTimeout wraps a handler with a timeout
func TaskWithTimeout(handler func(interface{}), payload interface{}, timeout time.Duration) func(interface{}) {
	return func(p interface{}) {
		done := make(chan struct{})
		go func() {
			handler(p)
			close(done)
		}()
		select {
		case <-done:
			return
		case <-time.After(timeout):
			log.Printf("⚠️  Task timed out after %v", timeout)
		}
	}
}
