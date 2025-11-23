# Tutorial 5: Integration - Ananke in Your Workflow

**Time**: 20 minutes  
**Level**: Advanced  
**Outcome**: Integrate Ananke into your development workflow

---

## Overview

This tutorial covers:
- Setting up constraint files for your project
- Validating code in pre-commit hooks
- Automating checks in CI/CD
- Team workflows and sharing constraints
- Production deployment

---

## Step 1: Set Up Project Structure

Create Ananke project directory:

```bash
mkdir -p .ananke
mkdir -p .ananke/constraints
mkdir -p .ananke/logs

# Initialize config
cat > .ananke/config.yaml << 'CONFIG'
# Ananke Configuration

service:
  endpoint: "${MODAL_ENDPOINT}"
  api_key: "${MODAL_API_KEY}"

model:
  name: "meta-llama/Meta-Llama-3.1-8B-Instruct"
  max_tokens: 2048
  temperature: 0.7

constraints:
  cache_enabled: true
  auto_extract_from:
    - src
    - tests

logging:
  level: "info"
  file: ".ananke/logs/ananke.log"
CONFIG

# Extract initial constraints
ananke extract ./src ./tests --output .ananke/constraints.json

# Compile
ananke compile .ananke/constraints.json \
  --output .ananke/constraints.cir

# Commit
git add .ananke/
git commit -m "Initialize Ananke constraints"
```

---

## Step 2: Pre-commit Hook Setup

Validate code before committing:

```bash
# Install hook
ananke hook install

# This creates .git/hooks/pre-commit

# Test it
git commit -m "test"
# Should validate constraints
```

Or manually create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

# Validate staged files against constraints
FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(py|ts|js|rs)$')

if [ -z "$FILES" ]; then
    exit 0
fi

echo "Checking constraints..."
ananke validate $FILES --constraints .ananke/constraints.cir

if [ $? -ne 0 ]; then
    echo "Constraint violations detected!"
    echo "Fix violations and try again."
    exit 1
fi

exit 0
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

---

## Step 3: GitHub Actions Setup

Add to `.github/workflows/constraints.yml`:

```yaml
name: Constraint Validation

on:
  pull_request:
  push:
    branches: [main, develop]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Full history for better analysis
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install Ananke
        run: pip install ananke-ai
      
      - name: Extract constraints
        run: |
          ananke extract ./src ./tests \
            --output .github/constraints.json
      
      - name: Compile constraints
        run: |
          ananke compile .github/constraints.json \
            --output .github/constraints.cir
      
      - name: Validate code
        run: |
          ananke validate ./src \
            --constraints .github/constraints.cir \
            --detailed
      
      - name: Comment on PR
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Constraint validation failed. Check the CI logs.'
            })
```

---

## Step 4: Pre-push Hook

Validate before pushing:

```bash
# Create .git/hooks/pre-push
cat > .git/hooks/pre-push << 'HOOK'
#!/bin/bash

# Get list of commits to be pushed
COMMITS=$(git rev-list origin/main..HEAD)

if [ -z "$COMMITS" ]; then
    exit 0
fi

echo "Validating $COMMITS commits..."

for commit in $COMMITS; do
    FILES=$(git show --pretty= --name-only $commit | grep -E '\.(py|ts|js|rs)$')
    if [ -z "$FILES" ]; then
        continue
    fi
    
    # Get file contents at that commit
    ananke validate $FILES --constraints .ananke/constraints.cir
    if [ $? -ne 0 ]; then
        echo "Constraints violated in $commit"
        exit 1
    fi
done

exit 0
HOOK

chmod +x .git/hooks/pre-push
```

---

## Step 5: Code Review Guidelines

Document in `CONSTRAINTS.md`:

```markdown
# Code Constraints

This project enforces the following constraints:

## Type Safety
- No `any` types
- All functions must have return type annotations
- All parameters must be typed

## Security
- All user input must be validated
- No direct SQL queries (use parameterized)
- Authentication required for all API endpoints

## Performance
- Function complexity must be below 10
- Database queries must use indexes
- Caching required for frequently accessed data

## Testing
- All public functions must have tests
- Test coverage must be above 80%

Generated code is automatically validated against these constraints.
```

Commit:

```bash
git add CONSTRAINTS.md
git commit -m "Document code constraints"
```

---

## Step 6: Team Workflow

### Sharing Constraints

```bash
# Team member 1: Creates constraints
ananke extract ./src --output team-constraints.json
git add team-constraints.json
git commit -m "Update constraints"
git push

# Team member 2: Pulls constraints
git pull

# Team member 3: Uses constraints for generation
ananke compile team-constraints.json --output team.cir
ananke generate "Add feature" --constraints team.cir
```

### Updating Constraints

```bash
# Regular update (weekly)
ananke extract ./src ./tests --output constraints.json
git add constraints.json
git commit -m "Update constraints from codebase"

# Or with team input
# 1. Extract
ananke extract ./src --output extracted.json

# 2. Get team feedback
# (email, discussion, review)

# 3. Update
cat extracted.json > constraints.json
# (edit based on feedback)

# 4. Compile and commit
ananke compile constraints.json --output constraints.cir
git add constraints.json constraints.cir
git commit -m "Update constraints based on team review"
```

---

## Step 7: Production Setup

### Deploy Inference Service

```bash
# Deploy for production
modal deploy modal_inference/inference.py

# Get endpoint
ENDPOINT=$(modal app list | grep ananke-inference | awk '{print $NF}')

# Set in environment
export MODAL_ENDPOINT=$ENDPOINT

# Test
curl $MODAL_ENDPOINT/health
```

### Docker Deployment

Create `Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install Ananke
RUN pip install ananke-ai

# Copy constraints
COPY .ananke/ .ananke/

# Set environment
ENV MODAL_ENDPOINT=https://your-endpoint.modal.run
ENV MODAL_API_KEY=your-key

# Run as CLI
ENTRYPOINT ["ananke"]
```

Build and run:

```bash
docker build -t ananke-cli .
docker run ananke-cli extract ./src --output constraints.json
```

### Kubernetes Deployment

Create `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ananke-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ananke
  template:
    metadata:
      labels:
        app: ananke
    spec:
      containers:
      - name: ananke
        image: ananke-cli:latest
        env:
        - name: MODAL_ENDPOINT
          valueFrom:
            configMapKeyRef:
              name: ananke-config
              key: modal-endpoint
        - name: MODAL_API_KEY
          valueFrom:
            secretKeyRef:
              name: ananke-secret
              key: modal-api-key
```

Deploy:

```bash
kubectl apply -f deployment.yaml
```

---

## Step 8: Monitoring and Metrics

### Set Up Logging

```bash
# Enable debug logging in .ananke/config.yaml
logging:
  level: debug
  format: json
  file: .ananke/logs/ananke.log

# Or via environment
export ANANKE_LOG_LEVEL=debug
```

### Track Metrics

Create `scripts/metrics.sh`:

```bash
#!/bin/bash

# Extract metrics
TOTAL_CONSTRAINTS=$(jq '.constraints | length' .ananke/constraints.json)
VIOLATIONS=$(ananke validate ./src --constraints .ananke/constraints.cir | grep -c "✗")

echo "Constraints: $TOTAL_CONSTRAINTS"
echo "Violations: $VIOLATIONS"

# Save to file
echo "$(date),$(hostname),$TOTAL_CONSTRAINTS,$VIOLATIONS" >> metrics.csv
```

---

## Step 9: Documentation

Create team documentation:

```markdown
# Using Ananke in Our Project

## Quick Start

```bash
# Extract constraints
ananke extract ./src

# Generate code
ananke generate "your feature" --constraints constraints.cir

# Validate
ananke validate generated.py --constraints constraints.cir
```

## Constraints

See `CONSTRAINTS.md` for full list.

## Updating Constraints

```bash
# Extract from current code
ananke extract ./src --output constraints.json

# Review changes
git diff constraints.json

# Commit when ready
git add constraints.json
git commit -m "Update constraints"
```

## CI/CD

Constraints are validated automatically on:
- Pull requests
- Commits to main
- Manual trigger

See `.github/workflows/constraints.yml` for details.
```

---

## Troubleshooting

### Hook not executing

**Problem**: Pre-commit hook runs but doesn't block

**Solution**:
```bash
# Make sure hook is executable
chmod +x .git/hooks/pre-commit

# Verify it runs
.git/hooks/pre-commit

# Check for errors
bash -x .git/hooks/pre-commit
```

### CI fails but local passes

**Problem**: Different results locally vs CI

**Solution**:
```bash
# Use same constraints in CI
# Update CI workflow to use .ananke/constraints.cir

# Or extract in CI
ananke extract ./src --output constraints.json

# Check Python versions match
python --version  # Local
# Verify same in CI
```

---

## Best Practices

1. **Commit constraints**: Version control constraints like code
2. **Regular updates**: Update constraints monthly as codebase evolves
3. **Team review**: Get team feedback on constraint changes
4. **Gradual adoption**: Start with few constraints, add over time
5. **Document**: Explain why each constraint exists
6. **Monitor**: Track constraint violations over time
7. **Iterate**: Adjust constraints based on real usage

---

## Complete Example Project

See `examples/complete-project/` in repository for:
- Full constraint set
- CI/CD configuration
- Team workflow setup
- Production deployment

---

**Congratulations! You've completed all tutorials.**

**Next steps**:
- Review the API Reference
- Explore advanced examples
- Join the community
- Start using Ananke in your projects!

