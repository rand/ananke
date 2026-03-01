/**
 * Type-Safe Variant with Visitor Pattern
 * A simplified std::variant implementation with visit support.
 */

#ifndef VARIANT_VISITOR_HPP
#define VARIANT_VISITOR_HPP

#include <cstddef>
#include <type_traits>
#include <utility>
#include <stdexcept>
#include <new>

// Helper to get maximum size
template<typename... Ts>
struct MaxSize;

template<typename T>
struct MaxSize<T> {
    static constexpr size_t value = sizeof(T);
};

template<typename T, typename... Rest>
struct MaxSize<T, Rest...> {
    static constexpr size_t value = sizeof(T) > MaxSize<Rest...>::value
        ? sizeof(T) : MaxSize<Rest...>::value;
};

// Helper to get maximum alignment
template<typename... Ts>
struct MaxAlign;

template<typename T>
struct MaxAlign<T> {
    static constexpr size_t value = alignof(T);
};

template<typename T, typename... Rest>
struct MaxAlign<T, Rest...> {
    static constexpr size_t value = alignof(T) > MaxAlign<Rest...>::value
        ? alignof(T) : MaxAlign<Rest...>::value;
};

// Helper to get type index in parameter pack
template<typename T, typename... Ts>
struct TypeIndex;

template<typename T, typename First, typename... Rest>
struct TypeIndex<T, First, Rest...> {
    static constexpr size_t value = std::is_same_v<T, First>
        ? 0 : 1 + TypeIndex<T, Rest...>::value;
};

template<typename T>
struct TypeIndex<T> {
    static_assert(sizeof(T) == 0, "Type not found in variant");
};

// Helper to get type at index
template<size_t I, typename... Ts>
struct TypeAtIndex;

template<typename First, typename... Rest>
struct TypeAtIndex<0, First, Rest...> {
    using type = First;
};

template<size_t I, typename First, typename... Rest>
struct TypeAtIndex<I, First, Rest...> {
    using type = typename TypeAtIndex<I - 1, Rest...>::type;
};

// Bad variant access exception
class bad_variant_access : public std::exception {
public:
    const char* what() const noexcept override {
        return "bad variant access";
    }
};

// Variant implementation
template<typename... Types>
class Variant {
private:
    static constexpr size_t storage_size = MaxSize<Types...>::value;
    static constexpr size_t storage_align = MaxAlign<Types...>::value;

    alignas(storage_align) unsigned char storage_[storage_size];
    size_t index_{sizeof...(Types)};  // Invalid index by default

    // Destroy current value
    template<size_t I = 0>
    void destroy_impl() {
        if constexpr (I < sizeof...(Types)) {
            if (index_ == I) {
                using T = typename TypeAtIndex<I, Types...>::type;
                reinterpret_cast<T*>(storage_)->~T();
            } else {
                destroy_impl<I + 1>();
            }
        }
    }

    // Copy from another variant
    template<size_t I = 0>
    void copy_impl(const Variant& other) {
        if constexpr (I < sizeof...(Types)) {
            if (other.index_ == I) {
                using T = typename TypeAtIndex<I, Types...>::type;
                new (storage_) T(*reinterpret_cast<const T*>(other.storage_));
                index_ = I;
            } else {
                copy_impl<I + 1>(other);
            }
        }
    }

    // Move from another variant
    template<size_t I = 0>
    void move_impl(Variant&& other) {
        if constexpr (I < sizeof...(Types)) {
            if (other.index_ == I) {
                using T = typename TypeAtIndex<I, Types...>::type;
                new (storage_) T(std::move(*reinterpret_cast<T*>(other.storage_)));
                index_ = I;
            } else {
                move_impl<I + 1>(std::move(other));
            }
        }
    }

public:
    // Default constructor (constructs first type)
    Variant() {
        using T = typename TypeAtIndex<0, Types...>::type;
        new (storage_) T();
        index_ = 0;
    }

    // Constructing constructor
    template<typename T, typename = std::enable_if_t<
        (std::is_same_v<std::decay_t<T>, Types> || ...)>>
    Variant(T&& value) {
        using DecayedT = std::decay_t<T>;
        new (storage_) DecayedT(std::forward<T>(value));
        index_ = TypeIndex<DecayedT, Types...>::value;
    }

    // Copy constructor
    Variant(const Variant& other) {
        copy_impl(other);
    }

    // Move constructor
    Variant(Variant&& other) noexcept {
        move_impl(std::move(other));
    }

    // Destructor
    ~Variant() {
        if (index_ < sizeof...(Types)) {
            destroy_impl();
        }
    }

    // Copy assignment
    Variant& operator=(const Variant& other) {
        if (this != &other) {
            if (index_ < sizeof...(Types)) {
                destroy_impl();
            }
            copy_impl(other);
        }
        return *this;
    }

    // Move assignment
    Variant& operator=(Variant&& other) noexcept {
        if (this != &other) {
            if (index_ < sizeof...(Types)) {
                destroy_impl();
            }
            move_impl(std::move(other));
        }
        return *this;
    }

    // Value assignment
    template<typename T, typename = std::enable_if_t<
        (std::is_same_v<std::decay_t<T>, Types> || ...)>>
    Variant& operator=(T&& value) {
        if (index_ < sizeof...(Types)) {
            destroy_impl();
        }
        using DecayedT = std::decay_t<T>;
        new (storage_) DecayedT(std::forward<T>(value));
        index_ = TypeIndex<DecayedT, Types...>::value;
        return *this;
    }

    // Get current type index
    size_t index() const noexcept {
        return index_;
    }

    // Check if holding specific type
    template<typename T>
    bool holds_alternative() const noexcept {
        return index_ == TypeIndex<T, Types...>::value;
    }

    // Get value (throws on type mismatch)
    template<typename T>
    T& get() {
        if (index_ != TypeIndex<T, Types...>::value) {
            throw bad_variant_access();
        }
        return *reinterpret_cast<T*>(storage_);
    }

    template<typename T>
    const T& get() const {
        if (index_ != TypeIndex<T, Types...>::value) {
            throw bad_variant_access();
        }
        return *reinterpret_cast<const T*>(storage_);
    }

    // Get pointer (nullptr on type mismatch)
    template<typename T>
    T* get_if() noexcept {
        if (index_ != TypeIndex<T, Types...>::value) {
            return nullptr;
        }
        return reinterpret_cast<T*>(storage_);
    }

    template<typename T>
    const T* get_if() const noexcept {
        if (index_ != TypeIndex<T, Types...>::value) {
            return nullptr;
        }
        return reinterpret_cast<const T*>(storage_);
    }

    // Emplace new value
    template<typename T, typename... Args>
    T& emplace(Args&&... args) {
        if (index_ < sizeof...(Types)) {
            destroy_impl();
        }
        new (storage_) T(std::forward<Args>(args)...);
        index_ = TypeIndex<T, Types...>::value;
        return *reinterpret_cast<T*>(storage_);
    }

    // Visit implementation
    template<typename Visitor, size_t I = 0>
    decltype(auto) visit_impl(Visitor&& visitor) {
        if constexpr (I < sizeof...(Types)) {
            if (index_ == I) {
                using T = typename TypeAtIndex<I, Types...>::type;
                return visitor(*reinterpret_cast<T*>(storage_));
            } else {
                return visit_impl<Visitor, I + 1>(std::forward<Visitor>(visitor));
            }
        } else {
            throw bad_variant_access();
        }
    }

    template<typename Visitor, size_t I = 0>
    decltype(auto) visit_impl(Visitor&& visitor) const {
        if constexpr (I < sizeof...(Types)) {
            if (index_ == I) {
                using T = typename TypeAtIndex<I, Types...>::type;
                return visitor(*reinterpret_cast<const T*>(storage_));
            } else {
                return visit_impl<Visitor, I + 1>(std::forward<Visitor>(visitor));
            }
        } else {
            throw bad_variant_access();
        }
    }
};

// Free function visit
template<typename Visitor, typename... Types>
decltype(auto) visit(Visitor&& visitor, Variant<Types...>& variant) {
    return variant.template visit_impl(std::forward<Visitor>(visitor));
}

template<typename Visitor, typename... Types>
decltype(auto) visit(Visitor&& visitor, const Variant<Types...>& variant) {
    return variant.template visit_impl(std::forward<Visitor>(visitor));
}

// Overloaded helper for creating visitors from lambdas
template<typename... Ts>
struct Overloaded : Ts... {
    using Ts::operator()...;
};

template<typename... Ts>
Overloaded(Ts...) -> Overloaded<Ts...>;

#endif // VARIANT_VISITOR_HPP
