//! Constraint Compilation Performance Benchmarks
//! Target: <50ms constraint compilation time

use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion};
use maze::ffi::{ConstraintIR, Grammar, GrammarRule, JsonSchema, RegexPattern, TokenMaskRules};
use std::collections::HashMap;

fn create_complex_json_schema() -> JsonSchema {
    let mut properties = HashMap::new();
    properties.insert(
        "name".to_string(),
        serde_json::json!({"type": "string", "minLength": 1}),
    );
    properties.insert(
        "age".to_string(),
        serde_json::json!({"type": "integer", "minimum": 0, "maximum": 150}),
    );
    properties.insert(
        "email".to_string(),
        serde_json::json!({"type": "string", "format": "email"}),
    );

    JsonSchema {
        schema_type: "object".to_string(),
        properties,
        required: vec!["name".to_string(), "email".to_string()],
        additional_properties: false,
    }
}

fn create_complex_grammar() -> Grammar {
    Grammar {
        rules: vec![
            GrammarRule {
                lhs: "expr".to_string(),
                rhs: vec!["term".to_string(), "+".to_string(), "expr".to_string()],
            },
            GrammarRule {
                lhs: "expr".to_string(),
                rhs: vec!["term".to_string()],
            },
            GrammarRule {
                lhs: "term".to_string(),
                rhs: vec!["factor".to_string(), "*".to_string(), "term".to_string()],
            },
            GrammarRule {
                lhs: "term".to_string(),
                rhs: vec!["factor".to_string()],
            },
            GrammarRule {
                lhs: "factor".to_string(),
                rhs: vec!["NUM".to_string()],
            },
        ],
        start_symbol: "expr".to_string(),
    }
}

fn bench_json_schema_serialization(c: &mut Criterion) {
    let mut group = c.benchmark_group("json_schema_serialization");

    let schema = create_complex_json_schema();

    group.bench_function("serialize", |b| {
        b.iter(|| {
            let _ = serde_json::to_string(black_box(&schema));
        });
    });

    group.bench_function("deserialize", |b| {
        let json = serde_json::to_string(&schema).unwrap();
        b.iter(|| {
            let _: JsonSchema = serde_json::from_str(black_box(&json)).unwrap();
        });
    });

    group.finish();
}

fn bench_grammar_serialization(c: &mut Criterion) {
    let mut group = c.benchmark_group("grammar_serialization");

    let grammar = create_complex_grammar();

    group.bench_function("serialize", |b| {
        b.iter(|| {
            let _ = serde_json::to_string(black_box(&grammar));
        });
    });

    group.bench_function("deserialize", |b| {
        let json = serde_json::to_string(&grammar).unwrap();
        b.iter(|| {
            let _: Grammar = serde_json::from_str(black_box(&json)).unwrap();
        });
    });

    group.finish();
}

fn bench_constraint_ir_serialization(c: &mut Criterion) {
    let mut group = c.benchmark_group("constraint_ir_serialization");

    for size in ["small", "medium", "large"].iter() {
        let constraint = match *size {
            "small" => ConstraintIR {
                name: "simple".to_string(),
                json_schema: None,
                grammar: None,
                regex_patterns: vec![],
                token_masks: None,
                priority: 1,
            },
            "medium" => ConstraintIR {
                name: "medium".to_string(),
                json_schema: Some(create_complex_json_schema()),
                grammar: None,
                regex_patterns: vec![RegexPattern {
                    pattern: r"\d+".to_string(),
                    flags: "g".to_string(),
                }],
                token_masks: None,
                priority: 1,
            },
            "large" => ConstraintIR {
                name: "complex".to_string(),
                json_schema: Some(create_complex_json_schema()),
                grammar: Some(create_complex_grammar()),
                regex_patterns: vec![
                    RegexPattern {
                        pattern: r"\d+".to_string(),
                        flags: "g".to_string(),
                    },
                    RegexPattern {
                        pattern: r"[a-zA-Z_][a-zA-Z0-9_]*".to_string(),
                        flags: String::new(),
                    },
                ],
                token_masks: Some(TokenMaskRules {
                    allowed_tokens: Some((0..1000).collect()),
                    forbidden_tokens: Some(vec![999, 1000, 1001]),
                }),
                priority: 1,
            },
            _ => unreachable!(),
        };

        group.bench_with_input(
            BenchmarkId::from_parameter(size),
            &constraint,
            |b, constraint| {
                b.iter(|| {
                    let _ = serde_json::to_string(black_box(constraint));
                });
            },
        );
    }

    group.finish();
}

fn bench_llguidance_conversion(c: &mut Criterion) {
    let mut group = c.benchmark_group("llguidance_conversion");

    let config = maze::ModalConfig::new(
        "http://localhost:8000".to_string(),
        "test-model".to_string(),
    );
    let orchestrator = maze::MazeOrchestrator::new(config).unwrap();

    for size in ["small", "medium", "large"].iter() {
        let constraints: Vec<ConstraintIR> = match *size {
            "small" => vec![ConstraintIR {
                name: "simple".to_string(),
                json_schema: None,
                grammar: None,
                regex_patterns: vec![],
                token_masks: None,
                priority: 1,
            }],
            "medium" => (0..5)
                .map(|i| ConstraintIR {
                    name: format!("constraint_{}", i),
                    json_schema: Some(create_complex_json_schema()),
                    grammar: None,
                    regex_patterns: vec![],
                    token_masks: None,
                    priority: 1,
                })
                .collect(),
            "large" => (0..10)
                .map(|i| ConstraintIR {
                    name: format!("constraint_{}", i),
                    json_schema: Some(create_complex_json_schema()),
                    grammar: Some(create_complex_grammar()),
                    regex_patterns: vec![RegexPattern {
                        pattern: r"\d+".to_string(),
                        flags: "g".to_string(),
                    }],
                    token_masks: None,
                    priority: 1,
                })
                .collect(),
            _ => unreachable!(),
        };

        group.bench_with_input(
            BenchmarkId::from_parameter(size),
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
    bench_json_schema_serialization,
    bench_grammar_serialization,
    bench_constraint_ir_serialization,
    bench_llguidance_conversion,
);

criterion_main!(benches);
