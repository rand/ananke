//! FFI Overhead Benchmarks
//! Measures Rust→Zig and Zig→Rust conversion costs
//! Target: <1ms for typical operations

use criterion::{black_box, criterion_group, criterion_main, Criterion, BenchmarkId};
use maze::ffi::{ConstraintIR, JsonSchema, Grammar, GrammarRule, RegexPattern, TokenMaskRules};
use std::collections::HashMap;

fn create_test_constraint(id: usize) -> ConstraintIR {
    let mut properties = HashMap::new();
    properties.insert(
        format!("field_{}", id),
        serde_json::json!({"type": "string"}),
    );

    ConstraintIR {
        name: format!("constraint_{}", id),
        json_schema: Some(JsonSchema {
            schema_type: "object".to_string(),
            properties,
            required: vec![],
            additional_properties: false,
        }),
        grammar: Some(Grammar {
            rules: vec![
                GrammarRule {
                    lhs: "S".to_string(),
                    rhs: vec!["A".to_string()],
                },
            ],
            start_symbol: "S".to_string(),
        }),
        regex_patterns: vec![
            RegexPattern {
                pattern: r"\w+".to_string(),
                flags: String::new(),
            },
        ],
        token_masks: Some(TokenMaskRules {
            allowed_tokens: Some((0..100).collect()),
            forbidden_tokens: None,
        }),
        priority: 1,
    }
}

fn bench_struct_serialization(c: &mut Criterion) {
    let mut group = c.benchmark_group("struct_serialization");
    
    let constraint = create_test_constraint(0);
    
    group.bench_function("to_json", |b| {
        b.iter(|| {
            let _ = serde_json::to_string(black_box(&constraint)).unwrap();
        });
    });
    
    group.bench_function("from_json", |b| {
        let json = serde_json::to_string(&constraint).unwrap();
        b.iter(|| {
            let _: ConstraintIR = serde_json::from_str(black_box(&json)).unwrap();
        });
    });
    
    group.bench_function("roundtrip", |b| {
        b.iter(|| {
            let json = serde_json::to_string(black_box(&constraint)).unwrap();
            let _: ConstraintIR = serde_json::from_str(&json).unwrap();
        });
    });
    
    group.finish();
}

fn bench_vector_marshaling(c: &mut Criterion) {
    let mut group = c.benchmark_group("vector_marshaling");
    
    for count in [1, 10, 50, 100].iter() {
        let constraints: Vec<ConstraintIR> = (0..*count)
            .map(|i| create_test_constraint(i))
            .collect();
        
        group.bench_with_input(
            BenchmarkId::from_parameter(count),
            &constraints,
            |b, constraints| {
                b.iter(|| {
                    let json = serde_json::to_string(black_box(constraints)).unwrap();
                    let _: Vec<ConstraintIR> = serde_json::from_str(&json).unwrap();
                });
            },
        );
    }
    
    group.finish();
}

fn bench_string_copying(c: &mut Criterion) {
    let mut group = c.benchmark_group("string_copying");
    
    let test_strings = vec![
        ("short", "test"),
        ("medium", "This is a medium length string for testing FFI overhead"),
        ("long", &"x".repeat(1000)),
    ];
    
    for (name, test_str) in test_strings.iter() {
        group.bench_with_input(
            BenchmarkId::from_parameter(name),
            test_str,
            |b, test_str| {
                b.iter(|| {
                    let _copy = test_str.to_string();
                });
            },
        );
    }
    
    group.finish();
}

fn bench_hashmap_conversion(c: &mut Criterion) {
    let mut group = c.benchmark_group("hashmap_conversion");
    
    for size in [5, 20, 50].iter() {
        let mut map = HashMap::new();
        for i in 0..*size {
            map.insert(
                format!("key_{}", i),
                serde_json::json!({"type": "string", "value": i}),
            );
        }
        
        group.bench_with_input(
            BenchmarkId::from_parameter(size),
            &map,
            |b, map| {
                b.iter(|| {
                    let json = serde_json::to_string(black_box(map)).unwrap();
                    let _: HashMap<String, serde_json::Value> = serde_json::from_str(&json).unwrap();
                });
            },
        );
    }
    
    group.finish();
}

fn bench_constraint_cloning(c: &mut Criterion) {
    let mut group = c.benchmark_group("constraint_cloning");
    
    let constraint = create_test_constraint(0);
    
    group.bench_function("clone", |b| {
        b.iter(|| {
            let _ = black_box(&constraint).clone();
        });
    });
    
    group.finish();
}

fn bench_batch_operations(c: &mut Criterion) {
    let mut group = c.benchmark_group("batch_operations");
    
    for batch_size in [10, 50, 100].iter() {
        let constraints: Vec<ConstraintIR> = (0..*batch_size)
            .map(|i| create_test_constraint(i))
            .collect();
        
        group.bench_with_input(
            BenchmarkId::from_parameter(batch_size),
            &constraints,
            |b, constraints| {
                b.iter(|| {
                    // Simulate sending batch across FFI
                    for constraint in constraints.iter() {
                        let _ = serde_json::to_string(black_box(constraint)).unwrap();
                    }
                });
            },
        );
    }
    
    group.finish();
}

criterion_group!(
    benches,
    bench_struct_serialization,
    bench_vector_marshaling,
    bench_string_copying,
    bench_hashmap_conversion,
    bench_constraint_cloning,
    bench_batch_operations,
);

criterion_main!(benches);
