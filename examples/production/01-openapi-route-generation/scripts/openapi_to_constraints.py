#!/usr/bin/env python3
"""
OpenAPI to Constraints Converter

Parses an OpenAPI 3.0 specification and converts it to Ananke constraint format,
then merges with extracted constraints from existing code.

Usage:
    python3 openapi_to_constraints.py <openapi.yaml> <extracted.json> -o <output.json>
"""

import json
import sys
import yaml
from pathlib import Path
from typing import Any, Dict, List, Optional


def load_openapi_spec(filepath: Path) -> Dict[str, Any]:
    """Load and parse OpenAPI YAML specification."""
    with open(filepath, 'r') as f:
        spec = yaml.safe_load(f)

    if not spec or 'openapi' not in spec:
        raise ValueError(f"Invalid OpenAPI specification in {filepath}")

    return spec


def load_extracted_constraints(filepath: Path) -> Dict[str, Any]:
    """Load extracted constraints from JSON file."""
    with open(filepath, 'r') as f:
        constraints = json.load(f)

    if 'constraints' not in constraints:
        raise ValueError(f"Invalid constraints format in {filepath}")

    return constraints


def convert_schema_to_validation(schema: Dict[str, Any], param_name: str) -> Dict[str, Any]:
    """Convert OpenAPI schema to validation constraint."""
    validation = {
        'type': 'validation',
        'parameter': param_name,
        'schema_type': schema.get('type', 'any'),
    }

    # Add type-specific validation rules
    if schema.get('type') == 'integer':
        if 'minimum' in schema:
            validation['minimum'] = schema['minimum']
        if 'maximum' in schema:
            validation['maximum'] = schema['maximum']
        validation['format'] = schema.get('format', 'int32')

    elif schema.get('type') == 'string':
        if 'minLength' in schema:
            validation['minLength'] = schema['minLength']
        if 'maxLength' in schema:
            validation['maxLength'] = schema['maxLength']
        if 'pattern' in schema:
            validation['pattern'] = schema['pattern']
        if 'format' in schema:
            validation['format'] = schema['format']
        if 'enum' in schema:
            validation['enum'] = schema['enum']

    elif schema.get('type') == 'array':
        if 'items' in schema:
            validation['items'] = schema['items']
        if 'minItems' in schema:
            validation['minItems'] = schema['minItems']
        if 'maxItems' in schema:
            validation['maxItems'] = schema['maxItems']

    return validation


def extract_path_constraints(path: str, method: str, operation: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Extract constraints from a single OpenAPI path operation."""
    constraints = []

    # Basic API contract constraint
    contract = {
        'type': 'api_contract',
        'source': 'openapi',
        'method': method.upper(),
        'path': path,
        'description': operation.get('summary', operation.get('description', '')),
        'operation_id': operation.get('operationId', ''),
    }

    # Extract parameters (path, query, header)
    if 'parameters' in operation:
        contract['parameters'] = []
        for param in operation['parameters']:
            param_info = {
                'name': param['name'],
                'location': param['in'],
                'required': param.get('required', False),
                'schema': param.get('schema', {}),
            }
            contract['parameters'].append(param_info)

            # Add validation constraint for each parameter
            if 'schema' in param:
                validation = convert_schema_to_validation(param['schema'], param['name'])
                validation['location'] = param['in']
                validation['required'] = param.get('required', False)
                validation['description'] = param.get('description', '')
                constraints.append(validation)

    # Extract request body
    if 'requestBody' in operation:
        request_body = operation['requestBody']
        contract['request_body'] = {
            'required': request_body.get('required', False),
            'content_types': list(request_body.get('content', {}).keys()),
        }

        # Extract schema from first content type (usually application/json)
        for content_type, content_spec in request_body.get('content', {}).items():
            if 'schema' in content_spec:
                schema = content_spec['schema']

                # Add request body validation constraint
                body_constraint = {
                    'type': 'validation',
                    'parameter': 'request_body',
                    'location': 'body',
                    'required': request_body.get('required', False),
                    'content_type': content_type,
                    'schema': schema,
                }

                # If schema has properties, add detailed validations
                if 'properties' in schema:
                    body_constraint['properties'] = {}
                    for prop_name, prop_schema in schema['properties'].items():
                        body_constraint['properties'][prop_name] = convert_schema_to_validation(
                            prop_schema, prop_name
                        )

                if 'required' in schema:
                    body_constraint['required_fields'] = schema['required']

                constraints.append(body_constraint)
                break  # Only process first content type

    # Extract responses
    if 'responses' in operation:
        contract['responses'] = {}
        for status_code, response_spec in operation['responses'].items():
            contract['responses'][status_code] = {
                'description': response_spec.get('description', ''),
            }

            # Extract response schema if available
            if 'content' in response_spec:
                for content_type, content_spec in response_spec['content'].items():
                    if 'schema' in content_spec:
                        contract['responses'][status_code]['schema'] = content_spec['schema']
                        break

            # Add response format constraint for error responses
            if status_code in ['400', '404', '409', '500']:
                error_constraint = {
                    'type': 'response_format',
                    'status_code': int(status_code),
                    'description': response_spec.get('description', ''),
                    'pattern': {
                        'properties': ['error', 'message'],
                        'optional_properties': ['details'],
                    },
                }
                constraints.append(error_constraint)

    constraints.append(contract)
    return constraints


def convert_openapi_to_constraints(spec: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Convert entire OpenAPI spec to list of constraints."""
    all_constraints = []

    # Add general API metadata
    if 'info' in spec:
        all_constraints.append({
            'type': 'metadata',
            'source': 'openapi',
            'api_title': spec['info'].get('title', ''),
            'api_version': spec['info'].get('version', ''),
            'description': spec['info'].get('description', ''),
        })

    # Process each path and operation
    if 'paths' in spec:
        for path, path_item in spec['paths'].items():
            for method in ['get', 'post', 'put', 'patch', 'delete']:
                if method in path_item:
                    operation = path_item[method]
                    path_constraints = extract_path_constraints(path, method, operation)
                    all_constraints.extend(path_constraints)

    # Add component schemas as type constraints
    if 'components' in spec and 'schemas' in spec['components']:
        for schema_name, schema_def in spec['components']['schemas'].items():
            type_constraint = {
                'type': 'type_constraint',
                'source': 'openapi',
                'name': schema_name,
                'schema': schema_def,
            }

            if 'properties' in schema_def:
                type_constraint['properties'] = schema_def['properties']
            if 'required' in schema_def:
                type_constraint['required'] = schema_def['required']

            all_constraints.append(type_constraint)

    return all_constraints


def merge_constraints(openapi_constraints: List[Dict[str, Any]],
                      extracted_constraints: Dict[str, Any]) -> Dict[str, Any]:
    """Merge OpenAPI constraints with extracted code constraints."""
    merged = {
        'constraints': openapi_constraints.copy(),
        'metadata': {
            'sources': ['openapi', 'extracted_code'],
            'merge_strategy': 'openapi_takes_precedence_for_api_contract',
        },
    }

    # Add extracted constraints
    if 'constraints' in extracted_constraints:
        for constraint in extracted_constraints['constraints']:
            # Skip duplicate API contract constraints (OpenAPI takes precedence)
            if constraint.get('type') == 'api_contract':
                continue

            # Add all other constraints (patterns, error handling, etc.)
            merged['constraints'].append(constraint)

    return merged


def main():
    """Main execution function."""
    if len(sys.argv) < 4:
        print("Usage: python3 openapi_to_constraints.py <openapi.yaml> <extracted.json> -o <output.json>")
        sys.exit(1)

    openapi_file = Path(sys.argv[1])
    extracted_file = Path(sys.argv[2])

    # Parse output flag
    output_file = None
    if '-o' in sys.argv:
        output_idx = sys.argv.index('-o')
        if output_idx + 1 < len(sys.argv):
            output_file = Path(sys.argv[output_idx + 1])

    if not output_file:
        print("Error: Output file required (-o flag)")
        sys.exit(1)

    # Validate input files exist
    if not openapi_file.exists():
        print(f"Error: OpenAPI file not found: {openapi_file}")
        sys.exit(1)

    if not extracted_file.exists():
        print(f"Error: Extracted constraints file not found: {extracted_file}")
        sys.exit(1)

    try:
        # Load inputs
        print(f"Loading OpenAPI spec from {openapi_file}...")
        openapi_spec = load_openapi_spec(openapi_file)

        print(f"Loading extracted constraints from {extracted_file}...")
        extracted_constraints = load_extracted_constraints(extracted_file)

        # Convert OpenAPI to constraints
        print("Converting OpenAPI spec to constraints...")
        openapi_constraints = convert_openapi_to_constraints(openapi_spec)
        print(f"  Generated {len(openapi_constraints)} constraints from OpenAPI spec")

        # Merge constraints
        print("Merging with extracted constraints...")
        merged = merge_constraints(openapi_constraints, extracted_constraints)
        print(f"  Total merged constraints: {len(merged['constraints'])}")

        # Write output
        output_file.parent.mkdir(parents=True, exist_ok=True)
        with open(output_file, 'w') as f:
            json.dump(merged, f, indent=2)

        print(f"\n✓ Successfully wrote merged constraints to {output_file}")

        # Print summary
        constraint_types = {}
        for c in merged['constraints']:
            ctype = c.get('type', 'unknown')
            constraint_types[ctype] = constraint_types.get(ctype, 0) + 1

        print("\nConstraint summary:")
        for ctype, count in sorted(constraint_types.items()):
            print(f"  {ctype}: {count}")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
