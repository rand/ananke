/**
 * SharedPtr Tests
 * Compile with: g++ -std=c++17 -o smart_ptr_test smart_ptr_test.cpp && ./smart_ptr_test
 */

#include <iostream>
#include <cassert>
#include <string>
#include <vector>

#include "smart_ptr.cpp"

#define TEST(name) void test_##name()
#define RUN_TEST(name) do { \
    std::cout << "  Testing " #name "..."; \
    test_##name(); \
    std::cout << " PASSED" << std::endl; \
} while(0)

// Test helper to track destructor calls
static int destructor_count = 0;

struct TestObject {
    int value;
    TestObject(int v = 0) : value(v) {}
    ~TestObject() { ++destructor_count; }
};

TEST(default_constructor) {
    SharedPtr<int> ptr;
    assert(!ptr);
    assert(ptr.get() == nullptr);
    assert(ptr.use_count() == 0);
}

TEST(nullptr_constructor) {
    SharedPtr<int> ptr(nullptr);
    assert(!ptr);
    assert(ptr.use_count() == 0);
}

TEST(raw_pointer_constructor) {
    SharedPtr<int> ptr(new int(42));
    assert(ptr);
    assert(*ptr == 42);
    assert(ptr.use_count() == 1);
}

TEST(copy_constructor) {
    SharedPtr<int> ptr1(new int(42));
    SharedPtr<int> ptr2(ptr1);

    assert(ptr1.get() == ptr2.get());
    assert(ptr1.use_count() == 2);
    assert(ptr2.use_count() == 2);
}

TEST(move_constructor) {
    SharedPtr<int> ptr1(new int(42));
    int* raw = ptr1.get();
    SharedPtr<int> ptr2(std::move(ptr1));

    assert(!ptr1);
    assert(ptr1.use_count() == 0);
    assert(ptr2.get() == raw);
    assert(ptr2.use_count() == 1);
}

TEST(copy_assignment) {
    SharedPtr<int> ptr1(new int(42));
    SharedPtr<int> ptr2;
    ptr2 = ptr1;

    assert(ptr1.get() == ptr2.get());
    assert(ptr1.use_count() == 2);
}

TEST(move_assignment) {
    SharedPtr<int> ptr1(new int(42));
    SharedPtr<int> ptr2;
    int* raw = ptr1.get();
    ptr2 = std::move(ptr1);

    assert(!ptr1);
    assert(ptr2.get() == raw);
    assert(ptr2.use_count() == 1);
}

TEST(nullptr_assignment) {
    SharedPtr<int> ptr(new int(42));
    ptr = nullptr;

    assert(!ptr);
    assert(ptr.use_count() == 0);
}

TEST(destructor_cleanup) {
    destructor_count = 0;
    {
        SharedPtr<TestObject> ptr1(new TestObject(42));
        {
            SharedPtr<TestObject> ptr2 = ptr1;
            assert(destructor_count == 0);  // Not destroyed yet
        }
        assert(destructor_count == 0);  // ptr1 still holds reference
    }
    assert(destructor_count == 1);  // Destroyed when ptr1 goes out of scope
}

TEST(dereference_operators) {
    struct Point { int x, y; };
    SharedPtr<Point> ptr(new Point{10, 20});

    assert((*ptr).x == 10);
    assert(ptr->y == 20);
}

TEST(reset_empty) {
    destructor_count = 0;
    SharedPtr<TestObject> ptr(new TestObject(42));
    ptr.reset();

    assert(!ptr);
    assert(destructor_count == 1);
}

TEST(reset_new_pointer) {
    destructor_count = 0;
    SharedPtr<TestObject> ptr(new TestObject(42));
    ptr.reset(new TestObject(100));

    assert(ptr);
    assert(ptr->value == 100);
    assert(destructor_count == 1);  // Old object destroyed
}

TEST(swap) {
    SharedPtr<int> ptr1(new int(1));
    SharedPtr<int> ptr2(new int(2));

    ptr1.swap(ptr2);

    assert(*ptr1 == 2);
    assert(*ptr2 == 1);
}

TEST(comparison_operators) {
    SharedPtr<int> ptr1(new int(42));
    SharedPtr<int> ptr2 = ptr1;
    SharedPtr<int> ptr3(new int(42));

    assert(ptr1 == ptr2);
    assert(ptr1 != ptr3);
    assert(ptr1 != nullptr);

    SharedPtr<int> null_ptr;
    assert(null_ptr == nullptr);
}

TEST(make_shared) {
    auto ptr = make_shared<std::string>("hello");
    assert(*ptr == "hello");
    assert(ptr.use_count() == 1);
}

TEST(custom_deleter) {
    static bool custom_deleted = false;
    custom_deleted = false;

    {
        SharedPtr<int> ptr(new int(42), [](int* p) {
            custom_deleted = true;
            delete p;
        });
    }

    assert(custom_deleted);
}

TEST(self_assignment) {
    SharedPtr<int> ptr(new int(42));
    ptr = ptr;  // Self-assignment

    assert(*ptr == 42);
    assert(ptr.use_count() == 1);
}

TEST(circular_reference_prevention) {
    // This test verifies the smart pointer works correctly
    // Note: Actual circular reference handling would need weak_ptr
    destructor_count = 0;

    {
        SharedPtr<TestObject> ptr1(new TestObject(1));
        SharedPtr<TestObject> ptr2(new TestObject(2));

        // Create chain but not circular
        assert(ptr1.use_count() == 1);
        assert(ptr2.use_count() == 1);
    }

    assert(destructor_count == 2);
}

TEST(with_vector) {
    std::vector<SharedPtr<int>> vec;

    vec.push_back(make_shared<int>(1));
    vec.push_back(make_shared<int>(2));
    vec.push_back(make_shared<int>(3));

    assert(vec.size() == 3);
    assert(*vec[0] == 1);
    assert(*vec[1] == 2);
    assert(*vec[2] == 3);
}

int main() {
    std::cout << "SharedPtr Tests:" << std::endl;

    RUN_TEST(default_constructor);
    RUN_TEST(nullptr_constructor);
    RUN_TEST(raw_pointer_constructor);
    RUN_TEST(copy_constructor);
    RUN_TEST(move_constructor);
    RUN_TEST(copy_assignment);
    RUN_TEST(move_assignment);
    RUN_TEST(nullptr_assignment);
    RUN_TEST(destructor_cleanup);
    RUN_TEST(dereference_operators);
    RUN_TEST(reset_empty);
    RUN_TEST(reset_new_pointer);
    RUN_TEST(swap);
    RUN_TEST(comparison_operators);
    RUN_TEST(make_shared);
    RUN_TEST(custom_deleter);
    RUN_TEST(self_assignment);
    RUN_TEST(circular_reference_prevention);
    RUN_TEST(with_vector);

    std::cout << "\nAll tests passed!" << std::endl;
    return 0;
}
