//! Cache Performance Benchmarks
//! Target: Cache hit <1μs, eviction policy efficiency

use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion};
use maze::ffi::{ConstraintIR, JsonSchema};
use maze::{MazeConfig, MazeOrchestrator, ModalConfig};
use std::collections::HashMap;

fn create_constraint_variant(id: usize) -> ConstraintIR {
    ConstraintIR {
        name: format!("constraint_{}", id),
        json_schema: Some(JsonSchema {
            schema_type: "object".to_string(),
            properties: {
                let mut props = HashMap::new();
                props.insert(
                    format!("field_{}", id),
                    serde_json::json!({"type": "string"}),
                );
                props
            },
            required: vec![],
            additional_properties: false,
        }),
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 1,
    }
}

fn bench_cache_hit_latency(c: &mut Criterion) {
    let mut group = c.benchmark_group("cache_hit_latency");

    let rt = tokio::runtime::Runtime::new().unwrap();
    let config = ModalConfig::new(
        "http://localhost:8000".to_string(),
        "test-model".to_string(),
    );
    let orchestrator = MazeOrchestrator::new(config).unwrap();

    let constraints = vec![create_constraint_variant(0)];

    // Prime the cache
    rt.block_on(async {
        let _ = orchestrator.compile_constraints(&constraints).await;
    });

    group.bench_function("single_constraint", |b| {
        b.iter(|| {
            rt.block_on(async {
                let _ = orchestrator
                    .compile_constraints(black_box(&constraints))
                    .await;
            });
        });
    });

    group.finish();
}

fn bench_cache_miss_latency(c: &mut Criterion) {
    let mut group = c.benchmark_group("cache_miss_latency");

    let rt = tokio::runtime::Runtime::new().unwrap();
    let config = ModalConfig::new(
        "http://localhost:8000".to_string(),
        "test-model".to_string(),
    );
    let orchestrator = MazeOrchestrator::new(config).unwrap();

    group.bench_function("single_constraint", |b| {
        b.iter(|| {
            rt.block_on(async {
                orchestrator.clear_cache().await.unwrap();
                let constraints = vec![create_constraint_variant(0)];
                let _ = orchestrator
                    .compile_constraints(black_box(&constraints))
                    .await;
            });
        });
    });

    group.finish();
}

fn bench_cache_eviction(c: &mut Criterion) {
    let mut group = c.benchmark_group("cache_eviction");

    let rt = tokio::runtime::Runtime::new().unwrap();

    for cache_size in [10, 100, 1000].iter() {
        let config = ModalConfig::new(
            "http://localhost:8000".to_string(),
            "test-model".to_string(),
        );
        let maze_config = MazeConfig {
            max_tokens: 2048,
            temperature: 0.7,
            enable_cache: true,
            cache_size_limit: *cache_size,
            timeout_secs: 300,
        };
        let orchestrator = MazeOrchestrator::with_config(config, maze_config).unwrap();

        // Fill cache to limit
        rt.block_on(async {
            for i in 0..*cache_size {
                let constraints = vec![create_constraint_variant(i)];
                let _ = orchestrator.compile_constraints(&constraints).await;
            }
        });

        group.bench_with_input(
            BenchmarkId::from_parameter(cache_size),
            cache_size,
            |b, _| {
                b.iter(|| {
                    rt.block_on(async {
                        // Add new entry, triggering eviction
                        let constraints = vec![create_constraint_variant(9999)];
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

fn bench_cache_hash_collision(c: &mut Criterion) {
    let mut group = c.benchmark_group("cache_hash_collision");

    let config = ModalConfig::new(
        "http://localhost:8000".to_string(),
        "test-model".to_string(),
    );
    let orchestrator = MazeOrchestrator::new(config).unwrap();

    // Create similar but different constraints
    let variants: Vec<Vec<ConstraintIR>> = (0..100)
        .map(|i| vec![create_constraint_variant(i)])
        .collect();

    group.bench_function("hash_uniqueness", |b| {
        b.iter(|| {
            for variant in &variants {
                let _ = orchestrator.generate_cache_key(black_box(variant));
            }
        });
    });

    group.finish();
}

fn bench_concurrent_cache_access(c: &mut Criterion) {
    let mut group = c.benchmark_group("concurrent_cache_access");

    let rt = tokio::runtime::Runtime::new().unwrap();
    let config = ModalConfig::new(
        "http://localhost:8000".to_string(),
        "test-model".to_string(),
    );
    let orchestrator = std::sync::Arc::new(MazeOrchestrator::new(config).unwrap());

    let constraints = vec![create_constraint_variant(0)];

    // Prime the cache
    rt.block_on(async {
        let _ = orchestrator.compile_constraints(&constraints).await;
    });

    for concurrency in [1, 2, 4, 8].iter() {
        group.bench_with_input(
            BenchmarkId::from_parameter(concurrency),
            concurrency,
            |b, &concurrency| {
                b.iter(|| {
                    rt.block_on(async {
                        let mut handles = vec![];
                        for _ in 0..concurrency {
                            let orch = orchestrator.clone();
                            let cons = constraints.clone();
                            handles.push(tokio::spawn(async move {
                                let _ = orch.compile_constraints(&cons).await;
                            }));
                        }
                        for handle in handles {
                            let _ = handle.await;
                        }
                    });
                });
            },
        );
    }

    group.finish();
}

criterion_group!(
    benches,
    bench_cache_hit_latency,
    bench_cache_miss_latency,
    bench_cache_eviction,
    bench_cache_hash_collision,
    bench_concurrent_cache_access,
);

criterion_main!(benches);
