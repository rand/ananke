#!/usr/bin/env python3
"""Generate realistic code fixtures for benchmark testing"""

import os
from pathlib import Path

# TypeScript fixture templates
TS_FUNCTION_TEMPLATE = """
    async {name}({params}): Promise<{return_type}> {{
        try {{
            const result = await this.db.query<{return_type}>(
                'SELECT * FROM {table} WHERE id = ?',
                [id]
            );
            this.logger.debug(`Fetched {name}`);
            return result;
        }} catch (error) {{
            this.logger.error('Operation failed:', error);
            throw error;
        }}
    }}
"""

def generate_typescript_fixture(lines_target: int, output_path: Path):
    """Generate TypeScript fixture with target line count"""
    
    base = """// TypeScript Fixture (target ~{} lines)
// Generated for benchmark testing

import {{ Database }} from './database';
import {{ Logger }} from './logger';
import {{ Cache }} from './cache';

interface Entity {{
    id: number;
    name: string;
    email: string;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
}}

interface CreateDto {{
    name: string;
    email: string;
}}

interface UpdateDto {{
    name?: string;
    email?: string;
    isActive?: boolean;
}}

type EntityResponse = Promise<Entity | null>;
type EntitiesResponse = Promise<Entity[]>;

class EntityService {{
    private db: Database;
    private logger: Logger;
    private cache: Cache<number, Entity>;

    constructor(database: Database, logger: Logger, cache: Cache<number, Entity>) {{
        this.db = database;
        this.logger = logger;
        this.cache = cache;
    }}

""".format(lines_target)
    
    # Calculate how many functions needed to reach target
    base_lines = len(base.split('\n'))
    function_lines = len(TS_FUNCTION_TEMPLATE.split('\n'))
    functions_needed = max(1, (lines_target - base_lines - 10) // function_lines)
    
    for i in range(functions_needed):
        func = TS_FUNCTION_TEMPLATE.format(
            name=f"operation{i}",
            params=f"id: number, data: string",
            return_type="Entity",
            table="entities"
        )
        base += func
    
    base += "\n}\n\nexport { EntityService, Entity, CreateDto, UpdateDto };\n"
    
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(base)
    actual_lines = len(base.split('\n'))
    print(f"Generated {output_path}: {actual_lines} lines")

# Python fixture template
PY_FUNCTION_TEMPLATE = """
    async def {name}(self, entity_id: int, data: str) -> Optional[Entity]:
        \"\"\"Async operation {name}\"\"\"
        try:
            result = await self.db.query(
                "SELECT * FROM entities WHERE id = ?",
                (entity_id,)
            )
            self.logger.debug(f"Fetched {{entity_id}}")
            return Entity(**result) if result else None
        except Exception as e:
            self.logger.error(f"Operation failed: {{e}}")
            raise
"""

def generate_python_fixture(lines_target: int, output_path: Path):
    """Generate Python fixture with target line count"""
    
    base = """# Python Fixture (target ~{} lines)
# Generated for benchmark testing

from typing import Optional, List, Dict, Any
from dataclasses import dataclass
from datetime import datetime
import asyncio

@dataclass
class Entity:
    id: int
    name: str
    email: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

@dataclass
class CreateDto:
    name: str
    email: str

@dataclass
class UpdateDto:
    name: Optional[str] = None
    email: Optional[str] = None
    is_active: Optional[bool] = None

class EntityService:
    def __init__(self, db, logger, cache):
        self.db = db
        self.logger = logger
        self.cache = cache

""".format(lines_target)
    
    base_lines = len(base.split('\n'))
    function_lines = len(PY_FUNCTION_TEMPLATE.split('\n'))
    functions_needed = max(1, (lines_target - base_lines - 10) // function_lines)
    
    for i in range(functions_needed):
        func = PY_FUNCTION_TEMPLATE.format(name=f"operation_{i}")
        base += func
    
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(base)
    actual_lines = len(base.split('\n'))
    print(f"Generated {output_path}: {actual_lines} lines")

# Rust fixture template
RUST_FUNCTION_TEMPLATE = """
    pub async fn {name}(&self, id: u64, data: String) -> Result<Option<Entity>> {{
        match self.db.query("SELECT * FROM entities WHERE id = ?", &[&id]).await {{
            Ok(result) => {{
                self.logger.debug(&format!("Fetched {{}}", id));
                Ok(Some(result.try_into()?))
            }},
            Err(e) => {{
                self.logger.error(&format!("Operation failed: {{}}", e));
                Err(e.into())
            }}
        }}
    }}
"""

def generate_rust_fixture(lines_target: int, output_path: Path):
    """Generate Rust fixture with target line count"""
    
    base = """// Rust Fixture (target ~{} lines)
// Generated for benchmark testing

use anyhow::Result;
use chrono::{{DateTime, Utc}};
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct Entity {{
    pub id: u64,
    pub name: String,
    pub email: String,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}}

#[derive(Debug, Clone)]
pub struct CreateDto {{
    pub name: String,
    pub email: String,
}}

#[derive(Debug, Clone)]
pub struct UpdateDto {{
    pub name: Option<String>,
    pub email: Option<String>,
    pub is_active: Option<bool>,
}}

pub struct EntityService {{
    db: Arc<Database>,
    logger: Arc<Logger>,
    cache: Arc<Cache<u64, Entity>>,
}}

impl EntityService {{
    pub fn new(db: Arc<Database>, logger: Arc<Logger>, cache: Arc<Cache<u64, Entity>>) -> Self {{
        Self {{ db, logger, cache }}
    }}

""".format(lines_target)
    
    base_lines = len(base.split('\n'))
    function_lines = len(RUST_FUNCTION_TEMPLATE.split('\n'))
    functions_needed = max(1, (lines_target - base_lines - 10) // function_lines)
    
    for i in range(functions_needed):
        func = RUST_FUNCTION_TEMPLATE.format(name=f"operation_{i}")
        base += func
    
    base += "}\n"
    
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(base)
    actual_lines = len(base.split('\n'))
    print(f"Generated {output_path}: {actual_lines} lines")

# Zig fixture template
ZIG_FUNCTION_TEMPLATE = """
    pub fn {name}(self: *Self, id: u64, data: []const u8) !?Entity {{
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{{id}}) catch |err| {{
            self.logger.err("Operation failed: {{}}", .{{err}});
            return err;
        }};
        self.logger.debug("Fetched {{}}", .{{id}});
        return if (result) |r| Entity.fromRow(r) else null;
    }}
"""

def generate_zig_fixture(lines_target: int, output_path: Path):
    """Generate Zig fixture with target line count"""
    
    base = """// Zig Fixture (target ~{} lines)
// Generated for benchmark testing

const std = @import("std");

pub const Entity = struct {{
    id: u64,
    name: []const u8,
    email: []const u8,
    is_active: bool,
    created_at: i64,
    updated_at: i64,
}};

pub const CreateDto = struct {{
    name: []const u8,
    email: []const u8,
}};

pub const UpdateDto = struct {{
    name: ?[]const u8 = null,
    email: ?[]const u8 = null,
    is_active: ?bool = null,
}};

pub const EntityService = struct {{
    const Self = @This();
    
    db: *Database,
    logger: *Logger,
    cache: *Cache(u64, Entity),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, db: *Database, logger: *Logger, cache: *Cache(u64, Entity)) !*Self {{
        var self = try allocator.create(Self);
        self.* = .{{
            .db = db,
            .logger = logger,
            .cache = cache,
            .allocator = allocator,
        }};
        return self;
    }}

    pub fn deinit(self: *Self) void {{
        self.allocator.destroy(self);
    }}

""".format(lines_target)
    
    base_lines = len(base.split('\n'))
    function_lines = len(ZIG_FUNCTION_TEMPLATE.split('\n'))
    functions_needed = max(1, (lines_target - base_lines - 10) // function_lines)
    
    for i in range(functions_needed):
        func = ZIG_FUNCTION_TEMPLATE.format(name=f"operation{i}")
        base += func
    
    base += "};\n"
    
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(base)
    actual_lines = len(base.split('\n'))
    print(f"Generated {output_path}: {actual_lines} lines")

# Go fixture template
GO_FUNCTION_TEMPLATE = """
func (s *EntityService) {name}(ctx context.Context, id uint64, data string) (*Entity, error) {{
    result, err := s.db.Query(ctx, "SELECT * FROM entities WHERE id = $1", id)
    if err != nil {{
        s.logger.Error("Operation failed", "error", err)
        return nil, err
    }}
    s.logger.Debug("Fetched entity", "id", id)
    return parseEntity(result), nil
}}
"""

def generate_go_fixture(lines_target: int, output_path: Path):
    """Generate Go fixture with target line count"""
    
    base = """// Go Fixture (target ~{} lines)
// Generated for benchmark testing

package service

import (
    "context"
    "time"
)

type Entity struct {{
    ID        uint64    `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email"`
    IsActive  bool      `json:"is_active"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}}

type CreateDto struct {{
    Name  string `json:"name"`
    Email string `json:"email"`
}}

type UpdateDto struct {{
    Name     *string `json:"name,omitempty"`
    Email    *string `json:"email,omitempty"`
    IsActive *bool   `json:"is_active,omitempty"`
}}

type EntityService struct {{
    db     *Database
    logger *Logger
    cache  *Cache
}}

func NewEntityService(db *Database, logger *Logger, cache *Cache) *EntityService {{
    return &EntityService{{
        db:     db,
        logger: logger,
        cache:  cache,
    }}
}}

""".format(lines_target)
    
    base_lines = len(base.split('\n'))
    function_lines = len(GO_FUNCTION_TEMPLATE.split('\n'))
    functions_needed = max(1, (lines_target - base_lines - 5) // function_lines)
    
    for i in range(functions_needed):
        func = GO_FUNCTION_TEMPLATE.format(name=f"Operation{i}")
        base += func
    
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(base)
    actual_lines = len(base.split('\n'))
    print(f"Generated {output_path}: {actual_lines} lines")

def main():
    base_path = Path(__file__).parent
    
    sizes = [
        ("small", 100),
        ("medium", 500),
        ("large", 1000),
        ("xlarge", 5000),
    ]
    
    languages = [
        ("typescript", "ts", generate_typescript_fixture),
        ("python", "py", generate_python_fixture),
        ("rust", "rs", generate_rust_fixture),
        ("zig", "zig", generate_zig_fixture),
        ("go", "go", generate_go_fixture),
    ]
    
    for lang_name, ext, generator in languages:
        for size_name, line_count in sizes:
            output_path = base_path / lang_name / size_name / f"entity_service_{line_count}.{ext}"
            generator(line_count, output_path)
    
    print("\n✓ All fixtures generated successfully!")

if __name__ == "__main__":
    main()
