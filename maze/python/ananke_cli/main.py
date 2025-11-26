"""
Ananke CLI: Command-line interface for constraint-driven code generation

Provides commands for configuring, extracting constraints, compiling,
generating code, and health checking the Ananke inference service.
"""

import click
import asyncio
import json
import sys
import os
from pathlib import Path
from typing import Optional

try:
    from ananke import Ananke, PyConstraintIR, PyGenerationRequest, PyGenerationContext
except ImportError:
    click.echo("Error: Ananke module not installed. Run 'maturin develop' first.", err=True)
    sys.exit(1)


@click.group()
@click.version_option(version="0.1.0")
def cli():
    """Ananke: Constraint-driven code generation powered by vLLM + llguidance

    Use 'ananke <command> --help' for detailed command usage.

    Environment Variables:
      ANANKE_MODAL_ENDPOINT - Modal inference endpoint URL
      ANANKE_MODAL_API_KEY  - Modal API key for authentication
      ANANKE_MODEL          - Model name (default: meta-llama/Llama-3.1-8B-Instruct)
    """
    pass


@cli.command()
@click.option('--endpoint', envvar='ANANKE_MODAL_ENDPOINT', required=True,
              show_envvar=True, help='Modal inference endpoint URL')
@click.option('--api-key', envvar='ANANKE_MODAL_API_KEY',
              show_envvar=True, help='Modal API key (optional)')
@click.option('--model', envvar='ANANKE_MODEL',
              show_envvar=True, default='meta-llama/Llama-3.1-8B-Instruct',
              help='Model name to use')
def config(endpoint, api_key, model):
    """Show current Ananke configuration

    Displays the current configuration settings including endpoint,
    model, and whether API key is configured.

    Example:
      ananke config --endpoint https://your-app.modal.run
    """
    click.echo("Ananke Configuration:")
    click.echo(f"  Endpoint: {endpoint}")
    click.echo(f"  Model:    {model}")
    click.echo(f"  API Key:  {'(configured)' if api_key else '(not set)'}")


@cli.command()
@click.argument('prompt')
@click.option('--max-tokens', default=2048, type=int,
              help='Maximum tokens to generate (default: 2048)')
@click.option('--temperature', default=0.7, type=float,
              help='Sampling temperature (default: 0.7)')
@click.option('--constraints', type=click.Path(exists=True),
              help='JSON file containing constraints')
@click.option('--output', '-o', type=click.Path(),
              help='Output file (default: stdout)')
@click.option('--endpoint', envvar='ANANKE_MODAL_ENDPOINT', required=True,
              help='Modal inference endpoint URL')
@click.option('--api-key', envvar='ANANKE_MODAL_API_KEY',
              help='Modal API key')
@click.option('--model', envvar='ANANKE_MODEL',
              default='meta-llama/Llama-3.1-8B-Instruct',
              help='Model name')
def generate(prompt, max_tokens, temperature, constraints, output, endpoint, api_key, model):
    """Generate code with optional constraints

    Generates code based on the provided prompt, optionally applying
    constraints from a JSON file.

    Examples:
      ananke generate "def add(a, b):" --max-tokens 100

      ananke generate "Create a user API" --constraints schema.json

      ananke generate "Implement login" -o login.py
    """
    async def _generate():
        with click.progressbar(length=1, label='Initializing') as bar:
            # Initialize Ananke
            ananke = Ananke(
                modal_endpoint=endpoint,
                modal_api_key=api_key,
                model=model,
                enable_cache=True
            )
            bar.update(1)

        # Load constraints if provided
        constraints_ir = []
        if constraints:
            with click.open_file(constraints, 'r') as f:
                constraints_data = json.load(f)

                if isinstance(constraints_data, list):
                    for c in constraints_data:
                        constraint = PyConstraintIR(
                            name=c.get('name', 'constraint'),
                            json_schema=json.dumps(c.get('json_schema')) if c.get('json_schema') else None,
                            grammar=c.get('grammar'),
                            regex_patterns=c.get('regex_patterns', [])
                        )
                        constraints_ir.append(constraint)
                else:
                    # Single constraint
                    constraint = PyConstraintIR(
                        name=constraints_data.get('name', 'constraint'),
                        json_schema=json.dumps(constraints_data.get('json_schema')) if constraints_data.get('json_schema') else None,
                        grammar=constraints_data.get('grammar'),
                        regex_patterns=constraints_data.get('regex_patterns', [])
                    )
                    constraints_ir.append(constraint)

        # Create generation context
        context = PyGenerationContext(
            current_file="<cli>",
            language="unknown",
            project_root=str(Path.cwd())
        )

        # Create request
        request = PyGenerationRequest(
            prompt=prompt,
            constraints_ir=constraints_ir,
            max_tokens=max_tokens,
            temperature=temperature,
            context=context
        )

        # Generate with progress
        with click.progressbar(length=1, label='Generating') as bar:
            try:
                response = await ananke.generate(request)
                bar.update(1)
            except Exception as e:
                click.echo(f"Error: Generation failed: {e}", err=True)
                sys.exit(1)

        # Output result
        result = {
            "generated_text": response.code,
            "finish_reason": response.finish_reason,
            "tokens_generated": response.tokens_generated,
            "constraint_satisfied": response.validation.all_satisfied,
            "model": response.provenance.model,
            "timestamp": response.metadata.timestamp
        }

        if output:
            with click.open_file(output, 'w') as f:
                if output.endswith('.json'):
                    json.dump(result, f, indent=2)
                else:
                    f.write(response.code)
            click.echo(f"Generated code saved to: {output}")
        else:
            click.echo("\n" + "=" * 80)
            click.echo("Generated Code:")
            click.echo("=" * 80)
            click.echo(response.code)
            click.echo("=" * 80)
            click.echo(f"Tokens: {response.tokens_generated} | "
                      f"Finish: {response.finish_reason} | "
                      f"Constraints: {'satisfied' if response.validation.all_satisfied else 'violated'}")

    try:
        asyncio.run(_generate())
    except KeyboardInterrupt:
        click.echo("\nGeneration cancelled.", err=True)
        sys.exit(130)


@cli.command()
@click.argument('constraints-file', type=click.Path(exists=True))
@click.option('--output', '-o', type=click.Path(),
              help='Output file for compiled constraints (default: stdout)')
@click.option('--endpoint', envvar='ANANKE_MODAL_ENDPOINT', required=True,
              help='Modal inference endpoint URL')
@click.option('--api-key', envvar='ANANKE_MODAL_API_KEY',
              help='Modal API key')
@click.option('--model', envvar='ANANKE_MODEL',
              default='meta-llama/Llama-3.1-8B-Instruct',
              help='Model name')
def compile(constraints_file, output, endpoint, api_key, model):
    """Compile constraints to llguidance format

    Compiles constraints from a JSON file to the llguidance format
    used by the inference engine. Useful for validating constraints
    and inspecting the compiled output.

    Examples:
      ananke compile constraints.json

      ananke compile schema.json --output compiled.json
    """
    async def _compile():
        # Initialize Ananke
        ananke = Ananke(
            modal_endpoint=endpoint,
            modal_api_key=api_key,
            model=model,
            enable_cache=True
        )

        # Load constraints
        with click.open_file(constraints_file, 'r') as f:
            constraints_data = json.load(f)

        constraints_ir = []
        if isinstance(constraints_data, list):
            for c in constraints_data:
                constraint = PyConstraintIR(
                    name=c.get('name', 'constraint'),
                    json_schema=json.dumps(c.get('json_schema')) if c.get('json_schema') else None,
                    grammar=c.get('grammar'),
                    regex_patterns=c.get('regex_patterns', [])
                )
                constraints_ir.append(constraint)
        else:
            constraint = PyConstraintIR(
                name=constraints_data.get('name', 'constraint'),
                json_schema=json.dumps(constraints_data.get('json_schema')) if constraints_data.get('json_schema') else None,
                grammar=constraints_data.get('grammar'),
                regex_patterns=constraints_data.get('regex_patterns', [])
            )
            constraints_ir.append(constraint)

        # Compile
        with click.progressbar(length=1, label='Compiling constraints') as bar:
            try:
                compiled = await ananke.compile_constraints(constraints_ir)
                bar.update(1)
            except Exception as e:
                click.echo(f"Error: Compilation failed: {e}", err=True)
                sys.exit(1)

        # Output
        result = {
            "hash": compiled["hash"],
            "compiled_at": compiled["compiled_at"],
            "schema_preview": str(compiled["schema"])[:200] + "..." if len(str(compiled["schema"])) > 200 else str(compiled["schema"])
        }

        if output:
            with click.open_file(output, 'w') as f:
                json.dump(compiled, f, indent=2)
            click.echo(f"Compiled constraints saved to: {output}")
        else:
            click.echo(json.dumps(result, indent=2))

    try:
        asyncio.run(_compile())
    except KeyboardInterrupt:
        click.echo("\nCompilation cancelled.", err=True)
        sys.exit(130)


@cli.command()
@click.option('--endpoint', envvar='ANANKE_MODAL_ENDPOINT', required=True,
              help='Modal inference endpoint URL')
@click.option('--api-key', envvar='ANANKE_MODAL_API_KEY',
              help='Modal API key')
@click.option('--model', envvar='ANANKE_MODEL',
              default='meta-llama/Llama-3.1-8B-Instruct',
              help='Model name')
def health(endpoint, api_key, model):
    """Check inference service health

    Performs a health check against the Modal inference service
    to verify it's running and accessible.

    Example:
      ananke health
    """
    async def _health():
        # Initialize Ananke
        ananke = Ananke(
            modal_endpoint=endpoint,
            modal_api_key=api_key,
            model=model
        )

        # Health check
        with click.progressbar(length=1, label='Checking health') as bar:
            try:
                is_healthy = await ananke.health_check()
                bar.update(1)
            except Exception as e:
                click.echo(f"Error: Health check failed: {e}", err=True)
                sys.exit(1)

        if is_healthy:
            click.echo("Status: HEALTHY")
            click.echo(f"Endpoint: {endpoint}")
            click.echo(f"Model: {model}")
        else:
            click.echo("Status: UNHEALTHY", err=True)
            sys.exit(1)

    try:
        asyncio.run(_health())
    except KeyboardInterrupt:
        click.echo("\nHealth check cancelled.", err=True)
        sys.exit(130)


@cli.command()
@click.option('--endpoint', envvar='ANANKE_MODAL_ENDPOINT', required=True,
              help='Modal inference endpoint URL')
@click.option('--api-key', envvar='ANANKE_MODAL_API_KEY',
              help='Modal API key')
@click.option('--model', envvar='ANANKE_MODEL',
              default='meta-llama/Llama-3.1-8B-Instruct',
              help='Model name')
@click.option('--clear', is_flag=True,
              help='Clear the cache')
def cache(endpoint, api_key, model, clear):
    """View or clear constraint compilation cache

    Shows cache statistics or clears the cache if --clear is specified.
    The cache stores compiled constraints for faster subsequent compilations.

    Examples:
      ananke cache                 # Show cache stats

      ananke cache --clear         # Clear the cache
    """
    async def _cache():
        # Initialize Ananke
        ananke = Ananke(
            modal_endpoint=endpoint,
            modal_api_key=api_key,
            model=model,
            enable_cache=True
        )

        if clear:
            with click.progressbar(length=1, label='Clearing cache') as bar:
                try:
                    await ananke.clear_cache()
                    bar.update(1)
                except Exception as e:
                    click.echo(f"Error: Failed to clear cache: {e}", err=True)
                    sys.exit(1)
            click.echo("Cache cleared successfully")
        else:
            try:
                stats = await ananke.cache_stats()
            except Exception as e:
                click.echo(f"Error: Failed to get cache stats: {e}", err=True)
                sys.exit(1)

            click.echo("Cache Statistics:")
            click.echo(f"  Size:  {stats['size']} entries")
            click.echo(f"  Limit: {stats['limit']} entries")

            if stats['size'] > 0:
                usage_pct = (stats['size'] / stats['limit']) * 100
                click.echo(f"  Usage: {usage_pct:.1f}%")

    try:
        asyncio.run(_cache())
    except KeyboardInterrupt:
        click.echo("\nCache operation cancelled.", err=True)
        sys.exit(130)


if __name__ == '__main__':
    cli()
