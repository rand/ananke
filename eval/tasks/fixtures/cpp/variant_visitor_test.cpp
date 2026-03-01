/**
 * Variant Tests
 * Compile with: g++ -std=c++17 -o variant_visitor_test variant_visitor_test.cpp && ./variant_visitor_test
 */

#include <iostream>
#include <cassert>
#include <string>
#include <vector>

#include "variant_visitor.cpp"

#define TEST(name) void test_##name()
#define RUN_TEST(name) do { \
    std::cout << "  Testing " #name "..."; \
    test_##name(); \
    std::cout << " PASSED" << std::endl; \
} while(0)

// Track destructor calls
static int destructor_count = 0;

struct TestObject {
    int value;
    TestObject(int v = 0) : value(v) {}
    TestObject(const TestObject& other) : value(other.value) {}
    TestObject(TestObject&& other) noexcept : value(other.value) { other.value = -1; }
    ~TestObject() { ++destructor_count; }
};

TEST(default_construction) {
    Variant<int, double, std::string> v;
    assert(v.index() == 0);
    assert(v.get<int>() == 0);
}

TEST(value_construction) {
    Variant<int, double, std::string> v1(42);
    assert(v1.index() == 0);
    assert(v1.get<int>() == 42);

    Variant<int, double, std::string> v2(3.14);
    assert(v2.index() == 1);
    assert(v2.get<double>() == 3.14);

    Variant<int, double, std::string> v3(std::string("hello"));
    assert(v3.index() == 2);
    assert(v3.get<std::string>() == "hello");
}

TEST(copy_construction) {
    Variant<int, std::string> v1(std::string("hello"));
    Variant<int, std::string> v2(v1);

    assert(v2.index() == 1);
    assert(v2.get<std::string>() == "hello");
}

TEST(move_construction) {
    Variant<int, std::string> v1(std::string("hello"));
    Variant<int, std::string> v2(std::move(v1));

    assert(v2.index() == 1);
    assert(v2.get<std::string>() == "hello");
}

TEST(copy_assignment) {
    Variant<int, std::string> v1(42);
    Variant<int, std::string> v2(std::string("hello"));

    v1 = v2;
    assert(v1.index() == 1);
    assert(v1.get<std::string>() == "hello");
}

TEST(move_assignment) {
    Variant<int, std::string> v1(42);
    Variant<int, std::string> v2(std::string("hello"));

    v1 = std::move(v2);
    assert(v1.index() == 1);
    assert(v1.get<std::string>() == "hello");
}

TEST(value_assignment) {
    Variant<int, double, std::string> v(42);

    v = 3.14;
    assert(v.index() == 1);
    assert(v.get<double>() == 3.14);

    v = std::string("hello");
    assert(v.index() == 2);
    assert(v.get<std::string>() == "hello");
}

TEST(holds_alternative) {
    Variant<int, double, std::string> v(42);

    assert(v.holds_alternative<int>());
    assert(!v.holds_alternative<double>());
    assert(!v.holds_alternative<std::string>());

    v = 3.14;
    assert(!v.holds_alternative<int>());
    assert(v.holds_alternative<double>());
}

TEST(get_throws_on_wrong_type) {
    Variant<int, std::string> v(42);

    try {
        v.get<std::string>();
        assert(false);  // Should throw
    } catch (const bad_variant_access&) {
        // Expected
    }
}

TEST(get_if) {
    Variant<int, std::string> v(42);

    int* p1 = v.get_if<int>();
    assert(p1 != nullptr);
    assert(*p1 == 42);

    std::string* p2 = v.get_if<std::string>();
    assert(p2 == nullptr);
}

TEST(emplace) {
    Variant<int, std::string> v(42);

    v.emplace<std::string>("hello");
    assert(v.index() == 1);
    assert(v.get<std::string>() == "hello");

    v.emplace<std::string>(5, 'x');  // string(5, 'x') = "xxxxx"
    assert(v.get<std::string>() == "xxxxx");
}

TEST(destructor_called) {
    destructor_count = 0;

    {
        Variant<int, TestObject> v(TestObject(42));
        assert(v.get<TestObject>().value == 42);
    }

    // Destructor should have been called for temporary and stored object
    assert(destructor_count >= 1);
}

TEST(destructor_on_reassignment) {
    destructor_count = 0;

    Variant<int, TestObject> v(TestObject(42));
    int before = destructor_count;

    v = 100;  // Assign int, should destroy TestObject

    assert(destructor_count > before);
}

TEST(visit_basic) {
    Variant<int, double, std::string> v(42);

    int result = visit([](auto&& val) -> int {
        using T = std::decay_t<decltype(val)>;
        if constexpr (std::is_same_v<T, int>) {
            return val;
        } else if constexpr (std::is_same_v<T, double>) {
            return static_cast<int>(val);
        } else {
            return static_cast<int>(val.size());
        }
    }, v);

    assert(result == 42);
}

TEST(visit_mutation) {
    Variant<int, std::string> v(42);

    visit([](auto&& val) {
        using T = std::decay_t<decltype(val)>;
        if constexpr (std::is_same_v<T, int>) {
            val = 100;
        }
    }, v);

    assert(v.get<int>() == 100);
}

TEST(overloaded_visitor) {
    Variant<int, double, std::string> v1(42);
    Variant<int, double, std::string> v2(3.14);
    Variant<int, double, std::string> v3(std::string("hello"));

    auto visitor = Overloaded{
        [](int i) { return std::string("int: ") + std::to_string(i); },
        [](double d) { return std::string("double: ") + std::to_string(d); },
        [](const std::string& s) { return std::string("string: ") + s; }
    };

    assert(visit(visitor, v1) == "int: 42");
    assert(visit(visitor, v2).substr(0, 7) == "double:");
    assert(visit(visitor, v3) == "string: hello");
}

TEST(const_variant) {
    const Variant<int, std::string> v(42);

    assert(v.index() == 0);
    assert(v.get<int>() == 42);
    assert(v.holds_alternative<int>());

    const int* p = v.get_if<int>();
    assert(p != nullptr);
    assert(*p == 42);
}

TEST(larger_types) {
    struct Large {
        int data[100];
        Large() { std::fill(std::begin(data), std::end(data), 42); }
    };

    Variant<int, Large> v;
    v.emplace<Large>();

    assert(v.holds_alternative<Large>());
    assert(v.get<Large>().data[0] == 42);
}

int main() {
    std::cout << "Variant Tests:" << std::endl;

    RUN_TEST(default_construction);
    RUN_TEST(value_construction);
    RUN_TEST(copy_construction);
    RUN_TEST(move_construction);
    RUN_TEST(copy_assignment);
    RUN_TEST(move_assignment);
    RUN_TEST(value_assignment);
    RUN_TEST(holds_alternative);
    RUN_TEST(get_throws_on_wrong_type);
    RUN_TEST(get_if);
    RUN_TEST(emplace);
    RUN_TEST(destructor_called);
    RUN_TEST(destructor_on_reassignment);
    RUN_TEST(visit_basic);
    RUN_TEST(visit_mutation);
    RUN_TEST(overloaded_visitor);
    RUN_TEST(const_variant);
    RUN_TEST(larger_types);

    std::cout << "\nAll tests passed!" << std::endl;
    return 0;
}
