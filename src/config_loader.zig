// config_loader.zig
// This is a configuration loader responsible for parsing the modules.config and creating
// an array of ModuleConfigs that will be used by the ModuleLoader to load all enabled modules.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith
const std = @import("std");
const logger = @import("common.zig").logger;
const ModuleConfig = @import("common.zig").ModuleConfig;

pub const ConfigLoader = struct {
    allocator: std.mem.Allocator,
    module_configs: std.ArrayList(*ModuleConfig),

    pub fn init(allocator: std.mem.Allocator) !ConfigLoader {
        return ConfigLoader{
            .allocator = allocator,
            .module_configs = std.ArrayList(*ModuleConfig).init(allocator),
        };
    }

    pub fn deinit(self: *ConfigLoader) void {
        for (self.module_configs.items) |module_config| {
            self.allocator.free(module_config.name);
            self.allocator.free(module_config.file_path);
            self.allocator.destroy(module_config);
        }
        self.module_configs.deinit();
    }

    pub fn loadConfig(self: *ConfigLoader, config_file_path: []const u8) !void {
        const file_content = try std.fs.cwd().readFileAlloc(self.allocator, config_file_path, 1024 * 1024);
        defer self.allocator.free(file_content);

        errdefer {
            for (self.module_configs.items) |module_config| {
                self.allocator.free(module_config.name);
                self.allocator.free(module_config.file_path);
                self.allocator.destroy(module_config);
            }
            self.module_configs.deinit();
        }

        var module_config: ?*ModuleConfig = null;
        errdefer if (module_config) |mod| self.allocator.destroy(mod);

        var lines = std.mem.splitSequence(u8, file_content, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0) continue;

            if (std.mem.eql(u8, trimmed, "Module:")) {
                if (module_config != null) {
                    try self.module_configs.append(module_config.?);
                    module_config = null;
                }
                module_config = try self.allocator.create(ModuleConfig);
                errdefer if (module_config) |mod| self.allocator.destroy(mod);
                continue;
            }

            if (module_config == null) continue;

            var parts = std.mem.splitSequence(u8, trimmed, ":");
            const key = std.mem.trim(u8, parts.next() orelse continue, " \t");
            const value = std.mem.trim(u8, parts.next() orelse continue, " \t");

            if (std.mem.eql(u8, key, "name")) {
                module_config.?.name = try self.allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "file_path")) {
                module_config.?.file_path = try self.allocator.dupeZ(u8, value);
            } else if (std.mem.eql(u8, key, "is_enabled")) {
                module_config.?.is_enabled = std.mem.eql(u8, value, "true");
            }
        }

        if (module_config != null) {
            try self.module_configs.append(module_config.?);
        }

        logger.info("Successfully added {} module configurations.", .{self.module_configs.items.len});
    }
};
