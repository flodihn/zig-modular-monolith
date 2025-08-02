const std = @import("std");

// Struct to represent a module from the text config
pub const ModuleConfig = struct {
    name: [:0]const u8, // Changed to null-terminated for safety
    file_path: [:0]const u8,
    is_enabled: bool,

    pub fn deinit(self: *ModuleConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.file_path);
    }
};

// Parse text file and return a list of module configurations
pub fn parseModuleConfig(allocator: std.mem.Allocator, config_file_path: []const u8) ![]ModuleConfig {
    // Read the text file
    const file = try std.fs.cwd().openFile(config_file_path, .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024); // Max 1MB
    defer allocator.free(file_contents);

    // Validate file contents
    if (!std.unicode.utf8Validate(file_contents)) {
        std.debug.print("Error: modules.txt contains invalid UTF-8\n", .{});
        return error.InvalidUtf8;
    }

    // Split content into lines
    var lines = std.mem.splitSequence(u8, file_contents, "\n");
    var module_configs = std.ArrayList(ModuleConfig).init(allocator);
    defer module_configs.deinit();

    var current_module: ?struct {
        name: ?[]const u8,
        file_path: ?[]const u8,
        is_enabled: ?bool,
    } = null;

    var line_number: usize = 1;
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        std.debug.print("Line {}: '{s}'\n", .{ line_number, trimmed }); // Debug print

        if (trimmed.len == 0) {
            // Empty line, finalize current module if exists
            if (current_module) |module| {
                if (module.name == null or module.file_path == null or module.is_enabled == null) {
                    std.debug.print("Error at line {}: Incomplete module\n", .{line_number});
                    return error.IncompleteModule;
                }
                const name = try allocator.dupeZ(u8, module.name.?);
                const file_path = try allocator.dupeZ(u8, module.file_path.?);
                try module_configs.append(ModuleConfig{
                    .name = name,
                    .file_path = file_path,
                    .is_enabled = module.is_enabled.?,
                });
                current_module = null;
            }
            line_number += 1;
            continue;
        }

        if (std.mem.eql(u8, trimmed, "Module:")) {
            // Start new module, finalize previous if exists
            if (current_module) |module| {
                if (module.name == null or module.file_path == null or module.is_enabled == null) {
                    std.debug.print("Error at line {}: Incomplete module\n", .{line_number});
                    return error.IncompleteModule;
                }
                const name = try allocator.dupeZ(u8, module.name.?);
                const file_path = try allocator.dupeZ(u8, module.file_path.?);
                try module_configs.append(ModuleConfig{
                    .name = name,
                    .file_path = file_path,
                    .is_enabled = module.is_enabled.?,
                });
            }
            current_module = .{ .name = null, .file_path = null, .is_enabled = null };
            line_number += 1;
            continue;
        }

        // Parse key-value pair
        var key_value = std.mem.splitSequence(u8, trimmed, ":");
        const key = std.mem.trim(u8, key_value.next() orelse {
            std.debug.print("Error at line {}: Invalid line format\n", .{line_number});
            return error.InvalidLine;
        }, " \t");
        const value = std.mem.trim(u8, key_value.next() orelse {
            std.debug.print("Error at line {}: Missing value\n", .{line_number});
            return error.InvalidLine;
        }, " \t");

        if (current_module == null) {
            std.debug.print("Error at line {}: Field outside Module section\n", .{line_number});
            return error.UnexpectedField;
        }

        if (std.mem.eql(u8, key, "name")) {
            current_module.?.name = value;
        } else if (std.mem.eql(u8, key, "file_path")) {
            current_module.?.file_path = value;
        } else if (std.mem.eql(u8, key, "is_enabled")) {
            if (std.mem.eql(u8, value, "true")) {
                current_module.?.is_enabled = true;
            } else if (std.mem.eql(u8, value, "false")) {
                current_module.?.is_enabled = false;
            } else {
                std.debug.print("Error at line {}: Invalid boolean value '{s}'\n", .{ line_number, value });
                return error.InvalidBoolean;
            }
        } else {
            std.debug.print("Error at line {}: Unknown field '{s}'\n", .{ line_number, key });
            return error.UnknownField;
        }
        line_number += 1;
    }

    // Finalize last module if exists
    if (current_module) |module| {
        if (module.name == null or module.file_path == null or module.is_enabled == null) {
            std.debug.print("Error at line {}: Incomplete module\n", .{line_number});
            return error.IncompleteModule;
        }
        const name = try allocator.dupeZ(u8, module.name.?);
        const file_path = try allocator.dupeZ(u8, module.file_path.?);
        try module_configs.append(ModuleConfig{
            .name = name,
            .file_path = file_path,
            .is_enabled = module.is_enabled.?,
        });
    }

    return module_configs.toOwnedSlice();
}
