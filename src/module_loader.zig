// module_loader.zig
const std = @import("std");
const config_loader = @import("config_loader.zig");

pub const c = if (@import("builtin").os.tag == .windows)
    @cImport({
        @cInclude("windows.h");
    })
else
    @cImport({
        @cInclude("dlfcn.h");
    });

const LoadLibError = error{
    LibraryNotFound,
    SymbolNotFound,
    LibraryLoadFailed,
    UnsupportedPlatform,
    InvalidFileExtension,
    OutOfMemory,
};

// Define symbol names as constants
const START_SYMBOL: [:0]const u8 = "start";
const STOP_SYMBOL: [:0]const u8 = "stop";
const UPDATE_SYMBOL: [:0]const u8 = "update";

// Define the interface for the loader
pub const ModuleInterface = struct {
    start: *const fn (config: ?[*]const config_loader.KeyValue, config_len: usize, findConfigValue: ?*const fn (config: ?[*]const config_loader.KeyValue, config_len: usize, key: [*:0]const u8) callconv(.C) ?[*:0]const u8) callconv(.C) void,
    stop: *const fn () callconv(.C) void,
    update: *const fn (delta_time: f32) callconv(.C) void,
    findConfigValue: ?*const fn (config: ?[*]const config_loader.KeyValue, config_len: usize, key: [*:0]const u8) callconv(.C) ?[*:0]const u8,
};

// Struct to hold loaded module information
pub const LoadedModule = struct {
    name: []const u8,
    handle: LibHandle,
    interface: ModuleInterface,

    pub fn deinit(self: LoadedModule) void {
        if (@import("builtin").os.tag == .windows) {
            _ = c.FreeLibrary(self.handle);
        } else {
            _ = c.dlclose(self.handle);
        }
    }
};

pub const LibHandle = if (@import("builtin").os.tag == .windows) c.HMODULE else ?*anyopaque;

pub fn loadModules(allocator: std.mem.Allocator, configs: []const config_loader.ModuleConfig) LoadLibError![]LoadedModule {
    var loaded_modules = std.ArrayList(LoadedModule).init(allocator);
    errdefer {
        for (loaded_modules.items) |module| {
            module.deinit();
        }
        loaded_modules.deinit();
    }

    for (configs) |config| {
        if (!config.is_enabled) continue;

        const loadedModule = try loadDynamicLibrary(config);
        try loaded_modules.append(loadedModule);
    }

    return loaded_modules.toOwnedSlice();
}

pub fn loadDynamicLibrary(moduleConfig: config_loader.ModuleConfig) LoadLibError!LoadedModule {
    const is_dll = std.mem.endsWith(u8, moduleConfig.file_path, ".dll");
    const is_so = std.mem.endsWith(u8, moduleConfig.file_path, ".so");
    const is_dylib = std.mem.endsWith(u8, moduleConfig.file_path, ".dylib");

    if (!is_dll and !is_so and !is_dylib) {
        return error.InvalidFileExtension;
    }

    switch (@import("builtin").os.tag) {
        .windows => {
            if (is_so or is_dylib) {
                return error.InvalidFileExtension;
            }
            return try loadWindowsDll(moduleConfig);
        },
        .linux, .macos => {
            if (is_dll or is_dylib) {
                return error.InvalidFileExtension;
            }
            return try loadUnixLib(moduleConfig);
        },
        else => return error.UnsupportedPlatform,
    }
}

fn loadWindowsDll(moduleConfig: config_loader.ModuleConfig) LoadLibError!LoadedModule {
    const lib_handle = c.LoadLibraryA(moduleConfig.file_path.ptr) orelse {
        std.debug.print("Failed to load library: {s}\n", .{moduleConfig.file_path});
        return error.LibraryLoadFailed;
    };

    const start = c.GetProcAddress(lib_handle, START_SYMBOL.ptr) orelse {
        _ = c.FreeLibrary(lib_handle);
        std.debug.print("Symbol not found: {s}\n", .{START_SYMBOL});
        return error.SymbolNotFound;
    };
    const stop = c.GetProcAddress(lib_handle, STOP_SYMBOL.ptr) orelse {
        _ = c.FreeLibrary(lib_handle);
        std.debug.print("Symbol not found: {s}\n", .{STOP_SYMBOL});
        return error.SymbolNotFound;
    };
    const update = c.GetProcAddress(lib_handle, UPDATE_SYMBOL.ptr) orelse {
        _ = c.FreeLibrary(lib_handle);
        std.debug.print("Symbol not found: {s}\n", .{UPDATE_SYMBOL});
        return error.SymbolNotFound;
    };

    return LoadedModule{
        .name = moduleConfig.name,
        .handle = lib_handle,
        .interface = ModuleInterface{
            .start = @ptrCast(@alignCast(start)),
            .stop = @ptrCast(@alignCast(stop)),
            .update = @ptrCast(@alignCast(update)),
            .findConfigValue = &findConfigValue,
        },
    };
}

fn loadUnixLib(moduleConfig: config_loader.ModuleConfig) LoadLibError!LoadedModule {
    const lib_handle = c.dlopen(moduleConfig.file_path.ptr, c.RTLD_LAZY) orelse {
        std.debug.print("Failed to load library: {s}\n", .{moduleConfig.file_path});
        return error.LibraryLoadFailed;
    };

    const start = c.dlsym(lib_handle, START_SYMBOL.ptr) orelse {
        _ = c.dlclose(lib_handle);
        std.debug.print("Symbol not found: {s}\n", .{START_SYMBOL});
        return error.SymbolNotFound;
    };
    const stop = c.dlsym(lib_handle, STOP_SYMBOL.ptr) orelse {
        _ = c.dlclose(lib_handle);
        std.debug.print("Symbol not found: {s}\n", .{STOP_SYMBOL});
        return error.SymbolNotFound;
    };
    const update = c.dlsym(lib_handle, UPDATE_SYMBOL.ptr) orelse {
        _ = c.dlclose(lib_handle);
        std.debug.print("Symbol not found: {s}\n", .{UPDATE_SYMBOL});
        return error.SymbolNotFound;
    };

    return LoadedModule{
        .name = moduleConfig.name,
        .handle = lib_handle,
        .interface = ModuleInterface{
            .start = @ptrCast(@alignCast(start)),
            .stop = @ptrCast(@alignCast(stop)),
            .update = @ptrCast(@alignCast(update)),
            .findConfigValue = &findConfigValue,
        },
    };
}

// Framework-provided helper to find a config value by key
pub fn findConfigValue(config: ?[*]const config_loader.KeyValue, config_len: usize, key: [*:0]const u8) callconv(.C) ?[*:0]const u8 {
    if (config == null) return null;

    const key_str = std.mem.span(key);
    for (config.?[0..config_len]) |kv| {
        if (std.mem.eql(u8, std.mem.span(kv.key), key_str)) {
            return kv.value;
        }
    }
    return null;
}
