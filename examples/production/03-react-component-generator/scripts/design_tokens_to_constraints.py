#!/usr/bin/env python3
"""
Design Tokens to Constraints Converter

Converts design system tokens (colors, spacing, typography) to Ananke constraints
and merges them with extracted component patterns.

Usage:
    python design_tokens_to_constraints.py \
        input/design-system.json \
        constraints/extracted.json \
        -o constraints/merged.json
"""

import json
import sys
import argparse
from pathlib import Path
from typing import Dict, Any, List


def extract_color_paths(colors: Dict[str, Any], prefix: str = "") -> List[str]:
    """
    Recursively extract all color token paths.

    Args:
        colors: Color token object (nested dict)
        prefix: Current path prefix

    Returns:
        List of color token paths (e.g., "primary.600", "neutral.50")
    """
    paths = []

    for key, value in colors.items():
        current_path = f"{prefix}.{key}" if prefix else key

        if isinstance(value, dict):
            # Nested object, recurse
            paths.extend(extract_color_paths(value, current_path))
        else:
            # Leaf node (actual color value)
            paths.append(current_path)

    return paths


def extract_spacing_values(spacing: Dict[str, str]) -> Dict[str, str]:
    """
    Extract spacing values and validate they are CSS length units.

    Args:
        spacing: Spacing token object

    Returns:
        Dictionary of valid spacing tokens
    """
    valid_spacing = {}

    for key, value in spacing.items():
        # Validate that value is a CSS length (px, rem, em, etc.)
        if isinstance(value, str) and (
            value.endswith("px")
            or value.endswith("rem")
            or value.endswith("em")
            or value == "0"
        ):
            valid_spacing[key] = value

    return valid_spacing


def extract_typography_constraints(typography: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract typography constraints (font families, sizes, weights, line heights).

    Args:
        typography: Typography token object

    Returns:
        Structured typography constraints
    """
    return {
        "fontFamilies": list(typography.get("fontFamily", {}).keys()),
        "fontSizes": list(typography.get("fontSize", {}).keys()),
        "fontWeights": list(typography.get("fontWeight", {}).keys()),
        "lineHeights": list(typography.get("lineHeight", {}).keys()),
    }


def create_style_constraints(tokens: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create style constraints that prevent hardcoded values.

    Args:
        tokens: Complete design token object

    Returns:
        Style constraints enforcing token usage
    """
    color_paths = extract_color_paths(tokens.get("colors", {}))

    constraints = {
        "allowed_color_tokens": color_paths,
        "allowed_spacing_tokens": list(tokens.get("spacing", {}).keys()),
        "disallowed_patterns": {
            "hardcoded_colors": [
                r"#[0-9a-fA-F]{3,6}",  # Hex colors
                r"rgb\(",  # RGB colors
                r"rgba\(",  # RGBA colors
                r"hsl\(",  # HSL colors
                r"hsla\(",  # HSLA colors
            ],
            "hardcoded_spacing": [
                r"\d+px(?!\s*\/\*\s*token)",  # Pixel values without token comment
                r"\d+rem(?!\s*\/\*\s*token)",  # Rem values without token comment
            ],
        },
        "required_practices": [
            "Use design tokens for all colors",
            "Use design tokens for all spacing",
            "Use design tokens for typography",
            "Avoid hardcoded values",
        ],
    }

    return constraints


def merge_constraints(
    extracted: Dict[str, Any], design_tokens: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Merge extracted component constraints with design token constraints.

    Args:
        extracted: Constraints extracted from existing components
        design_tokens: Design system token constraints

    Returns:
        Unified constraint object
    """
    merged = extracted.copy()

    # Add design system section
    merged["designSystem"] = {
        "colors": extract_color_paths(design_tokens.get("colors", {})),
        "spacing": extract_spacing_values(design_tokens.get("spacing", {})),
        "typography": extract_typography_constraints(
            design_tokens.get("typography", {})
        ),
        "borderRadius": list(design_tokens.get("borderRadius", {}).keys()),
        "shadows": list(design_tokens.get("shadows", {}).keys()),
    }

    # Add style enforcement constraints
    merged["styleConstraints"] = create_style_constraints(design_tokens)

    # Add accessibility requirements
    merged["accessibility"] = {
        "required_attributes": [
            "aria-label or aria-labelledby for interactive elements",
            "aria-invalid for error states",
            "aria-describedby for error messages",
            "role attributes where appropriate",
        ],
        "keyboard_support": {
            "required_keys": ["Tab", "Enter", "Escape"],
            "focus_management": "Visible focus indicators required",
        },
        "semantic_html": "Use appropriate HTML elements (button, input, label, etc.)",
        "color_contrast": {
            "minimum_ratio_text": 4.5,
            "minimum_ratio_interactive": 3.0,
        },
    }

    return merged


def validate_tokens(tokens: Dict[str, Any]) -> bool:
    """
    Validate that design tokens have required structure.

    Args:
        tokens: Design token object to validate

    Returns:
        True if valid, False otherwise
    """
    required_sections = ["colors", "spacing", "typography"]

    for section in required_sections:
        if section not in tokens:
            print(f"Error: Missing required section '{section}' in design tokens")
            return False

    # Validate colors have at least primary palette
    if "primary" not in tokens.get("colors", {}):
        print("Warning: No 'primary' color palette found")

    # Validate spacing has base units
    spacing = tokens.get("spacing", {})
    if "1" not in spacing and "4" not in spacing:
        print("Warning: No base spacing units (1 or 4) found")

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Convert design system tokens to Ananke constraints"
    )
    parser.add_argument(
        "design_tokens", type=Path, help="Path to design-system.json"
    )
    parser.add_argument(
        "extracted_constraints",
        type=Path,
        help="Path to extracted.json (from ananke extract)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        required=True,
        help="Output path for merged constraints",
    )

    args = parser.parse_args()

    # Load design tokens
    try:
        with open(args.design_tokens, "r") as f:
            design_tokens = json.load(f)
    except FileNotFoundError:
        print(f"Error: Design tokens file not found: {args.design_tokens}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in design tokens file: {e}")
        sys.exit(1)

    # Validate tokens
    if not validate_tokens(design_tokens):
        print("Warning: Design tokens validation failed, continuing anyway...")

    # Load extracted constraints
    try:
        with open(args.extracted_constraints, "r") as f:
            extracted = json.load(f)
    except FileNotFoundError:
        print(f"Error: Extracted constraints file not found: {args.extracted_constraints}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in extracted constraints file: {e}")
        sys.exit(1)

    # Merge constraints
    merged = merge_constraints(extracted, design_tokens)

    # Write output
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w") as f:
        json.dump(merged, f, indent=2)

    print(f"✓ Merged constraints written to {args.output}")
    print(f"  - Color tokens: {len(merged['designSystem']['colors'])}")
    print(f"  - Spacing tokens: {len(merged['designSystem']['spacing'])}")
    print(
        f"  - Font families: {len(merged['designSystem']['typography']['fontFamilies'])}"
    )
    print(f"  - Accessibility requirements: {len(merged['accessibility']['required_attributes'])}")


if __name__ == "__main__":
    main()
