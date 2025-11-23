# Ariadne DSL Grammar Specification

## Overview

Ariadne is a domain-specific language for declaratively defining constraints in the Ananke system. It provides a clean, readable syntax for expressing complex constraint relationships.

## Grammar

### Top-Level Constructs

```ebnf
Program ::= Declaration*

Declaration ::= ModuleDecl
              | ImportStmt
              | ConstraintDef
              | PublicDecl
              | Comment

ModuleDecl ::= "module" IdentifierPath

ImportStmt ::= "import" IdentifierPath ( "." "{" Identifier ("," Identifier)* "}" )?

ConstraintDef ::= "constraint" Identifier ("{" Property ("," Property)* "}")?

PublicDecl ::= "pub" "const" Identifier "=" Value
             | "pub" "fn" FunctionDef

Comment ::= "--" .* "\n"
```

### Properties and Values

```ebnf
Property ::= Identifier ":" Value

Value ::= String
        | MultilineString
        | Number
        | Boolean
        | "null"
        | Variant
        | VariantWithValue
        | Array
        | Object
        | Query
        | Identifier

String ::= "\"" ( [^"\] | "\\" . )* "\""

MultilineString ::= "\"\"\"" .* "\"\"\""

Number ::= "-"? [0-9]+ ( "." [0-9]+ )?

Boolean ::= "true" | "false"

Variant ::= "." Identifier

VariantWithValue ::= Variant "(" Value ")"

Array ::= "[" ( Value ("," Value)* )? "]"

Object ::= "{" ( Property ("," Property)* )? "}"

Query ::= "query" "(" Identifier ")" "{" .* "}"

IdentifierPath ::= Identifier ( "." Identifier )*

Identifier ::= [a-zA-Z_][a-zA-Z0-9_]*
```

### Function Definitions

```ebnf
FunctionDef ::= Identifier "(" Parameters? ")" ("->" TypeAnnotation)? "{" FunctionBody "}"

Parameters ::= Parameter ("," Parameter)*

Parameter ::= Identifier ":" TypeAnnotation

TypeAnnotation ::= Identifier | Variant | ComplexType

FunctionBody ::= .* // Arbitrary code, not parsed in detail
```

## Token Types

### Keywords

- `module` - Module declaration
- `import` - Import statement
- `constraint` - Constraint definition
- `pub` - Public declaration modifier
- `const` - Constant declaration
- `fn` - Function declaration
- `let` - Variable binding
- `for` - Loop construct
- `in` - Membership operator
- `where` - Filter clause
- `and`, `or`, `not` - Logical operators
- `if` - Conditional
- `null` - Null value
- `query` - Tree-sitter query pattern
- `true`, `false` - Boolean literals

### Symbols

- `:` - Property/type separator
- `,` - Element separator
- `;` - Statement terminator (optional)
- `.` - Member access / path separator
- `{` `}` - Block delimiters
- `[` `]` - Array delimiters
- `(` `)` - Grouping / function call
- `->` - Function return type arrow
- `=` - Assignment
- `@` - Capture marker (in queries)
- `$` - Variable prefix (in queries)
- `|` - Alternative operator

### Special Tokens

- Variant: `.EnumValue` - Enum variant notation
- Comment: `--` - Line comment prefix
- Multiline string: `"""..."""` - Multi-line string literal

## Semantic Rules

### Module System

1. A file may declare at most one module
2. Module names follow dot notation (e.g., `api.security`)
3. Imports can import entire modules or specific symbols
4. Symbol imports use brace syntax: `import std.{clew, braid}`

### Constraints

1. Constraint names must be unique within a module
2. Properties within a constraint may appear in any order
3. Constraints may reference other constraints via identifiers
4. Standard constraint properties include:
   - `id`: String - Unique identifier
   - `name`: String - Constraint name
   - `enforcement`: Variant - Enforcement strategy
   - `provenance`: Object - Source information
   - `failure_mode`: Variant - How to handle violations
   - `repair`: Object/null - Repair strategy
   - `metadata`: Object - Additional metadata
   - `depends_on`: Array - Dependencies

### Enforcement Strategies

Variants representing enforcement types:

- `.Syntactic({...})` - Grammar/syntax-based enforcement
- `.Type({...})` - Type system enforcement
- `.Structural({...})` - Tree-sitter structural patterns
- `.Semantic({...})` - Semantic property verification

### Failure Modes

Variants representing failure handling:

- `.HardBlock` - Prevent code generation
- `.SoftWarn({...})` - Warning with optional override
- `.AutoFix({...})` - Attempt automatic repair

### Provenance Sources

Variants representing constraint origins:

- `.ManualPolicy` - Hand-written policy
- `.ClewMined` - Mined from code
- `.TelemetryInferred` - Inferred from metrics
- `.DomainExpert` - Expert-defined
- `.LLMGenerated` - AI-generated

## Examples

### Simple Constraint

```ariadne
constraint no_any_type {
    id: "type-001",
    name: "no_any_type",
    enforcement: .Type({
        signature: {
            forbidden_types: ["any", "unknown"]
        }
    }),
    failure_mode: .HardBlock
}
```

### Structural Pattern Constraint

```ariadne
constraint no_dangerous_operations {
    id: "security-001",
    name: "no_dangerous_operations",

    enforcement: .Structural({
        pattern: query(javascript) {
            (call_expression
                function: (identifier) @fn
                where @fn in ["eval", "exec"]
            )
        },
        action: .Forbid
    }),

    failure_mode: .HardBlock
}
```

### Module with Imports

```ariadne
module api.security

import std.{clew, braid}

constraint require_authentication {
    id: "security-005",
    name: "require_authentication",

    enforcement: .Semantic({
        property: .Security({
            invariant: "All endpoints must check authentication"
        })
    }),

    provenance: {
        source: .ManualPolicy,
        confidence_score: 1.0
    }
}
```

### Public Exports

```ariadne
pub const security_constraints = [
    no_dangerous_operations,
    require_authentication,
    prevent_sql_injection
]

pub fn compile() -> ConstraintIR {
    let graph = braid.graph.new()

    for constraint in security_constraints {
        graph.add_node(constraint)
    }

    return graph.build()
}
```

## Type System

While Ariadne is dynamically typed at runtime, the constraint system uses structural typing:

### Common Types

- `String` - Text values
- `Number` - Numeric values (f64)
- `Boolean` - true/false
- `Array<T>` - Homogeneous arrays
- `Object` - Key-value maps
- `Variant` - Tagged union values

### Constraint-Specific Types

- `ConstraintKind` - Type of constraint
- `EnforcementStrategy` - How constraint is enforced
- `FailureMode` - How violations are handled
- `Provenance` - Constraint origin information
- `RepairStrategy` - How to fix violations

## Error Handling

The parser provides detailed error messages with line and column information:

```
Parse error at line 5, col 12: Expected ':' after property name
Current token: Token(identifier, "enforcement", line 5, col 12)
```

Error types:

- `UnexpectedToken` - Unexpected token in input
- `UnexpectedCharacter` - Invalid character
- `UnterminatedString` - Missing closing quote
- `InvalidCharacter` - Invalid number format

## Implementation Notes

### Lexical Analysis

- Comments are stripped during lexing
- Whitespace is insignificant (except in strings)
- Line tracking maintains accurate source positions
- Multi-line strings preserve internal formatting

### Parsing Strategy

- Recursive descent parser
- Lookahead of 1 token
- Error recovery not implemented (fail-fast)
- No operator precedence (use explicit grouping)

### Semantic Analysis

1. **Symbol Collection**: First pass collects all constraint definitions
2. **Reference Resolution**: Second pass verifies all references
3. **Type Checking**: Future - validate property types
4. **Dependency Analysis**: Future - detect circular dependencies

## Future Extensions

### Planned Features

1. **Macros**: LLM-powered macro expansion
2. **Type Annotations**: Optional static typing
3. **Inheritance**: Constraint extension via `inherits`
4. **Composition**: Constraint combination operators
5. **Conditionals**: Environment-specific constraints
6. **Imports**: Cross-file constraint reuse

### LSP Support

Future language server features:

- Autocomplete for constraint properties
- Go-to-definition for constraint references
- Hover documentation
- Real-time error checking
- Refactoring support

## Best Practices

### Naming Conventions

- Constraints: `snake_case` (e.g., `require_authentication`)
- Modules: `snake_case.dot.notation` (e.g., `api.security`)
- Properties: `snake_case` (e.g., `confidence_score`)
- Identifiers: `PascalCase` for types, `snake_case` for values

### Organization

- Group related constraints in modules
- Use descriptive constraint names
- Include provenance information
- Document complex patterns in comments
- Export collections of constraints

### Performance

- Keep query patterns simple
- Avoid deep nesting in structural patterns
- Use appropriate enforcement strategies
- Consider caching compiled constraints

## Compatibility

### JSON Interoperability

Ariadne can compile to/from JSON format for interoperability:

```zig
var compiler = AriadneCompiler.init(allocator);
const json_str = try compiler.toJson(ariadne_source);
```

### Integration Points

- **Clew**: Static analysis engine
- **Braid**: Constraint graph builder
- **Maze**: Code generation with constraints
- **LLM APIs**: Macro expansion and synthesis

## References

- [Ananke Architecture](/Users/rand/src/ananke/docs/architecture.md)
- [Constraint Types](/Users/rand/src/ananke/src/types/constraint.zig)
- [Example DSL Files](/Users/rand/src/ananke/examples/03-ariadne-dsl/)
