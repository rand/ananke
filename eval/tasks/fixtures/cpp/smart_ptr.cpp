/**
 * Reference-Counting Smart Pointer Implementation
 * Similar to std::shared_ptr with custom deleter support.
 */

#ifndef SMART_PTR_HPP
#define SMART_PTR_HPP

#include <atomic>
#include <utility>
#include <functional>

template<typename T>
struct DefaultDeleter {
    void operator()(T* ptr) const {
        delete ptr;
    }
};

template<typename T>
struct ControlBlock {
    std::atomic<size_t> ref_count{1};
    std::function<void(T*)> deleter;

    explicit ControlBlock(std::function<void(T*)> d = DefaultDeleter<T>{})
        : deleter(std::move(d)) {}

    void add_ref() {
        ++ref_count;
    }

    bool release() {
        return --ref_count == 0;
    }
};

template<typename T, typename Deleter = DefaultDeleter<T>>
class SharedPtr {
private:
    T* ptr_;
    ControlBlock<T>* control_;

    void cleanup() {
        if (control_ && control_->release()) {
            if (ptr_) {
                control_->deleter(ptr_);
            }
            delete control_;
        }
        ptr_ = nullptr;
        control_ = nullptr;
    }

public:
    // Default constructor
    SharedPtr() noexcept : ptr_(nullptr), control_(nullptr) {}

    // Nullptr constructor
    SharedPtr(std::nullptr_t) noexcept : ptr_(nullptr), control_(nullptr) {}

    // Raw pointer constructor
    explicit SharedPtr(T* ptr) : ptr_(ptr), control_(nullptr) {
        if (ptr_) {
            control_ = new ControlBlock<T>(Deleter{});
        }
    }

    // Raw pointer with custom deleter
    SharedPtr(T* ptr, std::function<void(T*)> deleter)
        : ptr_(ptr), control_(nullptr) {
        if (ptr_) {
            control_ = new ControlBlock<T>(std::move(deleter));
        }
    }

    // Copy constructor
    SharedPtr(const SharedPtr& other) noexcept
        : ptr_(other.ptr_), control_(other.control_) {
        if (control_) {
            control_->add_ref();
        }
    }

    // Move constructor
    SharedPtr(SharedPtr&& other) noexcept
        : ptr_(other.ptr_), control_(other.control_) {
        other.ptr_ = nullptr;
        other.control_ = nullptr;
    }

    // Destructor
    ~SharedPtr() {
        cleanup();
    }

    // Copy assignment
    SharedPtr& operator=(const SharedPtr& other) noexcept {
        if (this != &other) {
            cleanup();
            ptr_ = other.ptr_;
            control_ = other.control_;
            if (control_) {
                control_->add_ref();
            }
        }
        return *this;
    }

    // Move assignment
    SharedPtr& operator=(SharedPtr&& other) noexcept {
        if (this != &other) {
            cleanup();
            ptr_ = other.ptr_;
            control_ = other.control_;
            other.ptr_ = nullptr;
            other.control_ = nullptr;
        }
        return *this;
    }

    // Nullptr assignment
    SharedPtr& operator=(std::nullptr_t) noexcept {
        reset();
        return *this;
    }

    // Access operators
    T* get() const noexcept {
        return ptr_;
    }

    T& operator*() const noexcept {
        return *ptr_;
    }

    T* operator->() const noexcept {
        return ptr_;
    }

    // Reference count
    size_t use_count() const noexcept {
        return control_ ? control_->ref_count.load() : 0;
    }

    // Boolean conversion
    explicit operator bool() const noexcept {
        return ptr_ != nullptr;
    }

    // Reset to empty
    void reset() noexcept {
        cleanup();
    }

    // Reset with new pointer
    void reset(T* ptr) {
        if (ptr_ != ptr) {
            cleanup();
            ptr_ = ptr;
            if (ptr_) {
                control_ = new ControlBlock<T>(Deleter{});
            }
        }
    }

    // Reset with new pointer and deleter
    void reset(T* ptr, std::function<void(T*)> deleter) {
        if (ptr_ != ptr) {
            cleanup();
            ptr_ = ptr;
            if (ptr_) {
                control_ = new ControlBlock<T>(std::move(deleter));
            }
        }
    }

    // Swap
    void swap(SharedPtr& other) noexcept {
        std::swap(ptr_, other.ptr_);
        std::swap(control_, other.control_);
    }

    // Comparison operators
    bool operator==(const SharedPtr& other) const noexcept {
        return ptr_ == other.ptr_;
    }

    bool operator!=(const SharedPtr& other) const noexcept {
        return ptr_ != other.ptr_;
    }

    bool operator==(std::nullptr_t) const noexcept {
        return ptr_ == nullptr;
    }

    bool operator!=(std::nullptr_t) const noexcept {
        return ptr_ != nullptr;
    }
};

// Make shared helper
template<typename T, typename... Args>
SharedPtr<T> make_shared(Args&&... args) {
    return SharedPtr<T>(new T(std::forward<Args>(args)...));
}

// Swap specialization
template<typename T, typename D>
void swap(SharedPtr<T, D>& lhs, SharedPtr<T, D>& rhs) noexcept {
    lhs.swap(rhs);
}

#endif // SMART_PTR_HPP
