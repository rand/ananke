#[path = "chain_cache_1.rs"]
mod chain_cache_1;

use chain_cache_1::*;

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::collections::HashMap;

    #[test]
    fn test_memoize_creation() {
        let memo: Memoize<i32, i32> = Memoize::new();
        assert!(memo.is_empty());
        assert_eq!(memo.len(), 0);
    }

    #[test]
    fn test_memoize_call() {
        let mut memo: Memoize<i32, i32> = Memoize::new();
        let call_count = RefCell::new(0);

        let result = memo.call(5, || {
            *call_count.borrow_mut() += 1;
            5 * 5
        });
        assert_eq!(result, 25);
        assert_eq!(*call_count.borrow(), 1);

        // Second call should use cache
        let result = memo.call(5, || {
            *call_count.borrow_mut() += 1;
            5 * 5
        });
        assert_eq!(result, 25);
        assert_eq!(*call_count.borrow(), 1); // Not incremented
    }

    #[test]
    fn test_memoize_get() {
        let mut memo: Memoize<String, i32> = Memoize::new();
        memo.call("test".to_string(), || 42);

        assert_eq!(memo.get(&"test".to_string()), Some(&42));
        assert_eq!(memo.get(&"other".to_string()), None);
    }

    #[test]
    fn test_memoize_contains() {
        let mut memo: Memoize<i32, i32> = Memoize::new();
        memo.call(1, || 10);

        assert!(memo.contains(&1));
        assert!(!memo.contains(&2));
    }

    #[test]
    fn test_memoize_invalidate() {
        let mut memo: Memoize<i32, i32> = Memoize::new();
        memo.call(1, || 10);

        assert!(memo.contains(&1));
        let removed = memo.invalidate(&1);
        assert_eq!(removed, Some(10));
        assert!(!memo.contains(&1));
    }

    #[test]
    fn test_memoize_clear() {
        let mut memo: Memoize<i32, i32> = Memoize::new();
        memo.call(1, || 10);
        memo.call(2, || 20);
        memo.call(3, || 30);

        assert_eq!(memo.len(), 3);
        memo.clear();
        assert!(memo.is_empty());
    }

    #[test]
    fn test_fib_memoized() {
        let mut cache = HashMap::new();
        assert_eq!(fib_memoized(0, &mut cache), 0);
        assert_eq!(fib_memoized(1, &mut cache), 1);
        assert_eq!(fib_memoized(10, &mut cache), 55);
        assert_eq!(fib_memoized(20, &mut cache), 6765);
    }

    #[test]
    fn test_fib_memoized_performance() {
        let mut cache = HashMap::new();
        // This would be very slow without memoization
        let result = fib_memoized(40, &mut cache);
        assert_eq!(result, 102334155);
    }

    #[test]
    fn test_factorial_memoized() {
        let mut cache = HashMap::new();
        assert_eq!(factorial_memoized(0, &mut cache), 1);
        assert_eq!(factorial_memoized(1, &mut cache), 1);
        assert_eq!(factorial_memoized(5, &mut cache), 120);
        assert_eq!(factorial_memoized(10, &mut cache), 3628800);
    }

    #[test]
    fn test_memoize2_creation() {
        let memo: Memoize2<i32, i32, i32> = Memoize2::new();
        assert!(memo.is_empty());
    }

    #[test]
    fn test_memoize2_call() {
        let mut memo: Memoize2<i32, i32, i32> = Memoize2::new();
        let call_count = RefCell::new(0);

        let result = memo.call(2, 3, || {
            *call_count.borrow_mut() += 1;
            2 + 3
        });
        assert_eq!(result, 5);
        assert_eq!(*call_count.borrow(), 1);

        let result = memo.call(2, 3, || {
            *call_count.borrow_mut() += 1;
            2 + 3
        });
        assert_eq!(result, 5);
        assert_eq!(*call_count.borrow(), 1);
    }

    #[test]
    fn test_memoize2_get() {
        let mut memo: Memoize2<i32, i32, i32> = Memoize2::new();
        memo.call(1, 2, || 3);

        assert_eq!(memo.get(&1, &2), Some(&3));
        assert_eq!(memo.get(&1, &3), None);
    }

    #[test]
    fn test_binomial() {
        let mut cache = HashMap::new();
        assert_eq!(binomial(5, 0, &mut cache), 1);
        assert_eq!(binomial(5, 5, &mut cache), 1);
        assert_eq!(binomial(5, 2, &mut cache), 10);
        assert_eq!(binomial(10, 5, &mut cache), 252);
    }

    #[test]
    fn test_binomial_large() {
        let mut cache = HashMap::new();
        // Would be slow without memoization
        assert_eq!(binomial(20, 10, &mut cache), 184756);
    }

    #[test]
    fn test_memoize_recursive() {
        let mut cache = HashMap::new();

        fn expensive(n: i32, cache: &mut HashMap<i32, i32>) -> i32 {
            memoize_recursive(cache, n, |c| {
                if n <= 1 {
                    n
                } else {
                    expensive(n - 1, c) + expensive(n - 2, c)
                }
            })
        }

        assert_eq!(expensive(10, &mut cache), 55);
    }
}
