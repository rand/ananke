/**
 * ThreadPool Tests
 * Compile with: g++ -std=c++17 -pthread -o thread_pool_test thread_pool_test.cpp && ./thread_pool_test
 */

#include <iostream>
#include <cassert>
#include <atomic>
#include <chrono>
#include <numeric>

#include "thread_pool.cpp"

#define TEST(name) void test_##name()
#define RUN_TEST(name) do { \
    std::cout << "  Testing " #name "..."; \
    test_##name(); \
    std::cout << " PASSED" << std::endl; \
} while(0)

using namespace std::chrono_literals;

TEST(construction) {
    ThreadPool pool(4);
    assert(pool.size() == 4);
    assert(!pool.stopped());
}

TEST(invalid_size) {
    try {
        ThreadPool pool(0);
        assert(false);  // Should throw
    } catch (const std::invalid_argument&) {
        // Expected
    }
}

TEST(submit_single_task) {
    ThreadPool pool(2);

    auto future = pool.submit([]() { return 42; });
    assert(future.get() == 42);
}

TEST(submit_with_args) {
    ThreadPool pool(2);

    auto future = pool.submit([](int a, int b) { return a + b; }, 10, 20);
    assert(future.get() == 30);
}

TEST(submit_multiple_tasks) {
    ThreadPool pool(4);

    std::vector<std::future<int>> futures;
    for (int i = 0; i < 100; ++i) {
        futures.push_back(pool.submit([i]() { return i * 2; }));
    }

    for (int i = 0; i < 100; ++i) {
        assert(futures[i].get() == i * 2);
    }
}

TEST(execute_fire_and_forget) {
    ThreadPool pool(2);
    std::atomic<int> counter{0};

    for (int i = 0; i < 10; ++i) {
        pool.execute([&counter]() { ++counter; });
    }

    // Wait for tasks to complete
    std::this_thread::sleep_for(100ms);
    assert(counter == 10);
}

TEST(concurrent_execution) {
    ThreadPool pool(4);
    std::atomic<int> max_concurrent{0};
    std::atomic<int> current{0};

    std::vector<std::future<void>> futures;

    for (int i = 0; i < 8; ++i) {
        futures.push_back(pool.submit([&]() {
            int c = ++current;
            int expected = max_concurrent.load();
            while (c > expected && !max_concurrent.compare_exchange_weak(expected, c)) {}

            std::this_thread::sleep_for(50ms);
            --current;
        }));
    }

    for (auto& f : futures) {
        f.get();
    }

    // Should have had up to 4 concurrent tasks
    assert(max_concurrent >= 2);  // At least some concurrency
}

TEST(exception_propagation) {
    ThreadPool pool(2);

    auto future = pool.submit([]() -> int {
        throw std::runtime_error("Test exception");
    });

    try {
        future.get();
        assert(false);  // Should throw
    } catch (const std::runtime_error& e) {
        assert(std::string(e.what()) == "Test exception");
    }
}

TEST(graceful_shutdown) {
    std::atomic<int> completed{0};

    {
        ThreadPool pool(2);

        for (int i = 0; i < 10; ++i) {
            pool.execute([&completed]() {
                std::this_thread::sleep_for(10ms);
                ++completed;
            });
        }

        // Pool destructor should wait for all tasks
    }

    assert(completed == 10);
}

TEST(submit_after_shutdown) {
    ThreadPool pool(2);
    pool.shutdown();

    assert(pool.stopped());

    try {
        pool.submit([]() { return 42; });
        assert(false);  // Should throw
    } catch (const std::runtime_error&) {
        // Expected
    }
}

TEST(pending_count) {
    ThreadPool pool(1);

    std::mutex mtx;
    std::condition_variable cv;
    bool start = false;

    // Submit a blocking task
    pool.execute([&]() {
        std::unique_lock<std::mutex> lock(mtx);
        cv.wait(lock, [&]() { return start; });
    });

    // Give task time to start
    std::this_thread::sleep_for(10ms);

    // Submit more tasks - they should be pending
    for (int i = 0; i < 5; ++i) {
        pool.execute([]() {});
    }

    assert(pool.pending() >= 4);  // At least some pending

    // Release blocking task
    {
        std::lock_guard<std::mutex> lock(mtx);
        start = true;
    }
    cv.notify_one();
}

TEST(parallel_for_each) {
    ThreadPool pool(4);
    std::vector<int> data = {1, 2, 3, 4, 5};
    std::atomic<int> sum{0};

    parallel_for_each(pool, data.begin(), data.end(), [&sum](int x) {
        sum += x;
    });

    assert(sum == 15);
}

TEST(parallel_map) {
    ThreadPool pool(4);
    std::vector<int> data = {1, 2, 3, 4, 5};

    auto results = parallel_map(pool, data, [](int x) { return x * x; });

    assert(results.size() == 5);
    assert(results[0] == 1);
    assert(results[1] == 4);
    assert(results[2] == 9);
    assert(results[3] == 16);
    assert(results[4] == 25);
}

TEST(return_types) {
    ThreadPool pool(2);

    // Void return
    auto f1 = pool.submit([]() {});
    f1.get();

    // Int return
    auto f2 = pool.submit([]() { return 42; });
    assert(f2.get() == 42);

    // String return
    auto f3 = pool.submit([]() { return std::string("hello"); });
    assert(f3.get() == "hello");

    // Vector return
    auto f4 = pool.submit([]() { return std::vector<int>{1, 2, 3}; });
    auto v = f4.get();
    assert(v.size() == 3);
}

int main() {
    std::cout << "ThreadPool Tests:" << std::endl;

    RUN_TEST(construction);
    RUN_TEST(invalid_size);
    RUN_TEST(submit_single_task);
    RUN_TEST(submit_with_args);
    RUN_TEST(submit_multiple_tasks);
    RUN_TEST(execute_fire_and_forget);
    RUN_TEST(concurrent_execution);
    RUN_TEST(exception_propagation);
    RUN_TEST(graceful_shutdown);
    RUN_TEST(submit_after_shutdown);
    RUN_TEST(pending_count);
    RUN_TEST(parallel_for_each);
    RUN_TEST(parallel_map);
    RUN_TEST(return_types);

    std::cout << "\nAll tests passed!" << std::endl;
    return 0;
}
