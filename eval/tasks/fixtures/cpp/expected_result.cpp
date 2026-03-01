/**
 * Expected/Result Type for Error Handling
 * Similar to std::expected (C++23) or Rust's Result.
 */

#ifndef EXPECTED_RESULT_HPP
#define EXPECTED_RESULT_HPP

#include <utility>
#include <stdexcept>
#include <type_traits>
#include <optional>

// Exception for bad access
class bad_expected_access : public std::exception {
public:
    const char* what() const noexcept override {
        return "bad expected access";
    }
};

// Unexpected wrapper for error values
template<typename E>
class Unexpected {
    E error_;

public:
    explicit Unexpected(const E& e) : error_(e) {}
    explicit Unexpected(E&& e) : error_(std::move(e)) {}

    const E& value() const& { return error_; }
    E& value() & { return error_; }
    E&& value() && { return std::move(error_); }
};

// Deduction guide
template<typename E>
Unexpected(E) -> Unexpected<E>;

// Expected implementation
template<typename T, typename E>
class Expected {
private:
    union {
        T value_;
        E error_;
    };
    bool has_value_;

    void destroy() {
        if (has_value_) {
            value_.~T();
        } else {
            error_.~E();
        }
    }

public:
    using value_type = T;
    using error_type = E;

    // Value constructors
    Expected() : value_(), has_value_(true) {}

    Expected(const T& val) : value_(val), has_value_(true) {}

    Expected(T&& val) : value_(std::move(val)), has_value_(true) {}

    // Error constructors
    Expected(const Unexpected<E>& err)
        : error_(err.value()), has_value_(false) {}

    Expected(Unexpected<E>&& err)
        : error_(std::move(err).value()), has_value_(false) {}

    // Copy constructor
    Expected(const Expected& other) : has_value_(other.has_value_) {
        if (has_value_) {
            new (&value_) T(other.value_);
        } else {
            new (&error_) E(other.error_);
        }
    }

    // Move constructor
    Expected(Expected&& other) noexcept : has_value_(other.has_value_) {
        if (has_value_) {
            new (&value_) T(std::move(other.value_));
        } else {
            new (&error_) E(std::move(other.error_));
        }
    }

    // Destructor
    ~Expected() {
        destroy();
    }

    // Copy assignment
    Expected& operator=(const Expected& other) {
        if (this != &other) {
            destroy();
            has_value_ = other.has_value_;
            if (has_value_) {
                new (&value_) T(other.value_);
            } else {
                new (&error_) E(other.error_);
            }
        }
        return *this;
    }

    // Move assignment
    Expected& operator=(Expected&& other) noexcept {
        if (this != &other) {
            destroy();
            has_value_ = other.has_value_;
            if (has_value_) {
                new (&value_) T(std::move(other.value_));
            } else {
                new (&error_) E(std::move(other.error_));
            }
        }
        return *this;
    }

    // Value assignment
    Expected& operator=(const T& val) {
        destroy();
        new (&value_) T(val);
        has_value_ = true;
        return *this;
    }

    Expected& operator=(T&& val) {
        destroy();
        new (&value_) T(std::move(val));
        has_value_ = true;
        return *this;
    }

    // Error assignment
    Expected& operator=(const Unexpected<E>& err) {
        destroy();
        new (&error_) E(err.value());
        has_value_ = false;
        return *this;
    }

    // Observers
    bool has_value() const noexcept { return has_value_; }
    explicit operator bool() const noexcept { return has_value_; }

    // Value access (throws on error)
    T& value() & {
        if (!has_value_) throw bad_expected_access();
        return value_;
    }

    const T& value() const& {
        if (!has_value_) throw bad_expected_access();
        return value_;
    }

    T&& value() && {
        if (!has_value_) throw bad_expected_access();
        return std::move(value_);
    }

    // Error access (throws on value)
    E& error() & {
        if (has_value_) throw bad_expected_access();
        return error_;
    }

    const E& error() const& {
        if (has_value_) throw bad_expected_access();
        return error_;
    }

    E&& error() && {
        if (has_value_) throw bad_expected_access();
        return std::move(error_);
    }

    // Value access with default
    template<typename U>
    T value_or(U&& default_value) const& {
        return has_value_ ? value_ : static_cast<T>(std::forward<U>(default_value));
    }

    template<typename U>
    T value_or(U&& default_value) && {
        return has_value_ ? std::move(value_) : static_cast<T>(std::forward<U>(default_value));
    }

    // Error access with default
    template<typename U>
    E error_or(U&& default_error) const& {
        return has_value_ ? static_cast<E>(std::forward<U>(default_error)) : error_;
    }

    // Dereference operators
    T& operator*() & { return value_; }
    const T& operator*() const& { return value_; }
    T&& operator*() && { return std::move(value_); }

    T* operator->() { return &value_; }
    const T* operator->() const { return &value_; }

    // Monadic operations

    // map: Transform value if present
    template<typename F>
    auto map(F&& f) & -> Expected<decltype(f(value_)), E> {
        using U = decltype(f(value_));
        if (has_value_) {
            return Expected<U, E>(f(value_));
        }
        return Expected<U, E>(Unexpected(error_));
    }

    template<typename F>
    auto map(F&& f) const& -> Expected<decltype(f(value_)), E> {
        using U = decltype(f(value_));
        if (has_value_) {
            return Expected<U, E>(f(value_));
        }
        return Expected<U, E>(Unexpected(error_));
    }

    template<typename F>
    auto map(F&& f) && -> Expected<decltype(f(std::move(value_))), E> {
        using U = decltype(f(std::move(value_)));
        if (has_value_) {
            return Expected<U, E>(f(std::move(value_)));
        }
        return Expected<U, E>(Unexpected(std::move(error_)));
    }

    // map_error: Transform error if present
    template<typename F>
    auto map_error(F&& f) & -> Expected<T, decltype(f(error_))> {
        using U = decltype(f(error_));
        if (has_value_) {
            return Expected<T, U>(value_);
        }
        return Expected<T, U>(Unexpected(f(error_)));
    }

    // and_then: Chain operations that return Expected
    template<typename F>
    auto and_then(F&& f) & -> decltype(f(value_)) {
        using ReturnType = decltype(f(value_));
        if (has_value_) {
            return f(value_);
        }
        return ReturnType(Unexpected(error_));
    }

    template<typename F>
    auto and_then(F&& f) const& -> decltype(f(value_)) {
        using ReturnType = decltype(f(value_));
        if (has_value_) {
            return f(value_);
        }
        return ReturnType(Unexpected(error_));
    }

    template<typename F>
    auto and_then(F&& f) && -> decltype(f(std::move(value_))) {
        using ReturnType = decltype(f(std::move(value_)));
        if (has_value_) {
            return f(std::move(value_));
        }
        return ReturnType(Unexpected(std::move(error_)));
    }

    // or_else: Handle error with function returning Expected
    template<typename F>
    auto or_else(F&& f) & -> Expected {
        if (has_value_) {
            return *this;
        }
        return f(error_);
    }

    template<typename F>
    auto or_else(F&& f) && -> Expected {
        if (has_value_) {
            return std::move(*this);
        }
        return f(std::move(error_));
    }

    // Comparison operators
    template<typename U, typename G>
    bool operator==(const Expected<U, G>& other) const {
        if (has_value_ != other.has_value()) return false;
        if (has_value_) return value_ == other.value();
        return error_ == other.error();
    }

    template<typename U, typename G>
    bool operator!=(const Expected<U, G>& other) const {
        return !(*this == other);
    }
};

// Helper function to create Expected from value
template<typename T, typename E = std::string>
Expected<T, E> Ok(T&& value) {
    return Expected<T, E>(std::forward<T>(value));
}

// Helper function to create Expected from error
template<typename T, typename E>
Expected<T, E> Err(E&& error) {
    return Expected<T, E>(Unexpected(std::forward<E>(error)));
}

#endif // EXPECTED_RESULT_HPP
