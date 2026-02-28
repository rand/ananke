#!/usr/bin/env python3
"""
ConstraintSpec Round-Trip Conformance Validator (Python side)

Validates that JSON produced by `ananke export-spec` can be parsed
by Python and all CLaSH domain fields are well-formed.

Usage:
    ananke export-spec src/file.zig | python3 test/integration/validate_constraint_spec.py
    python3 test/integration/validate_constraint_spec.py spec.json
"""

import json
import sys
from typing import Any


class ConformanceError(Exception):
    pass


def validate_function_signatures(sigs: list[dict[str, Any]]) -> list[str]:
    """Validate function_signatures field matches expected schema."""
    errors: list[str] = []
    required_fields = {"name", "is_async", "is_public"}

    for i, sig in enumerate(sigs):
        for field in required_fields:
            if field not in sig:
                errors.append(f"function_signatures[{i}]: missing required field '{field}'")

        if "name" in sig and not isinstance(sig["name"], str):
            errors.append(f"function_signatures[{i}].name: expected string, got {type(sig['name']).__name__}")

        if "is_async" in sig and not isinstance(sig["is_async"], bool):
            errors.append(f"function_signatures[{i}].is_async: expected bool, got {type(sig['is_async']).__name__}")

        if "is_public" in sig and not isinstance(sig["is_public"], bool):
            errors.append(f"function_signatures[{i}].is_public: expected bool, got {type(sig['is_public']).__name__}")

    return errors


def validate_type_bindings(bindings: list[dict[str, Any]]) -> list[str]:
    """Validate type_bindings field."""
    errors: list[str] = []

    for i, binding in enumerate(bindings):
        if "name" not in binding:
            errors.append(f"type_bindings[{i}]: missing 'name'")
        if "kind" not in binding:
            errors.append(f"type_bindings[{i}]: missing 'kind'")

    return errors


def validate_class_definitions(classes: list[dict[str, Any]]) -> list[str]:
    """Validate class_definitions field."""
    errors: list[str] = []

    for i, cls in enumerate(classes):
        if "name" not in cls:
            errors.append(f"class_definitions[{i}]: missing 'name'")

    return errors


def validate_imports(imports: list[dict[str, Any]]) -> list[str]:
    """Validate imports field."""
    errors: list[str] = []

    for i, imp in enumerate(imports):
        if "module" not in imp:
            errors.append(f"imports[{i}]: missing 'module'")

    return errors


def validate_control_flow(cf: dict[str, Any]) -> list[str]:
    """Validate control_flow field (CLaSH ControlFlow domain)."""
    errors: list[str] = []
    required = {
        "async_function_count": int,
        "error_handling_count": int,
        "total_functions": int,
        "has_result_types": bool,
        "has_option_types": bool,
        "error_handling_style": str,
    }

    for field, expected_type in required.items():
        if field not in cf:
            errors.append(f"control_flow: missing '{field}'")
        elif not isinstance(cf[field], expected_type):
            errors.append(
                f"control_flow.{field}: expected {expected_type.__name__}, "
                f"got {type(cf[field]).__name__}"
            )

    valid_styles = {"result_based", "exception_based", "none"}
    if "error_handling_style" in cf and cf["error_handling_style"] not in valid_styles:
        errors.append(
            f"control_flow.error_handling_style: '{cf['error_handling_style']}' "
            f"not in {valid_styles}"
        )

    return errors


def validate_semantic_constraints(constraints: list[dict[str, Any]]) -> list[str]:
    """Validate semantic_constraints field (CLaSH Semantics domain)."""
    errors: list[str] = []
    valid_kinds = {"error_handling_required", "async_pattern", "error_type_defined"}

    for i, c in enumerate(constraints):
        if "kind" not in c:
            errors.append(f"semantic_constraints[{i}]: missing 'kind'")
        elif c["kind"] not in valid_kinds:
            errors.append(
                f"semantic_constraints[{i}].kind: '{c['kind']}' not in {valid_kinds}"
            )

        if "tier" not in c:
            errors.append(f"semantic_constraints[{i}]: missing 'tier'")
        elif c["tier"] != "soft":
            errors.append(
                f"semantic_constraints[{i}].tier: expected 'soft', got '{c['tier']}'. "
                "Semantic constraints must always be soft-tier (CLaSH invariant)."
            )

    return errors


def validate_constraint_spec(spec: dict[str, Any]) -> tuple[bool, list[str]]:
    """Validate a complete ConstraintSpec JSON object."""
    all_errors: list[str] = []

    # language is required
    if "language" not in spec:
        all_errors.append("Missing required field 'language'")
    elif not isinstance(spec["language"], str):
        all_errors.append(f"language: expected string, got {type(spec['language']).__name__}")

    # Validate each CLaSH domain field if present
    validators = {
        "function_signatures": (list, validate_function_signatures),
        "type_bindings": (list, validate_type_bindings),
        "class_definitions": (list, validate_class_definitions),
        "imports": (list, validate_imports),
        "control_flow": (dict, validate_control_flow),
        "semantic_constraints": (list, validate_semantic_constraints),
    }

    for field, (expected_type, validator) in validators.items():
        if field in spec:
            if not isinstance(spec[field], expected_type):
                all_errors.append(
                    f"{field}: expected {expected_type.__name__}, "
                    f"got {type(spec[field]).__name__}"
                )
            else:
                all_errors.extend(validator(spec[field]))

    return len(all_errors) == 0, all_errors


def main() -> int:
    # Read from file arg or stdin
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as f:
            raw = f.read()
    else:
        raw = sys.stdin.read()

    try:
        spec = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"FAIL: Invalid JSON: {e}", file=sys.stderr)
        return 1

    if not isinstance(spec, dict):
        print(f"FAIL: Expected JSON object, got {type(spec).__name__}", file=sys.stderr)
        return 1

    valid, errors = validate_constraint_spec(spec)

    if valid:
        # Summary of what was validated
        fields = []
        if "function_signatures" in spec:
            fields.append(f"functions={len(spec['function_signatures'])}")
        if "type_bindings" in spec:
            fields.append(f"types={len(spec['type_bindings'])}")
        if "class_definitions" in spec:
            fields.append(f"classes={len(spec['class_definitions'])}")
        if "imports" in spec:
            fields.append(f"imports={len(spec['imports'])}")
        if "control_flow" in spec:
            cf = spec["control_flow"]
            fields.append(f"control_flow(style={cf.get('error_handling_style', '?')})")
        if "semantic_constraints" in spec:
            fields.append(f"semantics={len(spec['semantic_constraints'])}")

        lang = spec.get("language", "unknown")
        print(f"PASS: ConstraintSpec ({lang}) — {', '.join(fields)}")
        return 0
    else:
        print(f"FAIL: {len(errors)} conformance errors:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
