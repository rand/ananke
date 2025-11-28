# Example 1: OpenAPI Route Generation

## Overview

This example demonstrates how Ananke generates type-safe Express.js API routes from OpenAPI 3.0 specifications. The generated code includes:

- Automatic request validation (path params, query params, request body)
- Type-safe response handling with proper HTTP status codes
- Consistent error patterns and error handling
- OpenAPI specification compliance
- Production-ready code with comprehensive error messages

## Value Proposition

**Problem**: Writing API routes manually is error-prone and time-consuming. Changes to API specifications require manual updates across multiple files, leading to drift between documentation and implementation.

**Solution**: Ananke extracts patterns from existing routes and merges them with OpenAPI specifications to generate consistent, validated routes that match your codebase's style.

**Benefits**:
- Eliminates 80% of route boilerplate code
- Ensures API spec compliance automatically
- Reduces manual validation errors
- Maintains consistency across all endpoints
- Saves 2-3 hours per endpoint in a typical project

## Prerequisites

- Node.js 18+ and npm
- Ananke CLI installed (`ananke --version` should work)
- Python 3.8+ (for OpenAPI parsing script)
- Basic familiarity with Express.js and OpenAPI

## Quick Start

Run the complete example in one command:

```bash
./run.sh
```

This will:
1. Extract routing patterns from existing code
2. Parse OpenAPI spec and merge constraints
3. Generate a new route handler
4. Validate the generated code with tests

Total runtime: ~30 seconds

## Setup Instructions

### 1. Install Python Dependencies

```bash
pip3 install -r requirements.txt
```

Or if you're using a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

This installs:
- `PyYAML` - YAML parsing for OpenAPI specs

### 2. Install Node.js Dependencies

```bash
npm install
```

This installs:
- `express` and `@types/express` - Web framework
- `vitest` - Test runner for validation
- `typescript` - Type checking
- `zod` - Runtime validation library

### 3. Verify Ananke Installation

```bash
ananke --version
```

Expected output: `ananke 0.1.0` (or later)

If not installed, follow the main Ananke installation guide.

### 4. Review Input Files

**input/openapi.yaml**: OpenAPI 3.0 specification for a User API with endpoints for fetching users, creating users, and listing users with pagination.

**input/existing_routes.ts**: Example Express route showing the codebase's preferred patterns for:
- Request validation
- Error handling
- Response formatting
- Database access patterns

## Step-by-Step Guide

### Phase 1: Extract Constraints from Existing Code

The first phase analyzes your existing route code to learn patterns:

```bash
ananke extract input/existing_routes.ts \
  --language typescript \
  -o constraints/extracted.json
```

**What it extracts**:
- Error handling patterns (try/catch structure)
- Response formatting conventions
- Validation approach (Zod schemas)
- HTTP status code usage
- Database interaction patterns
- Async/await patterns

**Output**: `constraints/extracted.json` containing learned patterns in Ananke's constraint format.

### Phase 2: Parse OpenAPI Spec and Merge Constraints

The second phase converts the OpenAPI specification into constraints and merges them with extracted patterns:

```bash
python3 scripts/openapi_to_constraints.py \
  input/openapi.yaml \
  constraints/extracted.json \
  -o constraints/merged.json
```

**What it does**:
- Parses OpenAPI paths, parameters, request bodies, and responses
- Converts parameter schemas to validation constraints
- Maps HTTP methods and status codes
- Merges with extracted code patterns
- Resolves conflicts (OpenAPI spec takes precedence for API contract)

**Output**: `constraints/merged.json` containing combined constraints ready for generation.

### Phase 3: Generate Route Handler

The third phase uses the merged constraints to generate a new route handler:

```bash
ananke generate "Generate an Express.js route handler for GET /users/{id} that validates the id parameter, fetches the user from the database, and returns appropriate responses" \
  --constraints constraints/merged.json \
  --max-tokens 2000 \
  -o output/generated_routes.ts
```

**What it generates**:
- Complete Express router with all endpoints from OpenAPI spec
- Request validation using Zod schemas
- Type-safe request/response handling
- Error handling matching existing code patterns
- Database access code following extracted patterns
- Comprehensive JSDoc comments

**Output**: `output/generated_routes.ts` containing production-ready route code.

### Phase 4: Validate Generated Code

The final phase runs tests to ensure the generated code is correct:

```bash
npm test
```

**What it validates**:
- TypeScript compilation succeeds
- All routes respond to correct HTTP methods
- Request validation rejects invalid inputs
- Response formats match OpenAPI spec
- Error handling works correctly
- HTTP status codes are correct

**Output**: Test results showing pass/fail status for each validation.

## Expected Output

After running `./run.sh`, you should see:

```
=== Example 1: OpenAPI Route Generation ===

1/4 Extracting constraints from existing code...
✓ Extracted 15 constraints from existing_routes.ts

2/4 Parsing OpenAPI spec and merging constraints...
✓ Parsed 3 endpoints from openapi.yaml
✓ Merged constraints: 23 total

3/4 Generating route handler...
✓ Generated 187 lines of code

4/4 Validating generated code...
 ✓ tests/test_generated.ts (6 tests passed)

✓ Complete! See output/generated_routes.ts
```

### Generated Code Structure

The generated `output/generated_routes.ts` includes:

```typescript
import { Router, Request, Response } from 'express';
import { z } from 'zod';

const router = Router();

// Validation schemas
const getUserParamsSchema = z.object({
  id: z.number().int().min(1)
});

// GET /users/:id - Fetch a single user
router.get('/users/:id', async (req: Request, res: Response) => {
  try {
    // Validate path parameters
    const params = getUserParamsSchema.parse({
      id: parseInt(req.params.id, 10)
    });

    // Database query (placeholder)
    const user = await db.users.findById(params.id);

    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: `No user exists with id ${params.id}`
      });
    }

    return res.status(200).json(user);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.errors
      });
    }
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

export default router;
```

## Customization Guide

### Changing the OpenAPI Specification

Edit `input/openapi.yaml` to add or modify endpoints:

```yaml
paths:
  /users/{id}/posts:
    get:
      summary: Get user's posts
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
        - name: limit
          in: query
          schema:
            type: integer
            default: 10
```

Then re-run `./run.sh` to regenerate routes.

### Customizing Code Patterns

Modify `input/existing_routes.ts` to change the patterns Ananke learns:

**For different error handling**:
```typescript
// Change from JSON errors to custom error class
throw new ApiError(404, 'User not found');
```

**For different validation libraries**:
```typescript
// Switch from Zod to Joi
const schema = Joi.object({
  id: Joi.number().integer().min(1)
});
```

After modifying existing routes, re-run extraction to update learned patterns.

### Adjusting Generation Prompt

Modify the prompt in `run.sh` (Phase 3) to change generation behavior:

```bash
# More verbose code with comments
ananke generate "Generate Express.js routes with detailed inline comments explaining each validation step..."

# Different architectural style
ananke generate "Generate Express.js routes using middleware pattern for validation..."

# Add specific features
ananke generate "Generate Express.js routes with request logging and performance monitoring..."
```

### Adding Custom Constraints

You can manually edit `constraints/merged.json` before generation to add custom constraints:

```json
{
  "constraints": [
    {
      "type": "pattern",
      "description": "All routes must include request ID in logs",
      "example": "logger.info({ requestId: req.id, ... })"
    }
  ]
}
```

## Advanced Usage

### Generating Routes for Specific Endpoints

To generate only specific endpoints, filter the OpenAPI spec:

```bash
# Extract only user-related endpoints
python3 scripts/openapi_to_constraints.py \
  input/openapi.yaml \
  constraints/extracted.json \
  --filter-path "/users/*" \
  -o constraints/merged.json
```

### Using Multiple Example Files

To learn from multiple existing route files:

```bash
# Extract from multiple files
ananke extract input/existing_routes.ts \
  -o constraints/routes1.json

ananke extract input/other_routes.ts \
  -o constraints/routes2.json

# Merge manually or use constraint merging
python3 scripts/merge_constraints.py \
  constraints/routes1.json \
  constraints/routes2.json \
  -o constraints/combined.json
```

### Integrating with CI/CD

Add to your CI pipeline to keep generated routes in sync with OpenAPI spec:

```yaml
# .github/workflows/sync-routes.yml
name: Sync OpenAPI Routes
on:
  push:
    paths:
      - 'specs/openapi.yaml'

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: ./examples/production/01-openapi-route-generation/run.sh
      - run: git diff --exit-code output/generated_routes.ts || echo "Routes out of sync!"
```

## Troubleshooting

### Issue: "ananke: command not found"

**Cause**: Ananke CLI is not installed or not in PATH.

**Solution**:
```bash
# Install from source
cd /path/to/ananke
zig build install

# Or add to PATH
export PATH=$PATH:/path/to/ananke/zig-out/bin
```

### Issue: "OpenAPI parsing failed"

**Cause**: Invalid OpenAPI specification format.

**Solution**:
```bash
# Validate OpenAPI spec
npm install -g @apidevtools/swagger-cli
swagger-cli validate input/openapi.yaml
```

### Issue: Generated code has TypeScript errors

**Cause**: Constraints don't match TypeScript expectations.

**Solution**:
```bash
# Check extracted constraints
cat constraints/extracted.json | jq '.constraints[] | select(.type == "type_constraint")'

# Verify merge worked correctly
cat constraints/merged.json | jq '.constraints | length'

# Try more explicit generation prompt
ananke generate "Generate TypeScript-compliant Express routes with proper type annotations..." \
  --constraints constraints/merged.json \
  -o output/generated_routes.ts
```

### Issue: Tests fail with validation errors

**Cause**: Generated code doesn't match OpenAPI spec expectations.

**Solution**:
```bash
# Run tests in verbose mode
npm test -- --reporter=verbose

# Check specific test failure
npm test -- --grep "validates request parameters"

# Verify OpenAPI spec matches expectations
cat input/openapi.yaml | grep -A 10 "parameters:"
```

### Issue: Generated code doesn't follow existing patterns

**Cause**: Extraction didn't capture patterns correctly.

**Solution**:
```bash
# Inspect extracted constraints
cat constraints/extracted.json | jq

# Add more examples to existing_routes.ts
# Make patterns more explicit and consistent

# Re-run extraction
ananke extract input/existing_routes.ts --language typescript -o constraints/extracted.json
```

## Understanding the Constraint Format

Ananke constraints are JSON objects describing code patterns and requirements:

```json
{
  "constraints": [
    {
      "type": "pattern",
      "category": "error_handling",
      "description": "All async routes use try/catch blocks",
      "example": "try { ... } catch (error) { res.status(500).json(...) }"
    },
    {
      "type": "validation",
      "library": "zod",
      "description": "Request parameters validated with Zod schemas",
      "example": "const schema = z.object({ id: z.number() })"
    },
    {
      "type": "api_contract",
      "source": "openapi",
      "method": "GET",
      "path": "/users/{id}",
      "parameters": [
        { "name": "id", "type": "integer", "minimum": 1, "required": true }
      ]
    }
  ]
}
```

**Constraint types**:
- `pattern`: Coding pattern to follow
- `validation`: Input validation approach
- `api_contract`: OpenAPI-defined API contract
- `type_constraint`: TypeScript type requirements
- `error_handling`: Error handling patterns
- `response_format`: Response structure requirements

## Real-World Integration

### Integrating Generated Routes into Your Application

```typescript
// src/app.ts
import express from 'express';
import generatedRoutes from './generated/routes';

const app = express();
app.use(express.json());
app.use('/api', generatedRoutes);

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

### Iterative Refinement

1. Generate initial routes
2. Review generated code
3. Update `existing_routes.ts` with preferred patterns
4. Re-run generation
5. Repeat until satisfied

### Combining with Manual Code

Generated routes can be used as a starting point:

```typescript
// Start with generated code
import generatedRoutes from './output/generated_routes';

// Add custom middleware
generatedRoutes.use(authMiddleware);
generatedRoutes.use(rateLimiter);

// Add custom routes
generatedRoutes.post('/users/:id/verify', customHandler);

export default generatedRoutes;
```

## Performance Characteristics

- **Extraction**: ~0.5 seconds for 100 lines of code
- **OpenAPI parsing**: ~1 second for 20 endpoints
- **Generation**: ~5-15 seconds depending on complexity
- **Validation**: ~2 seconds for comprehensive tests

Total time for this example: ~20-30 seconds

## Next Steps

After mastering this example:

1. **Try Example 2**: Database Migration Generator - Generate type-safe database migrations
2. **Try Example 3**: React Component Generator - Generate React components from design specs
3. **Customize for your project**: Adapt the example to your codebase's patterns
4. **Contribute**: Share your custom scripts and patterns with the Ananke community

## Additional Resources

- [OpenAPI Specification 3.0](https://swagger.io/specification/)
- [Express.js Documentation](https://expressjs.com/)
- [Zod Validation Library](https://zod.dev/)
- [Ananke Constraint Reference](../../docs/CONSTRAINT_FORMAT.md)
- [Ananke CLI Guide](../../docs/CLI_GUIDE.md)

## License

This example is part of the Ananke project and is licensed under the same terms as Ananke itself.

## Contributing

Found an improvement? Submit a PR or open an issue in the main Ananke repository.
