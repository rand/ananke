#!/usr/bin/env python3
"""Convert CLI specification YAML to Ananke constraint format.

This script parses a CLI command specification (in YAML format) and converts it
to the constraint format that Ananke can use for code generation.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def load_yaml_spec(spec_path: Path) -> Dict[str, Any]:
    """Load and parse YAML specification file.

    Args:
        spec_path: Path to the YAML specification file

    Returns:
        Parsed specification as a dictionary

    Raises:
        SystemExit: If file cannot be read or parsed
    """
    try:
        with open(spec_path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Error: Specification file not found: {spec_path}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error: Invalid YAML in {spec_path}: {e}", file=sys.stderr)
        sys.exit(1)
    except IOError as e:
        print(f"Error: Cannot read {spec_path}: {e}", file=sys.stderr)
        sys.exit(1)


def convert_type_to_click(type_name: str) -> str:
    """Convert specification type to Click type.

    Args:
        type_name: Type from specification (path, boolean, string, int, etc.)

    Returns:
        Click type string
    """
    type_mapping = {
        "path": "click.Path",
        "boolean": "bool",
        "string": "str",
        "int": "int",
        "float": "float",
        "choice": "click.Choice",
    }
    return type_mapping.get(type_name.lower(), "str")


def build_argument_constraints(arguments: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Build constraints for command arguments.

    Args:
        arguments: List of argument specifications

    Returns:
        List of argument constraints
    """
    constraints = []

    for arg in arguments:
        constraint = {
            "type": "click_argument",
            "name": arg["name"],
            "click_type": convert_type_to_click(arg.get("type", "string")),
            "required": arg.get("required", True),
            "help": arg.get("help", ""),
        }

        # Add path-specific constraints
        if arg.get("type") == "path" and arg.get("exists"):
            constraint["path_exists"] = True

        constraints.append(constraint)

    return constraints


def build_option_constraints(options: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Build constraints for command options.

    Args:
        options: List of option specifications

    Returns:
        List of option constraints
    """
    constraints = []

    for opt in options:
        constraint = {
            "type": "click_option",
            "name": opt["name"],
            "click_type": convert_type_to_click(opt.get("type", "string")),
            "required": opt.get("required", False),
            "help": opt.get("help", ""),
        }

        # Add short option if specified
        if "short" in opt:
            constraint["short"] = opt["short"]

        # Add default value if specified
        if "default" in opt:
            constraint["default"] = opt["default"]

        # Handle boolean flags
        if opt.get("type") == "boolean":
            constraint["is_flag"] = True

        # Add path-specific constraints
        if opt.get("type") == "path" and opt.get("exists"):
            constraint["path_exists"] = True

        constraints.append(constraint)

    return constraints


def build_validation_constraints(validations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Build validation constraints.

    Args:
        validations: List of validation specifications

    Returns:
        List of validation constraints
    """
    constraints = []

    for validation in validations:
        constraint = {
            "type": f"validation_{validation['type']}",
            "fields": validation.get("fields", [validation.get("field")]),
            "error_message": validation.get("error_message", "Validation failed"),
        }
        constraints.append(constraint)

    return constraints


def build_error_handling_constraints(
    error_handling: Dict[str, Dict[str, Any]]
) -> List[Dict[str, Any]]:
    """Build error handling constraints.

    Args:
        error_handling: Error handling specifications

    Returns:
        List of error handling constraints
    """
    constraints = []

    for error_type, config in error_handling.items():
        constraint = {
            "type": "error_handler",
            "error_type": error_type,
            "exit_code": config.get("exit_code", 1),
            "message_template": config.get("message_template", "Error: {message}"),
        }
        constraints.append(constraint)

    return constraints


def convert_spec_to_constraints(spec: Dict[str, Any]) -> Dict[str, Any]:
    """Convert full CLI specification to Ananke constraints.

    Args:
        spec: Parsed CLI specification

    Returns:
        Ananke constraint format
    """
    command = spec.get("command", {})

    constraints = {
        "version": "1.0",
        "type": "cli_command",
        "metadata": {
            "command_name": command.get("name", "command"),
            "function_name": command.get("function_name", command.get("name", "command")),
            "description": command.get("description", ""),
            "help_text": command.get("help", ""),
        },
        "constraints": [],
    }

    # Add command-level constraint
    constraints["constraints"].append(
        {
            "type": "click_command",
            "name": command.get("name", "command"),
            "function_name": command.get("function_name", command.get("name", "command")),
            "description": command.get("description", ""),
            "help": command.get("help", ""),
        }
    )

    # Add argument constraints
    if "arguments" in command:
        constraints["constraints"].extend(build_argument_constraints(command["arguments"]))

    # Add option constraints
    if "options" in command:
        constraints["constraints"].extend(build_option_constraints(command["options"]))

    # Add validation constraints
    if "validation" in command:
        constraints["constraints"].extend(build_validation_constraints(command["validation"]))

    # Add error handling constraints
    if "error_handling" in command:
        constraints["constraints"].extend(
            build_error_handling_constraints(command["error_handling"])
        )

    # Add output format constraints
    if "output" in command:
        for output_type, config in command["output"].items():
            constraints["constraints"].append(
                {
                    "type": f"output_{output_type}",
                    "message": config.get("message", ""),
                    "color": config.get("color"),
                    "stream": config.get("stream", "stdout"),
                }
            )

    # Add dependency information
    if "dependencies" in command:
        constraints["metadata"]["dependencies"] = command["dependencies"]

    # Add type hint settings
    if "type_hints" in command:
        constraints["metadata"]["type_hints"] = command["type_hints"]

    return constraints


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Convert CLI specification YAML to Ananke constraint format"
    )
    parser.add_argument("spec_file", type=Path, help="Path to CLI specification YAML file")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output constraint file (default: stdout)",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable verbose output",
    )

    args = parser.parse_args()

    # Verbose logging
    if args.verbose:
        print(f"Loading specification from: {args.spec_file}", file=sys.stderr)

    # Load and parse specification
    spec = load_yaml_spec(args.spec_file)

    if args.verbose:
        print("Converting specification to constraints...", file=sys.stderr)

    # Convert to constraints
    constraints = convert_spec_to_constraints(spec)

    # Format output
    indent = 2 if args.pretty else None
    output_json = json.dumps(constraints, indent=indent)

    # Write output
    if args.output:
        try:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(output_json)
                f.write("\n")

            if args.verbose:
                print(f"Constraints written to: {args.output}", file=sys.stderr)
        except IOError as e:
            print(f"Error: Cannot write to {args.output}: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(output_json)

    if args.verbose:
        print("Conversion complete!", file=sys.stderr)


if __name__ == "__main__":
    main()
