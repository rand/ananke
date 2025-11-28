# Example 03: React Component Generator

## Overview

Generate accessible, design-system-compliant React components following established patterns from your codebase. This example demonstrates how Ananke extracts component patterns, integrates design tokens, and generates new components with TypeScript types, accessibility features, and comprehensive test coverage.

## Value Proposition

**Problem**: Building UI components consistently across a large codebase is challenging. Developers must remember to:
- Apply correct design tokens (colors, spacing, typography)
- Implement accessibility attributes (ARIA labels, keyboard navigation)
- Write TypeScript interfaces with proper prop validation
- Create comprehensive test coverage
- Follow established component patterns

Manual component creation is error-prone and time-consuming, leading to inconsistent UX, accessibility violations, and technical debt.

**Solution**: Ananke extracts patterns from existing components, merges them with design system constraints, and generates new components that automatically follow best practices.

**ROI**:
- **Time Saved**: 2-3 hours per component (from 3 hours to 30 minutes)
- **Errors Prevented**: Eliminates 80% of accessibility violations caught in code review
- **Consistency**: 100% design token compliance, no hardcoded colors or spacing
- **Quality**: Every generated component includes tests and TypeScript types

## Prerequisites

- **Node.js**: 18+ (for TypeScript and React Testing Library)
- **Zig**: 0.15.1+ (for Ananke CLI)
- **Ananke**: Built and accessible in PATH
- **Setup Time**: Less than 10 minutes

## Quick Start

```bash
cd examples/production/03-react-component-generator
npm install
./run.sh
```

This will:
1. Extract component patterns from `input/Button.tsx`
2. Convert design tokens from `input/design-system.json` to constraints
3. Generate a new `Input` component in `output/Input.tsx`
4. Validate the generated component with tests

## Step-by-Step Guide

### 1. Input Preparation

The example includes two input files demonstrating the pattern:

**`input/Button.tsx`**: An example component showing best practices
- TypeScript interface with comprehensive prop types
- WCAG 2.1 AA compliant accessibility (ARIA attributes, keyboard support)
- Design system integration (tokens for colors, spacing, typography)
- Semantic HTML with proper button element usage
- Loading and disabled states

**`input/design-system.json`**: Design tokens exported from your design system
- Color palette (primary, secondary, neutral, semantic colors)
- Spacing scale (4px base, 8px - 64px range)
- Typography (font families, sizes, weights, line heights)
- Border radius values
- Shadow definitions

These files represent realistic production code, not toy examples.

### 2. Constraint Extraction

Extract component patterns from the existing Button component:

```bash
ananke extract input/Button.tsx \
  --language typescript \
  -o constraints/extracted.json
```

This captures:
- Component structure (functional component with TypeScript)
- Prop interface patterns (required vs optional, types, defaults)
- Accessibility patterns (ARIA attributes, semantic HTML)
- Event handler patterns (onClick, onFocus, onBlur)
- Conditional rendering patterns (loading, disabled states)

### 3. Design Token Integration

Convert design system tokens to Ananke constraints:

```bash
python scripts/design_tokens_to_constraints.py \
  input/design-system.json \
  constraints/extracted.json \
  -o constraints/merged.json
```

This script:
1. Parses the design system JSON
2. Creates constraints for allowed colors, spacing, typography
3. Merges with extracted component patterns
4. Validates token references (ensures tokens exist)

The merged constraints ensure generated components only use approved design tokens, preventing hardcoded values.

### 4. Code Generation

Generate the new Input component:

```bash
ananke generate "Create a React Input component with the following features:
- Text input with label and error message support
- Accessibility: proper ARIA labels, error announcements, keyboard navigation
- Design system integration: use tokens for colors, spacing, typography
- TypeScript: comprehensive interface with prop validation
- States: normal, focused, error, disabled
- Props: value, onChange, label, error, placeholder, disabled, required
Follow the same patterns as the Button component." \
  --constraints constraints/merged.json \
  --max-tokens 2000 \
  -o output/Input.tsx
```

The generation prompt is detailed and specific. Ananke uses the constraints to ensure:
- Only design tokens are used (no hardcoded colors)
- Accessibility attributes are included
- TypeScript types match established patterns
- Component structure follows existing conventions

### 5. Validation

Validate the generated component with three levels of tests:

**Syntax Validation** (fast, <1s):
```bash
npx tsc --noEmit output/Input.tsx
```

**Functional Tests** (medium, 5-10s):
```bash
npm test tests/test_input.test.tsx
```

**Accessibility Tests** (comprehensive):
```bash
npm test tests/accessibility.test.tsx
```

The test suite validates:
- Component renders without errors
- Props work correctly (value, onChange, disabled, etc.)
- Keyboard navigation functions (Tab, Enter, Escape)
- ARIA attributes are present and correct
- Error states are announced to screen readers
- Focus management works properly
- Design tokens are applied correctly

## Expected Output

The generated `output/Input.tsx` should include:

```typescript
import React from 'react';

interface InputProps {
  value: string;
  onChange: (value: string) => void;
  label: string;
  error?: string;
  placeholder?: string;
  disabled?: boolean;
  required?: boolean;
}

export const Input: React.FC<InputProps> = ({
  value,
  onChange,
  label,
  error,
  placeholder,
  disabled = false,
  required = false,
}) => {
  // Implementation with:
  // - Proper ARIA labels and descriptions
  // - Design token usage for styling
  // - Error state handling
  // - Keyboard navigation support
  // - Focus management
};
```

Key features:
- **TypeScript Interface**: Comprehensive prop types with optional/required distinction
- **Accessibility**: ARIA labels, error announcements, keyboard support
- **Design Tokens**: Colors, spacing, typography from `design-system.json`
- **Error Handling**: Visual and programmatic error state
- **Focus Management**: Proper focus indicators and keyboard navigation

## Customization

### Adapt for Your Use Case

1. **Replace `input/Button.tsx`** with your own component demonstrating your patterns
   - Include your accessibility practices
   - Show your TypeScript conventions
   - Demonstrate your styling approach

2. **Update `input/design-system.json`** with your design tokens
   - Export from Figma, Style Dictionary, or your design tool
   - Include all tokens (colors, spacing, typography, shadows, etc.)
   - Use consistent naming conventions

3. **Modify `scripts/design_tokens_to_constraints.py`** if needed
   - Add constraints for additional token types
   - Customize validation rules
   - Integrate with your design system format

4. **Adjust the generation prompt** for your component
   - Specify exact props and behavior
   - Include edge cases and states
   - Reference your component naming conventions

5. **Extend `tests/test_input.test.tsx`** for your requirements
   - Add tests for custom props
   - Validate your specific accessibility requirements
   - Test integration with your state management

### Example Modifications

**Generate a Select component**:
```bash
ananke generate "Create a React Select component with:
- Dropdown with keyboard navigation (Arrow keys, Enter, Escape)
- Accessibility: ARIA combobox pattern, option announcements
- Design tokens for styling
- Props: options, value, onChange, label, error, disabled
- Multi-select support with checkboxes
Follow Button component patterns." \
  --constraints constraints/merged.json \
  --max-tokens 2500 \
  -o output/Select.tsx
```

**Generate a Modal component**:
```bash
ananke generate "Create a React Modal component with:
- Overlay and content container
- Accessibility: focus trap, Escape key closes, ARIA dialog role
- Design tokens for colors, shadows, spacing
- Props: isOpen, onClose, title, children
- Portal rendering (React.createPortal)
Follow Button component patterns." \
  --constraints constraints/merged.json \
  --max-tokens 2500 \
  -o output/Modal.tsx
```

**Generate with your own tokens**:
```bash
# Update design-system.json with your Figma export
cp ~/Downloads/figma-tokens.json input/design-system.json

# Re-run the pipeline
./run.sh
```

## Troubleshooting

### Issue: Generated component has TypeScript errors

**Symptoms**: `npx tsc --noEmit` reports type errors

**Cause**: Constraints may not fully capture your TypeScript patterns, or the generation prompt conflicts with extracted patterns

**Solution**:
1. Check `constraints/extracted.json` to verify patterns were extracted correctly
2. Ensure `input/Button.tsx` compiles without errors
3. Make the generation prompt more specific about types
4. Add explicit type constraints to `scripts/design_tokens_to_constraints.py`

### Issue: Generated component missing accessibility attributes

**Symptoms**: `tests/accessibility.test.tsx` fails with missing ARIA attributes

**Cause**: Input component (`Button.tsx`) may not demonstrate all required accessibility patterns, or generation prompt is not specific enough

**Solution**:
1. Enhance `input/Button.tsx` with comprehensive ARIA attributes
2. Update generation prompt to explicitly request accessibility features
3. Add accessibility constraints to `constraints/merged.json` manually if needed
4. Check that `scripts/design_tokens_to_constraints.py` includes accessibility rules

Example constraint addition:
```json
{
  "accessibility": {
    "required_attributes": ["aria-label", "role"],
    "keyboard_support": ["Tab", "Enter", "Escape"],
    "focus_management": true
  }
}
```

### Issue: Generated component uses hardcoded colors instead of design tokens

**Symptoms**: Code contains `color: '#3b82f6'` instead of `color: tokens.colors.primary.500`

**Cause**: Design tokens weren't properly converted to constraints, or constraints weren't enforced during generation

**Solution**:
1. Verify `input/design-system.json` has correct structure
2. Check `constraints/merged.json` includes design token constraints
3. Ensure generation prompt mentions "use design tokens from design-system.json"
4. Update `scripts/design_tokens_to_constraints.py` to enforce token usage:

```python
# Add to constraints
constraints["style"] = {
    "allowed_colors": [f"tokens.colors.{path}" for path in color_paths],
    "disallowed_patterns": ["#[0-9a-f]{3,6}", "rgb\\(", "rgba\\("],
}
```

### Issue: Tests fail with "Cannot find module 'react'"

**Symptoms**: `npm test` fails with module resolution errors

**Cause**: Dependencies not installed or package.json is missing

**Solution**:
```bash
npm install
```

If the issue persists:
```bash
# Clean install
rm -rf node_modules package-lock.json
npm install
```

### Issue: Generated component doesn't match your code style

**Symptoms**: Indentation, quotes, or formatting differs from your codebase

**Cause**: Ananke doesn't enforce style, relies on post-generation formatting

**Solution**:
1. Run your code formatter on the output:
```bash
npx prettier --write output/Input.tsx
# or
npx eslint --fix output/Input.tsx
```

2. Add formatting step to `run.sh`:
```bash
# After generation
npx prettier --write output/*.tsx
```

### Issue: Component generates but is too simple/complex

**Symptoms**: Generated component doesn't match expected complexity

**Cause**: Generation prompt is too vague or constraints don't capture enough patterns

**Solution**:
1. **Too simple**: Make prompt more detailed, add specific requirements
2. **Too complex**: Simplify prompt, focus on core functionality
3. Adjust `--max-tokens` parameter (increase for more complex, decrease for simpler)
4. Provide more example components in `input/` to establish better patterns

## Design System Integration

### Supported Token Types

The example supports these design token categories:

**Colors**:
- Primary palette (50-900 shades)
- Secondary palette
- Neutral/gray palette
- Semantic colors (success, warning, error, info)

**Spacing**:
- Base unit (typically 4px)
- Scale (0, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64)

**Typography**:
- Font families (primary, secondary, mono)
- Font sizes (xs, sm, base, lg, xl, 2xl, etc.)
- Font weights (light, regular, medium, semibold, bold)
- Line heights

**Borders**:
- Border radius (sm, md, lg, full)
- Border widths

**Shadows**:
- Elevation levels (sm, md, lg, xl)

### Adding Custom Token Types

Edit `scripts/design_tokens_to_constraints.py`:

```python
def convert_design_tokens(tokens):
    constraints = {
        "colors": extract_colors(tokens.get("colors", {})),
        "spacing": extract_spacing(tokens.get("spacing", {})),
        "typography": extract_typography(tokens.get("typography", {})),

        # Add custom token type
        "animation": extract_animation(tokens.get("animation", {})),
    }
    return constraints

def extract_animation(animation_tokens):
    """Convert animation tokens to constraints."""
    return {
        "durations": animation_tokens.get("durations", {}),
        "easings": animation_tokens.get("easings", {}),
    }
```

## Accessibility Guide

Generated components follow WCAG 2.1 AA guidelines:

### Keyboard Navigation
- **Tab**: Move focus to/from component
- **Enter/Space**: Activate (for buttons/clickable elements)
- **Escape**: Close/cancel (for modals/dropdowns)
- **Arrow keys**: Navigate options (for selects/menus)

### Screen Reader Support
- Semantic HTML elements (`<button>`, `<input>`, `<label>`)
- ARIA labels for non-text elements
- ARIA descriptions for additional context
- ARIA live regions for dynamic updates
- Error announcements via `aria-invalid` and `aria-describedby`

### Focus Management
- Visible focus indicators (outline or border)
- Logical tab order
- Focus trap for modals
- Focus restoration after interactions

### Color Contrast
- Text: 4.5:1 minimum ratio
- Interactive elements: 3:1 minimum ratio
- Design tokens enforce contrast requirements

### Testing Accessibility

The example includes accessibility tests using `@axe-core/react`:

```bash
npm test tests/accessibility.test.tsx
```

These tests validate:
- ARIA attribute presence and correctness
- Keyboard navigation functionality
- Color contrast ratios
- Semantic HTML structure
- Focus management

## Next Steps

1. **Try customizing the input** for your design system
   - Export tokens from your design tool
   - Add your own component patterns
   - Generate components you actually need

2. **Integrate into your workflow**
   - Add to your component library generation pipeline
   - Create scripts for common component types
   - Automate testing and validation

3. **Explore related examples**
   - [Example 01: OpenAPI Route Generation](../01-openapi-route-generation/) - Backend code generation
   - [Example 05: Test Generator](../05-test-generator/) - Automated test creation
   - [Tutorial Examples](/examples/01-05/) - Learn core Ananke concepts

4. **Extend the example**
   - Add Storybook integration
   - Generate component documentation
   - Create visual regression tests
   - Integrate with your CI/CD pipeline

## Learn More

- [Ananke Documentation](../../../docs/) - Core concepts and API reference
- [React Accessibility](https://react.dev/learn/accessibility) - React a11y best practices
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/) - Web accessibility standards
- [Design Tokens W3C Spec](https://www.w3.org/community/design-tokens/) - Token format specification
- [Testing Library](https://testing-library.com/react) - Component testing best practices
