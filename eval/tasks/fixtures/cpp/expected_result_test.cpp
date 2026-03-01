/**
 * Expected Tests
 * Compile with: g++ -std=c++17 -o expected_result_test expected_result_test.cpp && ./expected_result_test
 */

#include <iostream>
#include <cassert>
#include <string>
#include <vector>

#include "expected_result.cpp"

#define TEST(name) void test_##name()
#define RUN_TEST(name) do { \
    std::cout << "  Testing " #name "..."; \
    test_##name(); \
    std::cout << " PASSED" << std::endl; \
} while(0)

TEST(value_construction) {
    Expected<int, std::string> e(42);
    assert(e.has_value());
    assert(e.value() == 42);
}

TEST(error_construction) {
    Expected<int, std::string> e(Unexpected(std::string("error")));
    assert(!e.has_value());
    assert(e.error() == "error");
}

TEST(copy_construction) {
    Expected<int, std::string> e1(42);
    Expected<int, std::string> e2(e1);

    assert(e2.has_value());
    assert(e2.value() == 42);

    Expected<int, std::string> e3(Unexpected(std::string("error")));
    Expected<int, std::string> e4(e3);

    assert(!e4.has_value());
    assert(e4.error() == "error");
}

TEST(move_construction) {
    Expected<std::string, int> e1(std::string("hello"));
    Expected<std::string, int> e2(std::move(e1));

    assert(e2.has_value());
    assert(e2.value() == "hello");
}

TEST(copy_assignment) {
    Expected<int, std::string> e1(42);
    Expected<int, std::string> e2(Unexpected(std::string("error")));

    e2 = e1;
    assert(e2.has_value());
    assert(e2.value() == 42);
}

TEST(move_assignment) {
    Expected<std::string, int> e1(std::string("hello"));
    Expected<std::string, int> e2(Unexpected(42));

    e2 = std::move(e1);
    assert(e2.has_value());
    assert(e2.value() == "hello");
}

TEST(boolean_conversion) {
    Expected<int, std::string> good(42);
    Expected<int, std::string> bad(Unexpected(std::string("error")));

    assert(good);
    assert(!bad);

    if (good) {
        // Should enter here
    } else {
        assert(false);
    }

    if (bad) {
        assert(false);
    } else {
        // Should enter here
    }
}

TEST(value_throws_on_error) {
    Expected<int, std::string> e(Unexpected(std::string("error")));

    try {
        e.value();
        assert(false);  // Should throw
    } catch (const bad_expected_access&) {
        // Expected
    }
}

TEST(error_throws_on_value) {
    Expected<int, std::string> e(42);

    try {
        e.error();
        assert(false);  // Should throw
    } catch (const bad_expected_access&) {
        // Expected
    }
}

TEST(value_or) {
    Expected<int, std::string> good(42);
    Expected<int, std::string> bad(Unexpected(std::string("error")));

    assert(good.value_or(0) == 42);
    assert(bad.value_or(0) == 0);
}

TEST(error_or) {
    Expected<int, std::string> good(42);
    Expected<int, std::string> bad(Unexpected(std::string("error")));

    assert(good.error_or("default") == "default");
    assert(bad.error_or("default") == "error");
}

TEST(dereference) {
    Expected<int, std::string> e(42);

    assert(*e == 42);
    *e = 100;
    assert(*e == 100);

    struct Point { int x, y; };
    Expected<Point, std::string> ep(Point{10, 20});
    assert(ep->x == 10);
    assert(ep->y == 20);
}

TEST(map) {
    Expected<int, std::string> e(42);

    auto result = e.map([](int x) { return x * 2; });
    assert(result.has_value());
    assert(result.value() == 84);

    // Map on error
    Expected<int, std::string> err(Unexpected(std::string("error")));
    auto result2 = err.map([](int x) { return x * 2; });
    assert(!result2.has_value());
    assert(result2.error() == "error");
}

TEST(map_error) {
    Expected<int, std::string> e(Unexpected(std::string("error")));

    auto result = e.map_error([](const std::string& s) {
        return s + " (mapped)";
    });

    assert(!result.has_value());
    assert(result.error() == "error (mapped)");

    // Map error on value
    Expected<int, std::string> good(42);
    auto result2 = good.map_error([](const std::string&) {
        return std::string("shouldn't happen");
    });
    assert(result2.has_value());
    assert(result2.value() == 42);
}

TEST(and_then) {
    auto divide = [](int x) -> Expected<int, std::string> {
        if (x == 0) {
            return Unexpected(std::string("division by zero"));
        }
        return 100 / x;
    };

    Expected<int, std::string> e1(5);
    auto r1 = e1.and_then(divide);
    assert(r1.has_value());
    assert(r1.value() == 20);

    Expected<int, std::string> e2(0);
    auto r2 = e2.and_then(divide);
    assert(!r2.has_value());
    assert(r2.error() == "division by zero");

    // and_then on error
    Expected<int, std::string> err(Unexpected(std::string("initial error")));
    auto r3 = err.and_then(divide);
    assert(!r3.has_value());
    assert(r3.error() == "initial error");
}

TEST(or_else) {
    Expected<int, std::string> e(Unexpected(std::string("error")));

    auto result = e.or_else([](const std::string&) -> Expected<int, std::string> {
        return 0;  // Default value on error
    });

    assert(result.has_value());
    assert(result.value() == 0);

    // or_else on value
    Expected<int, std::string> good(42);
    auto result2 = good.or_else([](const std::string&) -> Expected<int, std::string> {
        return 0;
    });
    assert(result2.has_value());
    assert(result2.value() == 42);
}

TEST(chaining) {
    auto parse_int = [](const std::string& s) -> Expected<int, std::string> {
        try {
            return std::stoi(s);
        } catch (...) {
            return Unexpected(std::string("parse error"));
        }
    };

    auto double_it = [](int x) -> Expected<int, std::string> {
        return x * 2;
    };

    auto result = parse_int("21")
        .and_then(double_it)
        .map([](int x) { return x + 1; });

    assert(result.has_value());
    assert(result.value() == 43);

    auto bad_result = parse_int("not a number")
        .and_then(double_it)
        .map([](int x) { return x + 1; });

    assert(!bad_result.has_value());
    assert(bad_result.error() == "parse error");
}

TEST(comparison) {
    Expected<int, std::string> e1(42);
    Expected<int, std::string> e2(42);
    Expected<int, std::string> e3(100);
    Expected<int, std::string> err1(Unexpected(std::string("error")));
    Expected<int, std::string> err2(Unexpected(std::string("error")));
    Expected<int, std::string> err3(Unexpected(std::string("other")));

    assert(e1 == e2);
    assert(e1 != e3);
    assert(e1 != err1);
    assert(err1 == err2);
    assert(err1 != err3);
}

TEST(ok_err_helpers) {
    auto good = Ok<int, std::string>(42);
    assert(good.has_value());
    assert(good.value() == 42);

    auto bad = Err<int, std::string>("error");
    assert(!bad.has_value());
    assert(bad.error() == "error");
}

TEST(with_complex_types) {
    struct Config {
        std::string name;
        int value;
    };

    auto load_config = []() -> Expected<Config, std::string> {
        return Config{"test", 42};
    };

    auto result = load_config();
    assert(result.has_value());
    assert(result->name == "test");
    assert(result->value == 42);
}

int main() {
    std::cout << "Expected Tests:" << std::endl;

    RUN_TEST(value_construction);
    RUN_TEST(error_construction);
    RUN_TEST(copy_construction);
    RUN_TEST(move_construction);
    RUN_TEST(copy_assignment);
    RUN_TEST(move_assignment);
    RUN_TEST(boolean_conversion);
    RUN_TEST(value_throws_on_error);
    RUN_TEST(error_throws_on_value);
    RUN_TEST(value_or);
    RUN_TEST(error_or);
    RUN_TEST(dereference);
    RUN_TEST(map);
    RUN_TEST(map_error);
    RUN_TEST(and_then);
    RUN_TEST(or_else);
    RUN_TEST(chaining);
    RUN_TEST(comparison);
    RUN_TEST(ok_err_helpers);
    RUN_TEST(with_complex_types);

    std::cout << "\nAll tests passed!" << std::endl;
    return 0;
}
