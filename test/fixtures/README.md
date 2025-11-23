# Ananke Test Fixtures

Test fixtures providing realistic sample code for constraint extraction and compilation testing.

## Overview

Fixtures are organized by language and complexity level, designed to validate:
- **Constraint extraction**: Can we identify constraints in real code?
- **Multi-language support**: Do all language parsers work correctly?
- **Performance**: Can we handle code of various sizes?
- **Error handling**: How do we respond to malformed input?

## Sample Code Files

### `sample.ts` - TypeScript Authentication Service
**Size**: ~60 lines | **Language**: TypeScript

```typescript
interface User {
  id: string;
  email: string;
  role: 'admin' | 'user';
}

async function authenticate(email: string, password: string): Promise<User | null> {
  if (!email || !password) {
    throw new Error('Email and password required');
  }
  
  const user = await db.findUser(email);
  if (!user) {
    return null;
  }
  
  const valid = await bcrypt.compare(password, user.hash);
  return valid ? user : null;
}
```

**Expected Constraints**: Type safety, null handling, async operations, error handling

### `sample.py` - Python Authentication Service
**Size**: ~50 lines | **Language**: Python

```python
from dataclasses import dataclass
from typing import Optional
import bcrypt

@dataclass
class User:
    id: str
    email: str
    role: str

def authenticate(email: str, password: str) -> Optional[User]:
    """Authenticate user by email and password."""
    if not email or not password:
        raise ValueError("Email and password required")
    
    user = db.find_user(email)
    if not user:
        return None
    
    valid = bcrypt.checkpw(password.encode(), user.hash)
    return user if valid else None
```

**Expected Constraints**: Type hints, documentation, class definitions, error handling

### `sample.rs` - Rust Authentication Service
**Size**: ~75 lines | **Language**: Rust

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub email: String,
    pub role: String,
}

pub async fn authenticate(
    email: &str,
    password: &str
) -> Result<User, AuthError> {
    if email.is_empty() || password.is_empty() {
        return Err(AuthError::InvalidInput);
    }
    
    let user = db.find_user(email).await?;
    let valid = bcrypt::verify(password, &user.hash)?;
    
    if valid {
        Ok(user)
    } else {
        Err(AuthError::InvalidPassword)
    }
}

#[derive(Debug)]
pub enum AuthError {
    InvalidInput,
    InvalidPassword,
    DatabaseError,
}
```

**Expected Constraints**: Type safety, error enums, async/await, input validation

### `sample.zig` - Zig Authentication Service
**Size**: ~70 lines | **Language**: Zig

```zig
const std = @import("std");

pub const User = struct {
    id: []const u8,
    email: []const u8,
    role: Role,
};

pub const Role = enum {
    admin,
    user,
};

pub const AuthError = error {
    InvalidInput,
    InvalidPassword,
    DatabaseError,
};

pub fn authenticate(
    allocator: std.mem.Allocator,
    email: []const u8,
    password: []const u8,
) !User {
    if (email.len == 0 or password.len == 0) {
        return AuthError.InvalidInput;
    }
    
    const user = try db.findUser(allocator, email);
    defer allocator.free(user.id);
    
    const valid = try bcrypt.verify(password, user.hash);
    if (!valid) {
        return AuthError.InvalidPassword;
    }
    
    return user;
}
```

**Expected Constraints**: Explicit return types, error unions, memory management

## Usage in Tests

### Embedding at Compile Time (Recommended)

```zig
const SAMPLE_TS = @embedFile("fixtures/sample.ts");

test "extraction: typescript sample" {
    const constraints = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer constraints.deinit();
    try testing.expect(constraints.constraints.items.len > 0);
}
```

## Files to Create

1. `sample.ts` - TypeScript fixture (copy code block above)
2. `sample.py` - Python fixture (copy code block above)
3. `sample.rs` - Rust fixture (copy code block above)
4. `sample.zig` - Zig fixture (copy code block above)
5. `large_code.zig` - Generated for performance tests (1000+ lines)
6. `malformed.ts` - Invalid syntax for error handling tests

---

**Status**: Ready for test implementation
