// Ariadne: Constraint DSL Compiler
// Optional domain-specific language for expressing complex constraint relationships
const std = @import("std");

// Import types from root module
const root = @import("ananke");
const Constraint = root.types.constraint.Constraint;
const ConstraintIR = root.types.constraint.ConstraintIR;
const ConstraintKind = root.types.constraint.ConstraintKind;
const EnforcementType = root.types.constraint.EnforcementType;
const Severity = root.types.constraint.Severity;
const ConstraintSource = root.types.constraint.ConstraintSource;

/// Ariadne DSL compiler
pub const AriadneCompiler = struct {
    allocator: std.mem.Allocator,
    llm_client: ?LLMClient = null,

    pub fn init(allocator: std.mem.Allocator) !AriadneCompiler {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AriadneCompiler) void {
        _ = self;
    }

    /// Parse Ariadne source to AST
    pub fn parse(self: *AriadneCompiler, source: []const u8) !AST {
        var parser = Parser.init(self.allocator, source);
        defer parser.deinit();
        return try parser.parse();
    }

    /// Validate AST semantically
    pub fn validate(self: *AriadneCompiler, ast: AST) !void {
        var analyzer = SemanticAnalyzer.init(self.allocator);
        defer analyzer.deinit();
        try analyzer.analyze(ast);
    }

    /// Parse and compile Ariadne source to ConstraintIR
    pub fn compile(self: *AriadneCompiler, source: []const u8) !ConstraintIR {
        // Parse source to AST
        var parser = Parser.init(self.allocator, source);
        defer parser.deinit();
        const ast = try parser.parse();

        // Semantic analysis
        var analyzer = SemanticAnalyzer.init(self.allocator);
        defer analyzer.deinit();
        try analyzer.analyze(ast);

        // Macro expansion (optionally use LLM)
        var expanded_ast = ast;
        if (self.llm_client) |client| {
            expanded_ast = try client.expandMacros(ast);
        } else {
            expanded_ast = try self.expandMacrosDefault(ast);
        }

        // Generate ConstraintIR
        return try self.generateIR(expanded_ast);
    }

    /// Convert Ariadne to equivalent JSON representation
    pub fn toJson(self: *AriadneCompiler, source: []const u8) ![]const u8 {
        const ir = try self.compile(source);
        return try self.irToJson(ir);
    }

    fn expandMacrosDefault(self: *AriadneCompiler, ast: AST) !AST {
        _ = self;
        // TODO: Implement default macro expansion
        return ast;
    }

    fn generateIR(self: *AriadneCompiler, ast: AST) !ConstraintIR {
        var ir_gen = IRGenerator.init(self.allocator);
        defer ir_gen.deinit();
        return try ir_gen.generate(ast);
    }

    fn irToJson(self: *AriadneCompiler, ir: ConstraintIR) ![]const u8 {
        var string = std.ArrayList(u8){};
        defer string.deinit(self.allocator);

        try std.json.stringify(ir, .{}, string.writer(self.allocator));
        return try self.allocator.dupe(u8, string.items);
    }
};

/// Token types for lexer
pub const TokenType = enum {
    // Literals
    identifier,
    string,
    multiline_string,
    number,
    boolean,

    // Keywords
    keyword_module,
    keyword_import,
    keyword_constraint,
    keyword_pub,
    keyword_const,
    keyword_fn,
    keyword_let,
    keyword_for,
    keyword_in,
    keyword_where,
    keyword_and,
    keyword_or,
    keyword_not,
    keyword_if,
    keyword_null,
    keyword_query,

    // Symbols
    colon,
    comma,
    semicolon,
    dot,
    left_brace,
    right_brace,
    left_bracket,
    right_bracket,
    left_paren,
    right_paren,
    arrow,
    equals,
    at_sign,
    dollar_sign,
    pipe,

    // Special
    variant, // .EnumVariant
    comment,
    eof,
    newline,
};

/// A token produced by the lexer
pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Token({s}, \"{s}\", line {d}, col {d})", .{ @tagName(self.type), self.lexeme, self.line, self.column });
    }
};

/// Lexer for tokenizing Ariadne source
pub const Lexer = struct {
    source: []const u8,
    pos: usize = 0,
    line: usize = 1,
    column: usize = 1,
    start_pos: usize = 0,
    start_line: usize = 1,
    start_column: usize = 1,

    pub fn init(source: []const u8) Lexer {
        return .{
            .source = source,
        };
    }

    pub fn nextToken(self: *Lexer) !Token {
        self.skipWhitespace();

        self.start_pos = self.pos;
        self.start_line = self.line;
        self.start_column = self.column;

        if (self.isAtEnd()) {
            return self.makeToken(.eof);
        }

        const c = self.advance();

        // Comments
        if (c == '-' and self.peek() == '-') {
            return self.comment();
        }

        // Multi-line strings
        if (c == '"' and self.peek() == '"' and self.peekNext() == '"') {
            return self.multilineString();
        }

        // Strings
        if (c == '"') {
            return self.string();
        }

        // Numbers
        if (isDigit(c) or (c == '-' and isDigit(self.peek()))) {
            return self.number();
        }

        // Variants (.EnumValue)
        if (c == '.' and isAlpha(self.peek())) {
            return self.variant();
        }

        // Identifiers and keywords
        if (isAlpha(c) or c == '_') {
            return self.identifier();
        }

        // Symbols
        return switch (c) {
            ':' => self.makeToken(.colon),
            ',' => self.makeToken(.comma),
            ';' => self.makeToken(.semicolon),
            '.' => self.makeToken(.dot),
            '{' => self.makeToken(.left_brace),
            '}' => self.makeToken(.right_brace),
            '[' => self.makeToken(.left_bracket),
            ']' => self.makeToken(.right_bracket),
            '(' => self.makeToken(.left_paren),
            ')' => self.makeToken(.right_paren),
            '@' => self.makeToken(.at_sign),
            '$' => self.makeToken(.dollar_sign),
            '|' => self.makeToken(.pipe),
            '=' => self.makeToken(.equals),
            '-' => blk: {
                if (self.peek() == '>') {
                    _ = self.advance();
                    break :blk self.makeToken(.arrow);
                }
                return error.UnexpectedCharacter;
            },
            else => error.UnexpectedCharacter,
        };
    }

    fn comment(self: *Lexer) !Token {
        _ = self.advance(); // consume second '-'
        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }
        return self.makeToken(.comment);
    }

    fn string(self: *Lexer) !Token {
        while (!self.isAtEnd() and self.peek() != '"') {
            if (self.peek() == '\\') {
                _ = self.advance(); // skip escape char
                if (!self.isAtEnd()) {
                    _ = self.advance(); // skip escaped char
                }
            } else {
                _ = self.advance();
            }
        }

        if (self.isAtEnd()) {
            return error.UnterminatedString;
        }

        _ = self.advance(); // closing quote
        return self.makeToken(.string);
    }

    fn multilineString(self: *Lexer) !Token {
        // Skip opening """
        _ = self.advance();
        _ = self.advance();

        while (!self.isAtEnd()) {
            if (self.peek() == '"' and self.peekNext() == '"' and self.peekNext2() == '"') {
                _ = self.advance();
                _ = self.advance();
                _ = self.advance();
                return self.makeToken(.multiline_string);
            }
            _ = self.advance();
        }

        return error.UnterminatedString;
    }

    fn number(self: *Lexer) !Token {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }

        // Decimal part
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance(); // consume '.'
            while (isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        return self.makeToken(.number);
    }

    fn variant(self: *Lexer) !Token {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }
        return self.makeToken(.variant);
    }

    fn identifier(self: *Lexer) !Token {
        while (isAlphaNumeric(self.peek()) or self.peek() == '_') {
            _ = self.advance();
        }

        const text = self.source[self.start_pos..self.pos];
        const token_type = getKeywordType(text);
        return self.makeToken(token_type);
    }

    fn getKeywordType(text: []const u8) TokenType {
        const keywords = std.StaticStringMap(TokenType).initComptime(.{
            .{ "module", .keyword_module },
            .{ "import", .keyword_import },
            .{ "constraint", .keyword_constraint },
            .{ "pub", .keyword_pub },
            .{ "const", .keyword_const },
            .{ "fn", .keyword_fn },
            .{ "let", .keyword_let },
            .{ "for", .keyword_for },
            .{ "in", .keyword_in },
            .{ "where", .keyword_where },
            .{ "and", .keyword_and },
            .{ "or", .keyword_or },
            .{ "not", .keyword_not },
            .{ "if", .keyword_if },
            .{ "null", .keyword_null },
            .{ "query", .keyword_query },
            .{ "true", .boolean },
            .{ "false", .boolean },
        });

        return keywords.get(text) orelse .identifier;
    }

    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            switch (c) {
                ' ', '\t', '\r' => {
                    _ = self.advance();
                },
                '\n' => {
                    self.line += 1;
                    self.column = 0;
                    _ = self.advance();
                },
                else => break,
            }
        }
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.pos];
        self.pos += 1;
        self.column += 1;
        return c;
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.pos];
    }

    fn peekNext(self: *Lexer) u8 {
        if (self.pos + 1 >= self.source.len) return 0;
        return self.source[self.pos + 1];
    }

    fn peekNext2(self: *Lexer) u8 {
        if (self.pos + 2 >= self.source.len) return 0;
        return self.source[self.pos + 2];
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.pos >= self.source.len;
    }

    fn makeToken(self: *Lexer, token_type: TokenType) Token {
        return .{
            .type = token_type,
            .lexeme = self.source[self.start_pos..self.pos],
            .line = self.start_line,
            .column = self.start_column,
        };
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }

    fn isUpper(c: u8) bool {
        return c >= 'A' and c <= 'Z';
    }

    fn isAlphaNumeric(c: u8) bool {
        return isAlpha(c) or isDigit(c);
    }
};

/// Ariadne parser
pub const Parser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    lexer: Lexer,
    current_token: Token,
    previous_token: Token,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Parser {
        const lexer = Lexer.init(source);
        const dummy_token = Token{
            .type = .eof,
            .lexeme = "",
            .line = 0,
            .column = 0,
        };

        return .{
            .allocator = allocator,
            .source = source,
            .lexer = lexer,
            .current_token = dummy_token,
            .previous_token = dummy_token,
        };
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
    }

    pub fn parse(self: *Parser) !AST {
        var nodes = std.ArrayList(ASTNode){};
        errdefer {
            // Clean up any nodes that were allocated before the error
            for (nodes.items) |node| {
                self.freeNode(node);
            }
            nodes.deinit(self.allocator);
        }

        // Prime the pump
        try self.advance();

        while (!self.check(.eof)) {
            // Skip comments
            if (self.check(.comment)) {
                try self.advance();
                continue;
            }

            const node = try self.parseTopLevel();
            try nodes.append(self.allocator, node);
        }

        return AST{
            .nodes = try nodes.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
        };
    }

    fn freeNode(self: *Parser, node: ASTNode) void {
        switch (node) {
            .module_decl => |decl| {
                self.allocator.free(decl.name);
            },
            .import_stmt => |stmt| {
                self.allocator.free(stmt.path);
                self.allocator.free(stmt.symbols);
            },
            .constraint_def => |def| {
                for (def.properties) |prop| {
                    AST.freeValue(self.allocator, prop.value);
                }
                self.allocator.free(def.properties);
            },
            .public_const => |const_decl| {
                AST.freeValue(self.allocator, const_decl.value);
            },
            .function_def => |func| {
                self.allocator.free(func.params);
            },
            .comment => {},
        }
    }

    fn parseTopLevel(self: *Parser) !ASTNode {
        if (self.match(.keyword_module)) {
            return self.parseModule();
        } else if (self.match(.keyword_import)) {
            return self.parseImport();
        } else if (self.match(.keyword_constraint)) {
            return self.parseConstraint();
        } else if (self.match(.keyword_pub)) {
            return self.parsePublicDecl();
        } else if (self.check(.comment)) {
            const comment = self.current_token.lexeme;
            try self.advance();
            return ASTNode{ .comment = comment };
        }

        return self.reportError("Expected module, import, constraint, or pub declaration");
    }

    fn parseModule(self: *Parser) !ASTNode {
        const name = try self.parseIdentifierPath();
        return ASTNode{
            .module_decl = .{ .name = name },
        };
    }

    fn parseImport(self: *Parser) !ASTNode {
        const path = try self.parseIdentifierPath();

        // Handle import std.{a, b, c}
        var imports = std.ArrayList([]const u8){};
        errdefer imports.deinit(self.allocator);

        if (self.match(.dot)) {
            try self.consume(.left_brace, "Expected '{' after module path");

            while (!self.check(.right_brace)) {
                const name = try self.expectIdentifier();
                try imports.append(self.allocator, name);

                if (!self.match(.comma)) break;
            }

            try self.consume(.right_brace, "Expected '}' after imports");
        }

        return ASTNode{
            .import_stmt = .{
                .path = path,
                .symbols = try imports.toOwnedSlice(self.allocator),
            },
        };
    }

    fn parseConstraint(self: *Parser) !ASTNode {
        const name = try self.expectIdentifier();

        var inherits: ?[]const u8 = null;
        if (self.match(.keyword_import)) { // Using 'inherits' keyword if it exists
            inherits = try self.expectIdentifier();
        }

        try self.consume(.left_brace, "Expected '{' after constraint name");

        var properties = std.ArrayList(Property){};
        errdefer properties.deinit(self.allocator);

        while (!self.check(.right_brace) and !self.check(.eof)) {
            if (self.check(.comment)) {
                try self.advance();
                continue;
            }

            const prop = try self.parseProperty();
            try properties.append(self.allocator, prop);

            // Optional comma
            _ = self.match(.comma);
        }

        try self.consume(.right_brace, "Expected '}' after constraint body");

        return ASTNode{
            .constraint_def = .{
                .name = name,
                .inherits = inherits,
                .properties = try properties.toOwnedSlice(self.allocator),
            },
        };
    }

    fn parsePublicDecl(self: *Parser) !ASTNode {
        if (self.match(.keyword_const)) {
            const name = try self.expectIdentifier();
            try self.consume(.equals, "Expected '=' after const name");
            const value = try self.parseValue();

            return ASTNode{
                .public_const = .{
                    .name = name,
                    .value = value,
                },
            };
        } else if (self.match(.keyword_fn)) {
            return self.parseFunction();
        }

        return self.reportError("Expected 'const' or 'fn' after 'pub'");
    }

    fn parseFunction(self: *Parser) !ASTNode {
        const name = try self.expectIdentifier();

        try self.consume(.left_paren, "Expected '(' after function name");

        var params = std.ArrayList(FunctionParam){};
        errdefer params.deinit(self.allocator);

        while (!self.check(.right_paren) and !self.check(.eof)) {
            const param_name = try self.expectIdentifier();
            try self.consume(.colon, "Expected ':' after parameter name");
            const param_type = try self.parseType();

            try params.append(self.allocator, .{
                .name = param_name,
                .type_annotation = param_type,
            });

            if (!self.match(.comma)) break;
        }

        try self.consume(.right_paren, "Expected ')' after parameters");

        var return_type: ?[]const u8 = null;
        if (self.match(.arrow)) {
            return_type = try self.parseType();
        }

        try self.consume(.left_brace, "Expected '{' before function body");

        // For now, skip function body (we don't need to parse it fully)
        var brace_depth: i32 = 1;
        const body_start = self.lexer.pos;

        while (brace_depth > 0 and !self.check(.eof)) {
            if (self.check(.left_brace)) brace_depth += 1;
            if (self.check(.right_brace)) brace_depth -= 1;

            if (brace_depth > 0) {
                try self.advance();
            }
        }

        const body_end = self.previous_token.lexeme.ptr - self.source.ptr;
        const body = self.source[body_start..body_end];

        try self.consume(.right_brace, "Expected '}' after function body");

        return ASTNode{
            .function_def = .{
                .name = name,
                .params = try params.toOwnedSlice(self.allocator),
                .return_type = return_type,
                .body = body,
            },
        };
    }

    fn parseProperty(self: *Parser) !Property {
        const key = try self.expectIdentifier();
        try self.consume(.colon, "Expected ':' after property name");
        const value = try self.parseValue();

        return .{
            .key = key,
            .value = value,
        };
    }

    fn parseValue(self: *Parser) error{ OutOfMemory, UnexpectedToken, UnterminatedString, UnexpectedCharacter, InvalidCharacter }!Value {
        // String literals
        if (self.check(.string)) {
            const str = self.current_token.lexeme;
            try self.advance();
            // Remove quotes
            return Value{ .string = str[1 .. str.len - 1] };
        }

        // Multi-line strings
        if (self.check(.multiline_string)) {
            const str = self.current_token.lexeme;
            try self.advance();
            // Remove """
            return Value{ .string = str[3 .. str.len - 3] };
        }

        // Numbers
        if (self.check(.number)) {
            const num_str = self.current_token.lexeme;
            try self.advance();
            const num = try std.fmt.parseFloat(f64, num_str);
            return Value{ .number = num };
        }

        // Booleans
        if (self.check(.boolean)) {
            const is_true = std.mem.eql(u8, self.current_token.lexeme, "true");
            try self.advance();
            return Value{ .boolean = is_true };
        }

        // Null
        if (self.match(.keyword_null)) {
            return Value{ .null_value = {} };
        }

        // Variants (.EnumValue)
        if (self.check(.variant)) {
            const variant = self.current_token.lexeme;
            try self.advance();

            // Check for variant with nested object
            if (self.match(.left_paren)) {
                const nested_ptr = try self.allocator.create(Value);
                nested_ptr.* = try self.parseValue();
                try self.consume(.right_paren, "Expected ')' after variant value");

                return Value{
                    .variant_with_value = .{
                        .name = variant,
                        .value = nested_ptr,
                    },
                };
            }

            return Value{ .variant = variant };
        }

        // Arrays
        if (self.match(.left_bracket)) {
            var items = std.ArrayList(Value){};
            errdefer items.deinit(self.allocator);

            while (!self.check(.right_bracket) and !self.check(.eof)) {
                const item = try self.parseValue();
                try items.append(self.allocator, item);

                if (!self.match(.comma)) break;
            }

            try self.consume(.right_bracket, "Expected ']' after array elements");

            return Value{ .array = try items.toOwnedSlice(self.allocator) };
        }

        // Objects
        if (self.match(.left_brace)) {
            var properties = std.ArrayList(Property){};
            errdefer properties.deinit(self.allocator);

            while (!self.check(.right_brace) and !self.check(.eof)) {
                if (self.check(.comment)) {
                    try self.advance();
                    continue;
                }

                const prop = try self.parseProperty();
                try properties.append(self.allocator, prop);

                // Optional comma
                _ = self.match(.comma);
            }

            try self.consume(.right_brace, "Expected '}' after object properties");

            return Value{ .object = try properties.toOwnedSlice(self.allocator) };
        }

        // Query patterns
        if (self.match(.keyword_query)) {
            try self.consume(.left_paren, "Expected '(' after 'query'");
            const language = try self.expectIdentifier();
            try self.consume(.right_paren, "Expected ')' after query language");
            try self.consume(.left_brace, "Expected '{' before query pattern");

            // Read until matching }
            var brace_depth: i32 = 1;
            const pattern_start = self.lexer.pos;

            while (brace_depth > 0 and !self.check(.eof)) {
                if (self.check(.left_brace)) brace_depth += 1;
                if (self.check(.right_brace)) brace_depth -= 1;

                if (brace_depth > 0) {
                    try self.advance();
                }
            }

            const pattern_end = self.previous_token.lexeme.ptr - self.source.ptr;
            const pattern = self.source[pattern_start..pattern_end];

            try self.consume(.right_brace, "Expected '}' after query pattern");

            return Value{
                .query = .{
                    .language = language,
                    .pattern = pattern,
                },
            };
        }

        // Identifiers (references)
        if (self.check(.identifier)) {
            const name = self.current_token.lexeme;
            try self.advance();
            return Value{ .identifier = name };
        }

        return self.reportError("Expected value");
    }

    fn parseType(self: *Parser) ![]const u8 {
        // For now, just parse type as identifier or complex type
        // This is a simplified version
        const start_pos = self.lexer.start_pos;

        // Simple identifier type
        if (self.check(.identifier)) {
            _ = try self.expectIdentifier();
        } else if (self.check(.variant)) {
            try self.advance();
        }

        // Handle generics like Promise<T>
        if (self.match(.left_bracket)) { // Using < would require special handling
            _ = try self.parseType();
            try self.consume(.right_bracket, "Expected '>' after generic type");
        }

        const end_pos = self.previous_token.lexeme.ptr - self.source.ptr + self.previous_token.lexeme.len;
        return self.source[start_pos..end_pos];
    }

    fn parseIdentifierPath(self: *Parser) ![]const u8 {
        const start = try self.expectIdentifier();
        var path = std.ArrayList(u8){};
        defer path.deinit(self.allocator);

        try path.appendSlice(self.allocator, start);

        // Handle dotted paths like "api.security" or "std.clew"
        // The lexer tokenizes ".security" as a variant token, so we need to handle both:
        // - .dot followed by identifier (when followed by non-alpha like {)
        // - .variant tokens (which include the dot)
        while (true) {
            if (self.check(.variant)) {
                // Variant token like ".security" - strip the leading dot and append
                const variant_lexeme = self.current_token.lexeme;
                if (variant_lexeme.len > 1 and variant_lexeme[0] == '.') {
                    try path.append(self.allocator, '.');
                    try path.appendSlice(self.allocator, variant_lexeme[1..]);
                    try self.advance();
                } else {
                    break;
                }
            } else if (self.check(.dot)) {
                // Peek ahead to see if next token is identifier
                const saved_current = self.current_token;
                const saved_previous = self.previous_token;
                const saved_lexer = self.lexer;

                _ = try self.advance(); // consume dot
                const is_identifier = self.check(.identifier);

                // Restore parser state
                self.current_token = saved_current;
                self.previous_token = saved_previous;
                self.lexer = saved_lexer;

                if (!is_identifier) {
                    break;
                }

                // Actually consume dot and identifier
                _ = try self.advance();
                try path.append(self.allocator, '.');
                const segment = try self.expectIdentifier();
                try path.appendSlice(self.allocator, segment);
            } else {
                break;
            }
        }

        return try self.allocator.dupe(u8, path.items);
    }

    fn expectIdentifier(self: *Parser) ![]const u8 {
        if (!self.check(.identifier)) {
            return self.reportError("Expected identifier");
        }
        const name = self.current_token.lexeme;
        try self.advance();
        return name;
    }

    fn consume(self: *Parser, token_type: TokenType, message: []const u8) !void {
        if (!self.check(token_type)) {
            std.debug.print("Error at line {d}, col {d}: {s}\n", .{ self.current_token.line, self.current_token.column, message });
            std.debug.print("Got token: {any}\n", .{self.current_token});
            return error.UnexpectedToken;
        }
        try self.advance();
    }

    fn match(self: *Parser, token_type: TokenType) bool {
        if (self.check(token_type)) {
            self.advance() catch return false;
            return true;
        }
        return false;
    }

    fn check(self: *Parser, token_type: TokenType) bool {
        return self.current_token.type == token_type;
    }

    fn advance(self: *Parser) !void {
        self.previous_token = self.current_token;
        self.current_token = try self.lexer.nextToken();

        // Skip comments automatically
        while (self.current_token.type == .comment) {
            self.current_token = try self.lexer.nextToken();
        }
    }

    fn reportError(self: *Parser, message: []const u8) error{UnexpectedToken} {
        std.debug.print("Parse error at line {d}, col {d}: {s}\n", .{
            self.current_token.line,
            self.current_token.column,
            message,
        });
        std.debug.print("Current token: {any}\n", .{self.current_token});
        return error.UnexpectedToken;
    }
};

/// Semantic analyzer for Ariadne
pub const SemanticAnalyzer = struct {
    allocator: std.mem.Allocator,
    constraint_defs: std.StringHashMap(void),

    pub fn init(allocator: std.mem.Allocator) SemanticAnalyzer {
        return .{
            .allocator = allocator,
            .constraint_defs = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *SemanticAnalyzer) void {
        self.constraint_defs.deinit();
    }

    pub fn analyze(self: *SemanticAnalyzer, ast: AST) !void {
        // First pass: collect all constraint definitions
        for (ast.nodes) |node| {
            switch (node) {
                .constraint_def => |def| {
                    try self.constraint_defs.put(def.name, {});
                },
                else => {},
            }
        }

        // Second pass: verify references
        for (ast.nodes) |node| {
            switch (node) {
                .constraint_def => |def| {
                    if (def.inherits) |parent| {
                        if (!self.constraint_defs.contains(parent)) {
                            std.debug.print("Warning: Unknown constraint '{s}' in inherits clause\n", .{parent});
                        }
                    }
                },
                else => {},
            }
        }
    }
};

/// IR Generator - converts AST to ConstraintIR
pub const IRGenerator = struct {
    allocator: std.mem.Allocator,
    constraints: std.ArrayList(Constraint),

    pub fn init(allocator: std.mem.Allocator) IRGenerator {
        return .{
            .allocator = allocator,
            .constraints = std.ArrayList(Constraint){},
        };
    }

    pub fn deinit(self: *IRGenerator) void {
        self.constraints.deinit(self.allocator);
    }

    pub fn generate(self: *IRGenerator, ast: AST) !ConstraintIR {
        // Extract all constraint definitions from AST
        for (ast.nodes) |node| {
            switch (node) {
                .constraint_def => |def| {
                    const constraint = try self.processConstraintDef(def);
                    try self.constraints.append(self.allocator, constraint);
                },
                else => {}, // Skip module declarations, imports, etc.
            }
        }

        // Convert constraints to ConstraintIR
        return try self.buildConstraintIR();
    }

    fn processConstraintDef(self: *IRGenerator, def: ConstraintDef) !Constraint {
        var constraint = Constraint{
            .id = 0, // Will be set from properties
            .name = def.name,
            .description = "",
            .kind = .syntactic,
            .severity = .err,
        };

        // Process properties to populate constraint fields
        for (def.properties) |prop| {
            try self.processProperty(&constraint, prop);
        }

        return constraint;
    }

    fn processProperty(self: *IRGenerator, constraint: *Constraint, prop: Property) !void {
        const key = prop.key;

        if (std.mem.eql(u8, key, "id")) {
            // Extract constraint ID
            if (prop.value == .string) {
                // For now, use a hash of the string as the ID
                constraint.id = std.hash.Wyhash.hash(0, prop.value.string);
            }
        } else if (std.mem.eql(u8, key, "name")) {
            if (prop.value == .string) {
                constraint.name = prop.value.string;
            }
        } else if (std.mem.eql(u8, key, "description")) {
            if (prop.value == .string) {
                constraint.description = prop.value.string;
            }
        } else if (std.mem.eql(u8, key, "enforcement")) {
            // Parse enforcement type from variant
            if (prop.value == .variant) {
                constraint.enforcement = try self.parseEnforcement(prop.value.variant);
            } else if (prop.value == .variant_with_value) {
                constraint.enforcement = try self.parseEnforcement(prop.value.variant_with_value.name);
            }
        } else if (std.mem.eql(u8, key, "provenance")) {
            // Parse provenance information
            if (prop.value == .object) {
                try self.parseProvenance(constraint, prop.value.object);
            }
        } else if (std.mem.eql(u8, key, "failure_mode")) {
            // Parse failure mode to determine severity
            if (prop.value == .variant) {
                constraint.severity = try self.parseFailureMode(prop.value.variant);
            } else if (prop.value == .variant_with_value) {
                constraint.severity = try self.parseFailureMode(prop.value.variant_with_value.name);
            }
        }
    }

    fn parseEnforcement(self: *IRGenerator, variant: []const u8) !EnforcementType {
        _ = self;
        if (std.mem.eql(u8, variant, ".Syntactic")) {
            return .Syntactic;
        } else if (std.mem.eql(u8, variant, ".Structural")) {
            return .Structural;
        } else if (std.mem.eql(u8, variant, ".Semantic")) {
            return .Semantic;
        } else if (std.mem.eql(u8, variant, ".Performance")) {
            return .Performance;
        } else if (std.mem.eql(u8, variant, ".Security")) {
            return .Security;
        }
        return .Syntactic; // Default
    }

    fn parseFailureMode(self: *IRGenerator, variant: []const u8) !Severity {
        _ = self;
        if (std.mem.eql(u8, variant, ".HardBlock")) {
            return .err;
        } else if (std.mem.eql(u8, variant, ".SoftWarn")) {
            return .warning;
        } else if (std.mem.eql(u8, variant, ".Warn")) {
            return .warning;
        } else if (std.mem.eql(u8, variant, ".AutoFix")) {
            return .warning;
        } else if (std.mem.eql(u8, variant, ".Suggest")) {
            return .hint;
        }
        return .err; // Default
    }

    fn parseProvenance(self: *IRGenerator, constraint: *Constraint, properties: []const Property) !void {
        for (properties) |prop| {
            if (std.mem.eql(u8, prop.key, "source")) {
                if (prop.value == .variant) {
                    constraint.source = try self.parseConstraintSource(prop.value.variant);
                }
            } else if (std.mem.eql(u8, prop.key, "confidence_score")) {
                if (prop.value == .number) {
                    constraint.confidence = @floatCast(prop.value.number);
                }
            } else if (std.mem.eql(u8, prop.key, "origin_artifact")) {
                if (prop.value == .string) {
                    constraint.origin_file = prop.value.string;
                }
            }
        }
    }

    fn parseConstraintSource(self: *IRGenerator, variant: []const u8) !ConstraintSource {
        _ = self;
        if (std.mem.eql(u8, variant, ".ManualPolicy")) {
            return .User_Defined;
        } else if (std.mem.eql(u8, variant, ".ClewMined")) {
            return .Test_Mining;
        } else if (std.mem.eql(u8, variant, ".BestPractice")) {
            return .Documentation;
        } else if (std.mem.eql(u8, variant, ".PerformancePolicy")) {
            return .Telemetry;
        }
        return .User_Defined; // Default
    }

    fn buildConstraintIR(self: *IRGenerator) !ConstraintIR {
        var ir = ConstraintIR{};

        // For a basic implementation, we'll build a simple ConstraintIR
        // In a full implementation, this would analyze the constraints and generate:
        // - JSON Schema for type constraints
        // - Grammar for syntactic constraints
        // - Regex patterns for pattern matching
        // - Token masks for forbidden/required tokens

        // Set priority based on highest constraint priority
        var max_priority: u32 = 0;
        for (self.constraints.items) |constraint| {
            const priority = constraint.getPriorityValue();
            if (priority > max_priority) {
                max_priority = priority;
            }
        }
        ir.priority = max_priority;

        return ir;
    }
};

/// Abstract Syntax Tree
pub const AST = struct {
    nodes: []const ASTNode,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *AST) void {
        // Free data in each node
        for (self.nodes) |node| {
            switch (node) {
                .module_decl => |decl| {
                    self.allocator.free(decl.name);
                },
                .import_stmt => |stmt| {
                    self.allocator.free(stmt.path);
                    self.allocator.free(stmt.symbols);
                },
                .constraint_def => |def| {
                    // Free properties recursively
                    for (def.properties) |prop| {
                        freeValue(self.allocator, prop.value);
                    }
                    self.allocator.free(def.properties);
                },
                .public_const => |const_decl| {
                    freeValue(self.allocator, const_decl.value);
                },
                .function_def => |func| {
                    self.allocator.free(func.params);
                },
                .comment => {},
            }
        }
        self.allocator.free(self.nodes);
    }

    fn freeValue(allocator: std.mem.Allocator, value: Value) void {
        switch (value) {
            .array => |arr| {
                for (arr) |item| {
                    freeValue(allocator, item);
                }
                allocator.free(arr);
            },
            .object => |obj| {
                for (obj) |prop| {
                    freeValue(allocator, prop.value);
                }
                allocator.free(obj);
            },
            .variant_with_value => |vwv| {
                freeValue(allocator, vwv.value.*);
                allocator.destroy(vwv.value);
            },
            else => {},
        }
    }
};

pub const ASTNode = union(enum) {
    module_decl: ModuleDecl,
    import_stmt: ImportStmt,
    constraint_def: ConstraintDef,
    public_const: PublicConst,
    function_def: FunctionDef,
    comment: []const u8,
};

pub const ModuleDecl = struct {
    name: []const u8,
};

pub const ImportStmt = struct {
    path: []const u8,
    symbols: []const []const u8,
};

pub const ConstraintDef = struct {
    name: []const u8,
    inherits: ?[]const u8 = null,
    properties: []const Property,
};

pub const Property = struct {
    key: []const u8,
    value: Value,
};

pub const Value = union(enum) {
    string: []const u8,
    number: f64,
    boolean: bool,
    null_value: void,
    variant: []const u8,
    variant_with_value: VariantWithValue,
    array: []const Value,
    object: []const Property,
    query: QueryPattern,
    identifier: []const u8,
};

pub const VariantWithValue = struct {
    name: []const u8,
    value: *Value,
};

pub const QueryPattern = struct {
    language: []const u8,
    pattern: []const u8,
};

pub const PublicConst = struct {
    name: []const u8,
    value: Value,
};

pub const FunctionDef = struct {
    name: []const u8,
    params: []const FunctionParam,
    return_type: ?[]const u8,
    body: []const u8,
};

pub const FunctionParam = struct {
    name: []const u8,
    type_annotation: []const u8,
};

/// LLM client for macro expansion
pub const LLMClient = struct {
    api_key: []const u8,

    pub fn expandMacros(self: LLMClient, ast: AST) !AST {
        _ = self;
        // TODO: Use LLM to expand complex macros
        return ast;
    }
};

/// Language Server Protocol support (future)
pub const AriadneLSP = struct {
    // TODO: Implement LSP for IDE integration
};
