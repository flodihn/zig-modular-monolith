const std = @import("std");
const config_loader = @import("config_loader.zig");
const module_loader = @import("module_loader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse the TOML configuration
    const module_configs = try config_loader.parseModuleConfig(allocator, "modules.config");
    defer {
        for (module_configs) |*config| {
            config.deinit(allocator);
        }
        allocator.free(module_configs);
    }

    // Print all ModuleConfig structs to verify parsing
    std.debug.print("Parsed Module Configurations:\n", .{});
    for (module_configs) |config| {
        std.debug.print("  Name: {s}, File Path: {s}, Enabled: {}\n", .{
            config.name,
            config.file_path,
            config.is_enabled,
        });
    }

    // Define the function signature to load
    //const MyFuncType = fn (i32) callconv(.C) i32;

    // Load enabled modules
    //const loaded_modules = try module_loader.loadModules(MyFuncType, allocator, module_configs, "my_function");
    //defer {
    //    for (loaded_modules) |module| {
    //        if (@import("builtin").os.tag == .windows) {
    //            _ = module_loader.c.FreeLibrary(module.handle);
    //        } else {
    //            _ = module_loader.c.dlclose(module.handle);
    //        }
    //    }
    //    allocator.free(loaded_modules);
    //}

    // Call each loaded function
    //for (loaded_modules) |module| {
    //    const func: MyFuncType = @ptrCast(module.func);
    //    const result = func(42);
    //    std.debug.print("Module '{s}' result: {}\n", .{ module.name, result });
    //}
}
