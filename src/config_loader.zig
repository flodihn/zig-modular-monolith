// config_loader.zig
const std = @import("std");

pub const KeyValue = extern struct {
    key: [*:0]const u8,
    value: [*:0]const u8,
};

pub const ModuleConfig = struct {
    name: []const u8,
    file_path: [:0]const u8,
    is_enabled: bool,
    module_specific_config: []const KeyValue = &.{},

    pub fn deinit(self: ModuleConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.file_path);
        for (self.module_specific_config) |kv| {
            allocator.free(std.mem.span(kv.key));
            allocator.free(std.mem.span(kv.value));
        }
        allocator.free(self.module_specific_config);
    }
};

pub fn loadConfig(allocator: std.mem.Allocator, file_path: []const u8) ![]ModuleConfig {
    const file_content = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(file_content);

    var modules = std.ArrayList(ModuleConfig).init(allocator);
    errdefer {
        for (modules.items) |module| {
            module.deinit(allocator);
        }
        modules.deinit();
    }

    var current_module: ?*ModuleConfig = null;
    errdefer if (current_module) |cm| allocator.destroy(cm);

    var lines = std.mem.splitSequence(u8, file_content, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (trimmed.len == 0) continue;

        if (std.mem.eql(u8, trimmed, "Module:")) {
            if (current_module != null) {
                try modules.append(current_module.?.*);
                allocator.destroy(current_module.?);
                current_module = null;
            }
            current_module = try allocator.create(ModuleConfig);
            current_module.?.* = ModuleConfig{
                .name = "",
                .file_path = "",
                .is_enabled = false,
                .module_specific_config = &.{},
            };
            continue;
        }

        if (current_module == null) continue;

        var parts = std.mem.splitSequence(u8, trimmed, ":");
        const key = std.mem.trim(u8, parts.next() orelse continue, " \t");
        const value = std.mem.trim(u8, parts.next() orelse continue, " \t");

        if (std.mem.eql(u8, key, "name")) {
            current_module.?.name = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "file_path")) {
            current_module.?.file_path = try allocator.dupeZ(u8, value);
        } else if (std.mem.eql(u8, key, "is_enabled")) {
            current_module.?.is_enabled = std.mem.eql(u8, value, "true");
        } else {
            var config_list = std.ArrayList(KeyValue).init(allocator);
            for (current_module.?.module_specific_config) |kv| {
                try config_list.append(kv);
            }
            try config_list.append(KeyValue{
                .key = try allocator.dupeZ(u8, key),
                .value = try allocator.dupeZ(u8, value),
            });
            const new_config = try config_list.toOwnedSlice();
            allocator.free(current_module.?.module_specific_config);
            current_module.?.module_specific_config = new_config;
        }
    }

    if (current_module != null) {
        try modules.append(current_module.?.*);
        allocator.destroy(current_module.?);
    }

    return modules.toOwnedSlice();
}
