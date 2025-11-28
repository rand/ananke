#!/usr/bin/env python3
"""
Schema Diff Tool for PostgreSQL

Compares two SQL schema files and generates a structured diff
showing added/removed columns, indexes, and constraints.

Output is formatted as JSON constraints for Ananke migration generation.
"""

import re
import json
import sys
from typing import Dict, List, Set, Any
from pathlib import Path
from dataclasses import dataclass, asdict


@dataclass
class Column:
    """Represents a database column."""
    name: str
    data_type: str
    nullable: bool = True
    default: str = None
    unique: bool = False
    primary_key: bool = False

    def __eq__(self, other):
        if not isinstance(other, Column):
            return False
        return (self.name == other.name and
                self.data_type == other.data_type and
                self.nullable == other.nullable and
                self.default == other.default)


@dataclass
class Index:
    """Represents a database index."""
    name: str
    table: str
    columns: List[str]
    unique: bool = False


@dataclass
class Table:
    """Represents a database table."""
    name: str
    columns: Dict[str, Column]
    indexes: Dict[str, Index]


class SQLParser:
    """Parse PostgreSQL schema files."""

    def __init__(self):
        self.tables: Dict[str, Table] = {}

    def parse_file(self, filepath: Path) -> Dict[str, Table]:
        """Parse a SQL file and extract table definitions."""
        with open(filepath, 'r') as f:
            content = f.read()

        # Remove comments
        content = re.sub(r'--.*$', '', content, flags=re.MULTILINE)
        content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)

        # Extract CREATE TABLE statements
        table_pattern = r'CREATE\s+TABLE\s+(\w+)\s*\((.*?)\);'
        for match in re.finditer(table_pattern, content, re.IGNORECASE | re.DOTALL):
            table_name = match.group(1)
            columns_text = match.group(2)

            table = Table(
                name=table_name,
                columns={},
                indexes={}
            )

            # Parse columns
            for col in self._parse_columns(columns_text):
                table.columns[col.name] = col

            self.tables[table_name] = table

        # Extract CREATE INDEX statements
        index_pattern = r'CREATE\s+(UNIQUE\s+)?INDEX\s+(\w+)\s+ON\s+(\w+)\s*\((.*?)\);'
        for match in re.finditer(index_pattern, content, re.IGNORECASE):
            unique = bool(match.group(1))
            index_name = match.group(2)
            table_name = match.group(3)
            columns_text = match.group(4)

            columns = [c.strip() for c in columns_text.split(',')]

            if table_name in self.tables:
                index = Index(
                    name=index_name,
                    table=table_name,
                    columns=columns,
                    unique=unique
                )
                self.tables[table_name].indexes[index_name] = index

        return self.tables

    def _parse_columns(self, columns_text: str) -> List[Column]:
        """Parse column definitions from CREATE TABLE."""
        columns = []

        # Split by comma, but respect parentheses
        parts = self._smart_split(columns_text, ',')

        for part in parts:
            part = part.strip()

            # Skip constraints (PRIMARY KEY, FOREIGN KEY, etc.)
            if any(kw in part.upper() for kw in ['PRIMARY KEY', 'FOREIGN KEY', 'CONSTRAINT', 'CHECK']):
                continue

            # Parse column definition
            col_match = re.match(
                r'(\w+)\s+([\w\(\)]+)(\s+.*)?',
                part,
                re.IGNORECASE
            )

            if col_match:
                col_name = col_match.group(1)
                col_type = col_match.group(2)
                modifiers = (col_match.group(3) or '').upper()

                column = Column(
                    name=col_name,
                    data_type=col_type,
                    nullable='NOT NULL' not in modifiers,
                    unique='UNIQUE' in modifiers,
                    primary_key='PRIMARY KEY' in modifiers
                )

                # Extract default value
                default_match = re.search(r'DEFAULT\s+([^,\s]+(?:\([^)]*\))?)', modifiers)
                if default_match:
                    column.default = default_match.group(1)

                columns.append(column)

        return columns

    def _smart_split(self, text: str, delimiter: str) -> List[str]:
        """Split text by delimiter, respecting parentheses."""
        parts = []
        current = []
        depth = 0

        for char in text:
            if char == '(':
                depth += 1
            elif char == ')':
                depth -= 1
            elif char == delimiter and depth == 0:
                parts.append(''.join(current))
                current = []
                continue

            current.append(char)

        if current:
            parts.append(''.join(current))

        return parts


class SchemaDiff:
    """Compare two database schemas and generate diff."""

    def __init__(self, old_schema: Dict[str, Table], new_schema: Dict[str, Table]):
        self.old_schema = old_schema
        self.new_schema = new_schema
        self.changes = {
            'tables_added': [],
            'tables_removed': [],
            'columns_added': [],
            'columns_removed': [],
            'columns_modified': [],
            'indexes_added': [],
            'indexes_removed': []
        }

    def compute_diff(self) -> Dict[str, Any]:
        """Compute differences between schemas."""
        old_tables = set(self.old_schema.keys())
        new_tables = set(self.new_schema.keys())

        # Tables added/removed
        self.changes['tables_added'] = list(new_tables - old_tables)
        self.changes['tables_removed'] = list(old_tables - new_tables)

        # Check columns and indexes in common tables
        common_tables = old_tables & new_tables

        for table_name in common_tables:
            old_table = self.old_schema[table_name]
            new_table = self.new_schema[table_name]

            self._diff_columns(table_name, old_table, new_table)
            self._diff_indexes(table_name, old_table, new_table)

        return self.changes

    def _diff_columns(self, table_name: str, old_table: Table, new_table: Table):
        """Compare columns between two versions of a table."""
        old_cols = set(old_table.columns.keys())
        new_cols = set(new_table.columns.keys())

        # Columns added
        for col_name in (new_cols - old_cols):
            col = new_table.columns[col_name]
            self.changes['columns_added'].append({
                'table': table_name,
                'column': col_name,
                'type': col.data_type,
                'nullable': col.nullable,
                'default': col.default
            })

        # Columns removed
        for col_name in (old_cols - new_cols):
            self.changes['columns_removed'].append({
                'table': table_name,
                'column': col_name
            })

        # Columns modified
        for col_name in (old_cols & new_cols):
            old_col = old_table.columns[col_name]
            new_col = new_table.columns[col_name]

            if old_col != new_col:
                self.changes['columns_modified'].append({
                    'table': table_name,
                    'column': col_name,
                    'old_type': old_col.data_type,
                    'new_type': new_col.data_type,
                    'old_nullable': old_col.nullable,
                    'new_nullable': new_col.nullable
                })

    def _diff_indexes(self, table_name: str, old_table: Table, new_table: Table):
        """Compare indexes between two versions of a table."""
        old_indexes = set(old_table.indexes.keys())
        new_indexes = set(new_table.indexes.keys())

        # Indexes added
        for idx_name in (new_indexes - old_indexes):
            idx = new_table.indexes[idx_name]
            self.changes['indexes_added'].append({
                'name': idx_name,
                'table': table_name,
                'columns': idx.columns,
                'unique': idx.unique
            })

        # Indexes removed
        for idx_name in (old_indexes - new_indexes):
            self.changes['indexes_removed'].append({
                'name': idx_name,
                'table': table_name
            })


def generate_migration_constraints(diff: Dict[str, Any]) -> Dict[str, Any]:
    """Convert schema diff to Ananke migration constraints."""

    # Build migration description
    changes_summary = []
    if diff['columns_added']:
        changes_summary.append(f"Add {len(diff['columns_added'])} columns")
    if diff['columns_removed']:
        changes_summary.append(f"Remove {len(diff['columns_removed'])} columns")
    if diff['indexes_added']:
        changes_summary.append(f"Create {len(diff['indexes_added'])} indexes")
    if diff['indexes_removed']:
        changes_summary.append(f"Drop {len(diff['indexes_removed'])} indexes")

    description = ', '.join(changes_summary) if changes_summary else "No changes"

    constraints = {
        'migration': {
            'description': description,
            'changes': diff,
            'transaction_safe': True,
            'reversible': True
        },
        'patterns': {
            'format': 'PostgreSQL DDL',
            'structure': 'UP/DOWN sections with BEGIN/COMMIT',
            'header': 'Migration metadata (name, timestamp, description)',
            'safety': 'Use IF EXISTS/IF NOT EXISTS for idempotency'
        },
        'requirements': {
            'up_migration': 'Apply all schema changes',
            'down_migration': 'Completely revert to previous state',
            'default_values': 'Use safe defaults for NOT NULL columns',
            'idempotency': 'Safe to run multiple times'
        }
    }

    return constraints


def main():
    """Main entry point."""
    if len(sys.argv) != 4:
        print("Usage: schema_diff.py <old_schema.sql> <new_schema.sql> <output.json>")
        sys.exit(1)

    old_schema_path = Path(sys.argv[1])
    new_schema_path = Path(sys.argv[2])
    output_path = Path(sys.argv[3])

    # Parse schemas
    print(f"Parsing {old_schema_path}...")
    old_parser = SQLParser()
    old_schema = old_parser.parse_file(old_schema_path)

    print(f"Parsing {new_schema_path}...")
    new_parser = SQLParser()
    new_schema = new_parser.parse_file(new_schema_path)

    # Compute diff
    print("Computing schema diff...")
    differ = SchemaDiff(old_schema, new_schema)
    diff = differ.compute_diff()

    # Generate constraints
    print("Generating migration constraints...")
    constraints = generate_migration_constraints(diff)

    # Write output
    with open(output_path, 'w') as f:
        json.dump(constraints, f, indent=2)

    print(f"\nSchema diff written to {output_path}")
    print(f"\nSummary:")
    print(f"  Columns added: {len(diff['columns_added'])}")
    print(f"  Columns removed: {len(diff['columns_removed'])}")
    print(f"  Indexes added: {len(diff['indexes_added'])}")
    print(f"  Indexes removed: {len(diff['indexes_removed'])}")


if __name__ == '__main__':
    main()
