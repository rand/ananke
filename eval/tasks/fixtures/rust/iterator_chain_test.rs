#[path = "iterator_chain.rs"]
mod iterator_chain;

use iterator_chain::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_transform_strings() {
        let input = vec!["  hello  ", "world", "", "  rust  "];
        let result = transform_strings(input);
        assert_eq!(result, vec!["HELLO", "WORLD", "RUST"]);
    }

    #[test]
    fn test_sum_even_squares() {
        let numbers = vec![1, 2, 3, 4, 5, 6];
        let result = sum_even_squares(numbers);
        // 2^2 + 4^2 + 6^2 = 4 + 16 + 36 = 56
        assert_eq!(result, 56);
    }

    #[test]
    fn test_word_frequency() {
        let text = "hello world hello rust world world";
        let freq = word_frequency(text);
        assert_eq!(freq.get("hello"), Some(&2));
        assert_eq!(freq.get("world"), Some(&3));
        assert_eq!(freq.get("rust"), Some(&1));
    }

    #[test]
    fn test_flatten_nested() {
        let nested = vec![vec![1, 2], vec![3, 4, 5], vec![6]];
        let result = flatten_nested(nested);
        assert_eq!(result, vec![1, 2, 3, 4, 5, 6]);
    }

    #[test]
    fn test_zip_with() {
        let a = vec![1, 2, 3];
        let b = vec![4, 5, 6];
        let result = zip_with(a, b, |x, y| x + y);
        assert_eq!(result, vec![5, 7, 9]);
    }

    #[test]
    fn test_take_while_positive() {
        let numbers = vec![5, 3, 1, -2, 4, 6];
        let result = take_while_positive(numbers);
        assert_eq!(result, vec![5, 3, 1]);
    }

    #[test]
    fn test_partition_by_predicate() {
        let numbers = vec![1, 2, 3, 4, 5, 6];
        let (evens, odds) = partition_by_predicate(numbers, |n| n % 2 == 0);
        assert_eq!(evens, vec![2, 4, 6]);
        assert_eq!(odds, vec![1, 3, 5]);
    }

    #[test]
    fn test_find_first_match() {
        let numbers = vec![1, 3, 5, 6, 7, 8];
        let result = find_first_match(numbers, |n| n % 2 == 0);
        assert_eq!(result, Some(6));
    }

    #[test]
    fn test_find_first_match_none() {
        let numbers = vec![1, 3, 5, 7];
        let result = find_first_match(numbers, |n| n % 2 == 0);
        assert_eq!(result, None);
    }

    #[test]
    fn test_chunk_by_size() {
        let items = vec![1, 2, 3, 4, 5];
        let result = chunk_by_size(items, 2);
        assert_eq!(result, vec![vec![1, 2], vec![3, 4], vec![5]]);
    }

    #[test]
    fn test_data_pipeline_map() {
        let pipeline = DataPipeline::new(vec![1, 2, 3]);
        let result = pipeline.map(|x| x * 2).into_inner();
        assert_eq!(result, vec![2, 4, 6]);
    }

    #[test]
    fn test_data_pipeline_filter() {
        let pipeline = DataPipeline::new(vec![1, 2, 3, 4, 5]);
        let result = pipeline.filter(|x| x % 2 == 0).into_inner();
        assert_eq!(result, vec![2, 4]);
    }

    #[test]
    fn test_data_pipeline_chain() {
        let pipeline = DataPipeline::new(vec![1, 2, 3, 4, 5]);
        let result = pipeline
            .filter(|x| x % 2 == 0)
            .map(|x| x * 10)
            .into_inner();
        assert_eq!(result, vec![20, 40]);
    }
}
