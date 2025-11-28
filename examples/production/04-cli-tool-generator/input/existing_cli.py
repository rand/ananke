#!/usr/bin/env python3
"""Example CLI command showing established patterns.

This file demonstrates best practices for Click CLI commands that will be
extracted as patterns for generating new commands.
"""

import click
import json
import sys
from pathlib import Path
from typing import Optional


def validate_file_exists(file_path: str) -> Path:
    """Validate that a file exists and is readable.

    Args:
        file_path: Path to the file to validate

    Returns:
        Path object if valid

    Raises:
        SystemExit: If file doesn't exist or isn't readable
    """
    path = Path(file_path)
    if not path.exists():
        click.echo(
            click.style("Error:", fg="red", bold=True) + f" File not found: {file_path}",
            err=True,
        )
        sys.exit(2)

    if not path.is_file():
        click.echo(
            click.style("Error:", fg="red", bold=True) + f" Not a file: {file_path}",
            err=True,
        )
        sys.exit(2)

    return path


def load_json_file(file_path: Path) -> dict:
    """Load and parse a JSON file.

    Args:
        file_path: Path to the JSON file

    Returns:
        Parsed JSON data as a dictionary

    Raises:
        SystemExit: If JSON is malformed
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        click.echo(
            click.style("Error:", fg="red", bold=True)
            + f" Invalid JSON in {file_path}: {e.msg} at line {e.lineno}, column {e.colno}",
            err=True,
        )
        sys.exit(2)
    except IOError as e:
        click.echo(
            click.style("Error:", fg="red", bold=True) + f" Cannot read {file_path}: {e}",
            err=True,
        )
        sys.exit(2)


@click.command()
@click.argument("config_file", type=click.Path(exists=False))
@click.option(
    "--output",
    "-o",
    type=click.Path(),
    help="Output file path (default: stdout)",
)
@click.option(
    "--format",
    type=click.Choice(["json", "yaml", "text"], case_sensitive=False),
    default="json",
    help="Output format",
)
@click.option(
    "--verbose",
    "-v",
    is_flag=True,
    help="Enable verbose output",
)
@click.option(
    "--strict",
    is_flag=True,
    help="Enable strict validation mode",
)
def process_config(
    config_file: str,
    output: Optional[str],
    format: str,
    verbose: bool,
    strict: bool,
) -> None:
    """Process configuration file and output results.

    This command demonstrates standard CLI patterns:
    - Argument for required input file
    - Options for optional parameters
    - Boolean flags for toggles
    - Choice validation for enums
    - Proper error handling and exit codes
    - Helpful error messages
    - Comprehensive help text

    Examples:

        # Basic usage
        process-config config.json

        # Save to file
        process-config config.json --output result.json

        # Use different format
        process-config config.json --format yaml

        # Enable verbose mode
        process-config config.json -v

        # Strict validation
        process-config config.json --strict

    Exit Codes:
        0 - Success
        1 - Validation failure
        2 - Runtime error (file not found, invalid JSON, etc.)
    """
    # Verbose logging
    if verbose:
        click.echo(f"Processing config file: {config_file}", err=True)
        click.echo(f"Output format: {format}", err=True)
        if strict:
            click.echo("Strict mode: enabled", err=True)

    # Validate input file exists
    config_path = validate_file_exists(config_file)

    # Load configuration
    if verbose:
        click.echo("Loading configuration...", err=True)

    config_data = load_json_file(config_path)

    # Validate configuration structure
    if strict:
        required_fields = ["name", "version"]
        missing_fields = [field for field in required_fields if field not in config_data]

        if missing_fields:
            click.echo(
                click.style("Validation Error:", fg="red", bold=True)
                + f" Missing required fields: {', '.join(missing_fields)}",
                err=True,
            )
            sys.exit(1)

    # Process configuration
    if verbose:
        click.echo("Processing configuration...", err=True)

    result = {
        "status": "success",
        "config": config_data,
        "metadata": {
            "format": format,
            "strict_mode": strict,
        },
    }

    # Format output
    if format == "json":
        output_text = json.dumps(result, indent=2)
    elif format == "yaml":
        # Simplified YAML output for demonstration
        output_text = f"status: {result['status']}\n"
        output_text += f"config:\n"
        for key, value in config_data.items():
            output_text += f"  {key}: {value}\n"
    else:  # text
        output_text = f"Status: {result['status']}\n"
        output_text += f"Config: {config_data.get('name', 'N/A')} v{config_data.get('version', 'N/A')}\n"

    # Write output
    if output:
        try:
            output_path = Path(output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(output_text)

            click.echo(
                click.style("Success:", fg="green", bold=True) + f" Output written to {output}"
            )
        except IOError as e:
            click.echo(
                click.style("Error:", fg="red", bold=True) + f" Cannot write to {output}: {e}",
                err=True,
            )
            sys.exit(2)
    else:
        # Output to stdout
        click.echo(output_text)

    # Success
    sys.exit(0)


if __name__ == "__main__":
    process_config()
