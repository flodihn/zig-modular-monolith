// main.zig
const std = @import("std");
const module_loader = @import("module_loader.zig");
const config_loader = @import("config_loader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            std.debug.print("Memory leak detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    // Load config from modules.config
    const configs = try config_loader.loadConfig(allocator, "modules.config");
    defer {
        for (configs) |config| {
            config.deinit(allocator);
        }
        allocator.free(configs);
    }

    // Load modules
    const modules = try module_loader.loadModules(allocator, configs);
    defer {
        for (modules) |module| {
            module.interface.stop();
            module.deinit();
        }
        allocator.free(modules);
    }

    // Call start for each module with its configuration
    for (modules, configs) |module, config| {
        std.debug.print("Starting module: {s}\n", .{module.name});
        module.interface.start(if (config.module_specific_config.len > 0) config.module_specific_config.ptr else null, config.module_specific_config.len, module.interface.findConfigValue);
    }
}
