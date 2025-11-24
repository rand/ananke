//! Maze Orchestration Benchmarks
//! Target: Measure end-to-end orchestration overhead (without Modal)

use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion};
use maze::ffi::{ConstraintIR, Grammar, JsonSchema, RegexPattern, TokenMaskRules};
use maze::{GenerationRequest, MazeConfig, MazeOrchestrator, ModalConfig};
use std::collections::HashMap;

fn create_test_constraint(name: &str) -> ConstraintIR {
    ConstraintIR {
        name: name.to_string(),
        json_schema: Some(JsonSchema {
            schema_type: "object".to_string(),
            properties: HashMap::new(),
            required: vec![],
            additional_properties: false,
        }),
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 1,
    }
}

fn bench_constraint_compilation(c: &mut Criterion) {
    let mut group = c.benchmark_group("constraint_compilation");

    let rt = tokio::runtime::Runtime::new().unwrap();

    for constraint_count in [1, 5, 10, 25, 50].iter() {
        let constraints: Vec<ConstraintIR> = (0..*constraint_count)
            .map(|i| create_test_constraint(&format!("constraint_{}", i)))
            .collect();

        group.bench_with_input(
            BenchmarkId::from_parameter(constraint_count),
            constraint_count,
            |b, _| {
                b.iter(|| {
                    let config = ModalConfig::new(
                        "http://localhost:8000".to_string(),
                        "test-model".to_string(),
                    );
                    let orchestrator = MazeOrchestrator::new(config).unwrap();

                    rt.block_on(async {
                        // Just compile constraints, don't call Modal
                        let _ = orchestrator
                            .compile_constraints(black_box(&constraints))
                            .await;
                    });
                });
            },
        );
    }

    group.finish();
}

fn bench_cache_performance(c: &mut Criterion) {
    let mut group = c.benchmark_group("cache_performance");

    let rt = tokio::runtime::Runtime::new().unwrap();
    let config = ModalConfig::new(
        "http://localhost:8000".to_string(),
        "test-model".to_string(),
    );
    let orchestrator = MazeOrchestrator::new(config).unwrap();

    let constraints: Vec<ConstraintIR> = (0..10)
        .map(|i| create_test_constraint(&format!("constraint_{}", i)))
        .collect();

    // Prime the cache
    rt.block_on(async {
        let _ = orchestrator.compile_constraints(&constraints).await;
    });

    group.bench_function("cache_hit", |b| {
        b.iter(|| {
            rt.block_on(async {
                let _ = orchestrator
                    .compile_constraints(black_box(&constraints))
                    .await;
            });
        });
    });

    group.bench_function("cache_miss", |b| {
        b.iter(|| {
            rt.block_on(async {
                orchestrator.clear_cache().await.unwrap();
                let _ = orchestrator
                    .compile_constraints(black_box(&constraints))
                    .await;
            });
        });
    });

    group.finish();
}

fn bench_hash_generation(c: &mut Criterion) {
    let mut group = c.benchmark_group("hash_generation");

    let config = ModalConfig::new(
        "http://localhost:8000".to_string(),
        "test-model".to_string(),
    );
    let orchestrator = MazeOrchestrator::new(config).unwrap();

    for constraint_count in [1, 10, 50].iter() {
        let constraints: Vec<ConstraintIR> = (0..*constraint_count)
            .map(|i| create_test_constraint(&format!("constraint_{}", i)))
            .collect();

        group.bench_with_input(
            BenchmarkId::from_parameter(constraint_count),
            &constraints,
            |b, constraints| {
                b.iter(|| {
                    let _ = orchestrator.generate_cache_key(black_box(constraints));
                });
            },
        );
    }

    group.finish();
}

fn bench_llguidance_schema_generation(c: &mut Criterion) {
    let mut group = c.benchmark_group("llguidance_schema");

    let config = ModalConfig::new(
        "http://localhost:8000".to_string(),
        "test-model".to_string(),
    );
    let orchestrator = MazeOrchestrator::new(config).unwrap();

    for constraint_count in [1, 5, 10].iter() {
        let constraints: Vec<ConstraintIR> = (0..*constraint_count)
            .map(|i| create_test_constraint(&format!("constraint_{}", i)))
            .collect();

        group.bench_with_input(
            BenchmarkId::from_parameter(constraint_count),
            &constraints,
            |b, constraints| {
                b.iter(|| {
                    let _ = orchestrator.compile_to_llguidance(black_box(constraints));
                });
            },
        );
    }

    group.finish();
}

criterion_group!(
    benches,
    bench_constraint_compilation,
    bench_cache_performance,
    bench_hash_generation,
    bench_llguidance_schema_generation,
);

criterion_main!(benches);
