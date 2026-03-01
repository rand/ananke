//! Iterator Chain Implementation
//! Demonstrates Rust iterator combinators for data transformation pipelines

use std::collections::HashMap;

pub struct DataPipeline<T> {
    data: Vec<T>,
}

impl<T: Clone> DataPipeline<T> {
    pub fn new(data: Vec<T>) -> Self {
        DataPipeline { data }
    }

    pub fn into_inner(self) -> Vec<T> {
        self.data
    }
}

impl<T: Clone + 'static> DataPipeline<T> {
    pub fn map<U: Clone + 'static, F>(self, f: F) -> DataPipeline<U>
    where
        F: Fn(T) -> U,
    {
        DataPipeline {
            data: self.data.into_iter().map(f).collect(),
        }
    }

    pub fn filter<F>(self, predicate: F) -> DataPipeline<T>
    where
        F: Fn(&T) -> bool,
    {
        DataPipeline {
            data: self.data.into_iter().filter(predicate).collect(),
        }
    }

    pub fn flat_map<U: Clone + 'static, I, F>(self, f: F) -> DataPipeline<U>
    where
        I: IntoIterator<Item = U>,
        F: Fn(T) -> I,
    {
        DataPipeline {
            data: self.data.into_iter().flat_map(f).collect(),
        }
    }
}

pub fn transform_strings(input: Vec<&str>) -> Vec<String> {
    input
        .into_iter()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_uppercase())
        .collect()
}

pub fn sum_even_squares(numbers: Vec<i32>) -> i32 {
    numbers
        .into_iter()
        .filter(|n| n % 2 == 0)
        .map(|n| n * n)
        .sum()
}

pub fn word_frequency(text: &str) -> HashMap<String, usize> {
    text.split_whitespace()
        .map(|word| word.to_lowercase())
        .map(|word| word.chars().filter(|c| c.is_alphabetic()).collect::<String>())
        .filter(|word| !word.is_empty())
        .fold(HashMap::new(), |mut acc, word| {
            *acc.entry(word).or_insert(0) += 1;
            acc
        })
}

pub fn flatten_nested(nested: Vec<Vec<i32>>) -> Vec<i32> {
    nested.into_iter().flatten().collect()
}

pub fn zip_with<A, B, C, F>(a: Vec<A>, b: Vec<B>, f: F) -> Vec<C>
where
    F: Fn(A, B) -> C,
{
    a.into_iter().zip(b).map(|(x, y)| f(x, y)).collect()
}

pub fn take_while_positive(numbers: Vec<i32>) -> Vec<i32> {
    numbers.into_iter().take_while(|&n| n > 0).collect()
}

pub fn partition_by_predicate<T, F>(items: Vec<T>, predicate: F) -> (Vec<T>, Vec<T>)
where
    F: Fn(&T) -> bool,
{
    items.into_iter().partition(predicate)
}

pub fn find_first_match<T, F>(items: Vec<T>, predicate: F) -> Option<T>
where
    F: Fn(&T) -> bool,
{
    items.into_iter().find(predicate)
}

pub fn chunk_by_size<T: Clone>(items: Vec<T>, size: usize) -> Vec<Vec<T>> {
    items.chunks(size).map(|chunk| chunk.to_vec()).collect()
}
