# Tutorial 1: Extract Constraints from Your Code

**Time**: 15 minutes  
**Level**: Beginner  
**Outcome**: Extract constraints from a TypeScript service and understand the constraint report

---

## Objective

Learn how to use Ananke's Clew engine to automatically extract constraints from existing code. By the end, you'll understand:

- How Clew analyzes code
- What constraint types get extracted
- How to generate constraint reports
- How to save constraints for later use

---

## Step 1: Prepare Sample Code

Let's create a simple TypeScript service to analyze. Save this as `sample-service.ts`:

```typescript
// sample-service.ts
import { Router, Request, Response } from 'express';
import { authenticate } from './auth';
import db from './database';

interface User {
  id: string;
  email: string;
  name: string;
  created_at: Date;
}

class UserService {
  private router: Router;

  constructor() {
    this.router = Router();
    this.setupRoutes();
  }

  // Get all users with pagination
  private setupRoutes() {
    this.router.get('/users', authenticate, async (req: Request, res: Response) => {
      try {
        const page = parseInt(req.query.page as string) || 1;
        const limit = parseInt(req.query.limit as string) || 10;
        
        // Validate input
        if (page < 1 || limit < 1 || limit > 100) {
          return res.status(400).json({ error: 'Invalid pagination parameters' });
        }

        const users: User[] = await db.query(
          'SELECT * FROM users LIMIT ? OFFSET ?',
          [limit, (page - 1) * limit]
        );

        res.json({ users, page, limit });
      } catch (error) {
        res.status(500).json({ error: 'Database query failed' });
      }
    });

    // Create new user
    this.router.post('/users', authenticate, async (req: Request, res: Response) => {
      const { email, name } = req.body;

      // Validate input
      if (!email || !name) {
        return res.status(400).json({ error: 'Email and name required' });
      }

      if (!this.isValidEmail(email)) {
        return res.status(400).json({ error: 'Invalid email format' });
      }

      try {
        const user = await db.query(
          'INSERT INTO users (email, name) VALUES (?, ?)',
          [email, name]
        );
        res.status(201).json(user);
      } catch (error) {
        res.status(500).json({ error: 'Failed to create user' });
      }
    });
  }

  private isValidEmail(email: string): boolean {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return regex.test(email);
  }

  getRouter(): Router {
    return this.router;
  }
}

export default new UserService();
```

## Step 2: Extract Constraints

Now extract constraints from this file:

```bash
# Extract constraints from single file
ananke extract sample-service.ts --output constraints.json --detailed
```

**Output breakdown**: The command will analyze the code and generate `constraints.json` with extracted patterns.

## Step 3: View the Constraint Report

Look at the generated constraints:

```bash
# Pretty-print the constraints
cat constraints.json | jq .

# Or use Ananke's viewer
ananke constraints show constraints.json
```

You should see something like:

```json
{
  "file": "sample-service.ts",
  "language": "typescript",
  "constraints": {
    "type_safety": {
      "found": true,
      "details": [
        "Use of TypeScript interfaces (User interface)",
        "Type annotations on function parameters",
        "Return type annotations present"
      ]
    },
    "syntactic": {
      "found": true,
      "details": [
        "Private method naming convention (private setupRoutes)",
        "Class-based structure",
        "Method organization pattern"
      ]
    },
    "security": {
      "found": true,
      "details": [
        "Authentication decorator used (@authenticate)",
        "Input validation on email format",
        "Parameterized queries (LIMIT ? OFFSET ?)",
        "Error handling present"
      ]
    },
    "semantic": {
      "found": true,
      "details": [
        "Data validation before use",
        "Error handling with try-catch",
        "HTTP status codes used correctly"
      ]
    },
    "architectural": {
      "found": true,
      "details": [
        "Service class encapsulation",
        "Router dependency injection pattern",
        "Clear method organization"
      ]
    }
  },
  "summary": {
    "total_constraints": 14,
    "constraint_categories": 5,
    "confidence": "high"
  }
}
```

## Step 4: Extract from Multiple Files

Extract constraints from multiple files:

```bash
# Extract from directory
mkdir -p src
cp sample-service.ts src/

# Extract from whole directory
ananke extract src/ --output all-constraints.json

# See what was found
wc -l all-constraints.json
```

## Step 5: Analyze Extracted Patterns

View detailed patterns:

```bash
# Get pattern details
ananke constraints show all-constraints.json --pattern

# Filter by constraint type
ananke constraints show all-constraints.json --type security
```

## Step 6: Save Constraints for Later

Use extracted constraints for generation:

```bash
# Compile constraints for use in generation
ananke compile all-constraints.json --output compiled.cir

# The compiled format is optimized for generation
ls -lh compiled.cir
```

## Understanding the Report

### Constraint Categories Explained

**Type Safety** (`type_safety`)
- Presence of type annotations
- Use of strict typing patterns
- Return type declarations
- Null handling patterns

**Syntactic** (`syntactic`)
- Naming conventions (camelCase, snake_case)
- Code formatting patterns
- Class/function organization
- Import/export structure

**Security** (`security`)
- Authentication/authorization checks
- Input validation patterns
- Secure API patterns (parameterized queries)
- Error handling presence

**Semantic** (`semantic`)
- Data flow patterns
- Control flow structure
- Side effect patterns
- Validation ordering

**Architectural** (`architectural`)
- Module organization
- Class/interface relationships
- Dependency patterns
- Layer separation

## Next Steps

Now that you've extracted constraints:

1. **Modify constraints**: Edit `constraints.json` to add or remove patterns
2. **Combine sources**: Mix automatic extraction with manual constraints
3. **Use in generation**: Generate code that follows the same patterns
4. **Share with team**: Commit constraints to your repository

See **Tutorial 2** to learn how to compile and optimize constraints.

---

## Troubleshooting

### No constraints found

**Problem**: Extraction runs but finds no constraints

**Solution**: Make sure the file contains the expected patterns (type annotations, error handling, etc.)

### File type not supported

**Problem**: Error like "Unsupported file type"

**Solution**: Explicitly specify language:
```bash
ananke extract file.ts --language typescript
```

### Want more details?

Get comprehensive extraction report:

```bash
ananke extract src/ \
  --detailed \
  --include-patterns \
  --output report.json
```

This includes confidence scores and pattern locations.

---

**Next**: [Tutorial 2: Compile Constraints](02-compile-constraints.md)
