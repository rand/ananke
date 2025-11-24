// Python extractor using line-by-line parsing
const std = @import("std");
const base = @import("base.zig");

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !base.SyntaxStructure {
    var structure = base.SyntaxStructure.init(allocator);
    errdefer structure.deinit();
    
    var line_num: u32 = 1;
    var lines = std.mem.splitScalar(u8, source, '\n');
    
    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;
        
        // Parse imports
        if (std.mem.startsWith(u8, trimmed, "import ") or std.mem.startsWith(u8, trimmed, "from ")) {
            if (try parseImport(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse classes
        else if (std.mem.startsWith(u8, trimmed, "class ") or std.mem.startsWith(u8, trimmed, "@dataclass")) {
            if (try parseClass(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse functions (def, async def, lambda)
        else if (std.mem.indexOf(u8, trimmed, "def ") != null or
                 std.mem.indexOf(u8, trimmed, "async def") != null or
                 std.mem.indexOf(u8, trimmed, "lambda") != null) {
            if (try parseFunction(allocator, trimmed, line_num)) |func_decl| {
                try structure.functions.append(allocator, func_decl);
            }
        }
    }
    
    return structure;
}

fn parseImport(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    var module_name: []const u8 = "";
    
    // Pattern: from MODULE import ...
    if (std.mem.startsWith(u8, line, "from ")) {
        const name_start: usize = 5;
        var name_end = name_start;
        
        while (name_end < line.len and line[name_end] != ' ' and line[name_end] != '\n') {
            name_end += 1;
        }
        
        if (name_end > name_start) {
            module_name = try allocator.dupe(u8, line[name_start..name_end]);
        }
    }
    // Pattern: import MODULE
    else if (std.mem.startsWith(u8, line, "import ")) {
        const name_start: usize = 7;
        var name_end = name_start;
        
        while (name_end < line.len and line[name_end] != ' ' and line[name_end] != ',' and line[name_end] != '\n') {
            name_end += 1;
        }
        
        if (name_end > name_start) {
            module_name = try allocator.dupe(u8, line[name_start..name_end]);
        }
    }
    
    if (module_name.len > 0) {
        return base.ImportDecl{
            .module = module_name,
            .line = line_num,
            .items = &.{},
        };
    }
    
    return null;
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    // Handle @dataclass decorator (look for class on next iteration)
    if (std.mem.startsWith(u8, line, "@dataclass")) {
        return null; // Will be picked up when "class" line is found
    }
    
    const class_pos = std.mem.indexOf(u8, line, "class ") orelse return null;
    const name_start = class_pos + 6;
    
    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }
    
    if (name_end <= name_start) return null;
    
    const name = try allocator.dupe(u8, line[name_start..name_end]);
    
    return base.TypeDecl{
        .name = name,
        .line = line_num,
        .kind = .class_type,
    };
}

fn parseFunction(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    const is_async = std.mem.indexOf(u8, line, "async def") != null;
    
    var name: ?[]const u8 = null;
    var return_type: ?[]const u8 = null;
    
    // Pattern: def name(...) or async def name(...)
    if (std.mem.indexOf(u8, line, "def ")) |def_pos| {
        const name_start = def_pos + 4;
        var name_end = name_start;
        
        while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
            name_end += 1;
        }
        
        if (name_end > name_start) {
            name = try allocator.dupe(u8, line[name_start..name_end]);
        }
        
        // Extract return type (look for -> TYPE:)
        if (std.mem.indexOf(u8, line, ") -> ")) |arrow_pos| {
            const type_start = arrow_pos + 5;
            var type_end = type_start;
            
            while (type_end < line.len and line[type_end] != ':' and line[type_end] != '\n') {
                type_end += 1;
            }
            
            if (type_end > type_start) {
                const type_str = std.mem.trim(u8, line[type_start..type_end], " \t");
                if (type_str.len > 0) {
                    return_type = try allocator.dupe(u8, type_str);
                }
            }
        }
    }
    // Pattern: lambda
    else if (std.mem.indexOf(u8, line, "lambda")) |lambda_pos| {
        // Try to extract variable name if it's an assignment
        if (std.mem.indexOf(u8, line[0..lambda_pos], " = ")) |eq_pos| {
            var name_start: usize = 0;
            while (name_start < eq_pos and (line[name_start] == ' ' or line[name_start] == '\t')) {
                name_start += 1;
            }
            
            var name_end = name_start;
            while (name_end < eq_pos and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
                name_end += 1;
            }
            
            if (name_end > name_start) {
                name = try allocator.dupe(u8, line[name_start..name_end]);
            }
        } else {
            name = try allocator.dupe(u8, "<lambda>");
        }
    }
    
    const has_error_handling = std.mem.indexOf(u8, line, "try:") != null or
                                std.mem.indexOf(u8, line, "except") != null or
                                std.mem.indexOf(u8, line, "raise") != null;

    if (name) |func_name| {
        return base.FunctionDecl{
            .name = func_name,
            .line = line_num,
            .is_async = is_async,
            .return_type = return_type,
            .has_error_handling = has_error_handling,
        };
    }

    // If we allocated return_type but didn't find a name, free it
    if (return_type) |ret_type| {
        allocator.free(ret_type);
    }

    return null;
}
