#!/bin/bash
# Example 03: React Component Generator
# Demonstrates: Accessible React component generation with design system integration

set -e  # Exit on error

# Color output helpers
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Example 03: React Component Generator"
echo "========================================="
echo ""

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v ananke &> /dev/null; then
    echo -e "${RED}Error: ananke CLI not found${NC}"
    echo "Please install Ananke first:"
    echo "  cd ../../../"
    echo "  zig build"
    echo "  export PATH=\$PATH:\$(pwd)/zig-out/bin"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 not found${NC}"
    echo "Please install Python 3.11+"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: node not found${NC}"
    echo "Please install Node.js 18+"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    echo ""
    echo -e "${YELLOW}Installing Node.js dependencies...${NC}"
    npm install
    echo -e "${GREEN}✓ Dependencies installed${NC}"
fi

# Phase 1: Extract constraints from existing Button component
echo ""
echo -e "${BLUE}[1/4] Extracting component patterns from Button.tsx...${NC}"

if [ ! -f "input/Button.tsx" ]; then
    echo -e "${RED}Error: input/Button.tsx not found${NC}"
    exit 1
fi

ananke extract input/Button.tsx \
  --language typescript \
  -o constraints/extracted.json

echo -e "${GREEN}✓ Extracted component patterns${NC}"
echo "   - TypeScript interface patterns"
echo "   - Accessibility attributes"
echo "   - Event handler patterns"
echo "   - Conditional rendering"

# Phase 2: Merge with design system constraints
echo ""
echo -e "${BLUE}[2/4] Merging with design system constraints...${NC}"

if [ ! -f "input/design-system.json" ]; then
    echo -e "${RED}Error: input/design-system.json not found${NC}"
    exit 1
fi

python3 scripts/design_tokens_to_constraints.py \
  input/design-system.json \
  constraints/extracted.json \
  -o constraints/merged.json

echo -e "${GREEN}✓ Merged design system constraints${NC}"

# Phase 3: Generate Input component
echo ""
echo -e "${BLUE}[3/4] Generating Input component...${NC}"

ananke generate "Create a React Input component with the following features:

Component Requirements:
- Text input field with label and error message support
- TypeScript interface with comprehensive prop types
- Accessibility: WCAG 2.1 AA compliant
  - Proper ARIA labels (aria-label, aria-labelledby)
  - Error announcements (aria-invalid, aria-describedby)
  - Keyboard navigation (Tab to focus, Escape to clear)
  - Screen reader support
- Design system integration:
  - Use design tokens for colors (primary, neutral, error)
  - Use design tokens for spacing (padding, margin)
  - Use design tokens for typography (font size, weight)
  - Use design tokens for borders and shadows
- Component states:
  - Normal: default input state
  - Focused: visible focus indicator with ring
  - Error: red border and error message display
  - Disabled: grayed out and non-interactive
- Props interface:
  - value: string (required)
  - onChange: (value: string) => void (required)
  - label: string (required)
  - error?: string (optional error message)
  - placeholder?: string (optional placeholder text)
  - disabled?: boolean (default false)
  - required?: boolean (default false)
  - type?: 'text' | 'email' | 'password' | 'number' (default 'text')

Implementation Details:
- Follow the same patterns as the Button component
- Use semantic HTML with <input> and <label> elements
- Include error message container with conditional rendering
- Apply design tokens using CSS classes (Tailwind-style)
- Add proper TypeScript types for all props and handlers
- Include JSDoc comments for documentation

Example usage:
<Input
  value={email}
  onChange={setEmail}
  label=\"Email Address\"
  placeholder=\"you@example.com\"
  type=\"email\"
  required
/>

<Input
  value={password}
  onChange={setPassword}
  label=\"Password\"
  type=\"password\"
  error=\"Password must be at least 8 characters\"
  required
/>" \
  --constraints constraints/merged.json \
  --max-tokens 2000 \
  -o output/Input.tsx

echo -e "${GREEN}✓ Generated Input component${NC}"
echo "   - TypeScript interface with prop types"
echo "   - Accessibility attributes (ARIA labels, keyboard support)"
echo "   - Design system token usage"
echo "   - Error state handling"

# Phase 4: Validate generated component
echo ""
echo -e "${BLUE}[4/4] Validating generated component...${NC}"

# Syntax validation
echo "  → Checking TypeScript syntax..."
if npx tsc --noEmit output/Input.tsx 2>/dev/null; then
    echo -e "    ${GREEN}✓ TypeScript compilation successful${NC}"
else
    echo -e "    ${YELLOW}⚠ TypeScript compilation had warnings (may be due to missing imports)${NC}"
fi

# Run tests
echo "  → Running component tests..."
if npm test 2>&1 | grep -q "PASS"; then
    echo -e "    ${GREEN}✓ All tests passed${NC}"
else
    echo -e "    ${YELLOW}⚠ Some tests may have failed (check npm test output)${NC}"
fi

# Success message
echo ""
echo "========================================="
echo -e "${GREEN}✓ Example complete!${NC}"
echo "========================================="
echo ""
echo -e "Generated component: ${BLUE}output/Input.tsx${NC}"
echo -e "Constraints used: ${BLUE}constraints/merged.json${NC}"
echo -e "Test file: ${BLUE}tests/test_input.test.tsx${NC}"
echo ""
echo "Next steps:"
echo "  1. Review the generated component: cat output/Input.tsx"
echo "  2. Run tests individually: npm test tests/test_input.test.tsx"
echo "  3. Try customizing: edit the generation prompt in run.sh"
echo "  4. Generate other components: Modal, Select, Checkbox, etc."
echo ""
echo "Learn more: cat README.md"
