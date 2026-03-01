/**
 * Thread Pool with Future Support
 * Modern C++ thread pool using std::packaged_task and futures.
 */

#ifndef THREAD_POOL_HPP
#define THREAD_POOL_HPP

#include <vector>
#include <queue>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <future>
#include <functional>
#include <stdexcept>
#include <type_traits>

class ThreadPool {
private:
    std::vector<std::thread> workers_;
    std::queue<std::function<void()>> tasks_;

    std::mutex mutex_;
    std::condition_variable cv_;
    bool stop_{false};

    void worker_thread() {
        while (true) {
            std::function<void()> task;

            {
                std::unique_lock<std::mutex> lock(mutex_);
                cv_.wait(lock, [this] {
                    return stop_ || !tasks_.empty();
                });

                if (stop_ && tasks_.empty()) {
                    return;
                }

                task = std::move(tasks_.front());
                tasks_.pop();
            }

            task();
        }
    }

public:
    explicit ThreadPool(size_t num_threads) {
        if (num_threads == 0) {
            throw std::invalid_argument("Thread pool must have at least one thread");
        }

        workers_.reserve(num_threads);
        for (size_t i = 0; i < num_threads; ++i) {
            workers_.emplace_back(&ThreadPool::worker_thread, this);
        }
    }

    ~ThreadPool() {
        shutdown();
    }

    // Non-copyable
    ThreadPool(const ThreadPool&) = delete;
    ThreadPool& operator=(const ThreadPool&) = delete;

    // Submit a task and return a future for the result
    template<typename F, typename... Args>
    auto submit(F&& f, Args&&... args)
        -> std::future<typename std::invoke_result<F, Args...>::type>
    {
        using return_type = typename std::invoke_result<F, Args...>::type;

        auto task = std::make_shared<std::packaged_task<return_type()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<return_type> result = task->get_future();

        {
            std::lock_guard<std::mutex> lock(mutex_);

            if (stop_) {
                throw std::runtime_error("Cannot submit to stopped thread pool");
            }

            tasks_.emplace([task]() { (*task)(); });
        }

        cv_.notify_one();
        return result;
    }

    // Submit a task without caring about the result
    template<typename F, typename... Args>
    void execute(F&& f, Args&&... args) {
        auto task = std::bind(std::forward<F>(f), std::forward<Args>(args)...);

        {
            std::lock_guard<std::mutex> lock(mutex_);

            if (stop_) {
                throw std::runtime_error("Cannot submit to stopped thread pool");
            }

            tasks_.emplace([task = std::move(task)]() { task(); });
        }

        cv_.notify_one();
    }

    // Graceful shutdown
    void shutdown() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (stop_) return;
            stop_ = true;
        }

        cv_.notify_all();

        for (auto& worker : workers_) {
            if (worker.joinable()) {
                worker.join();
            }
        }
    }

    // Get number of worker threads
    size_t size() const noexcept {
        return workers_.size();
    }

    // Get number of pending tasks
    size_t pending() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return tasks_.size();
    }

    // Check if pool is stopped
    bool stopped() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return stop_;
    }
};

// Parallel for-each using thread pool
template<typename Iterator, typename Func>
void parallel_for_each(ThreadPool& pool, Iterator begin, Iterator end, Func&& f) {
    std::vector<std::future<void>> futures;

    for (auto it = begin; it != end; ++it) {
        futures.push_back(pool.submit([&f, it]() { f(*it); }));
    }

    for (auto& future : futures) {
        future.get();  // Wait for completion and propagate exceptions
    }
}

// Parallel map using thread pool
template<typename Container, typename Func>
auto parallel_map(ThreadPool& pool, const Container& input, Func&& f)
    -> std::vector<typename std::invoke_result<Func, typename Container::value_type>::type>
{
    using result_type = typename std::invoke_result<Func, typename Container::value_type>::type;

    std::vector<std::future<result_type>> futures;
    futures.reserve(input.size());

    for (const auto& item : input) {
        futures.push_back(pool.submit(f, item));
    }

    std::vector<result_type> results;
    results.reserve(futures.size());

    for (auto& future : futures) {
        results.push_back(future.get());
    }

    return results;
}

#endif // THREAD_POOL_HPP
