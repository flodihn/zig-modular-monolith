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
};

pub const LibHandle = if (@import("builtin").os.tag == .windows) c.HMODULE else ?*anyopaque;

// Struct to hold loaded module information
pub const LoadedModule = struct {
    name: []const u8,
    handle: LibHandle,
    func: *const anyopaque, // Store function pointer generically
};

pub fn loadDynamicLibrary(comptime T: type, lib_name: [:0]const u8, symbol_name: [:0]const u8) LoadLibError!struct { handle: LibHandle, func: T } {
    const is_dll = std.mem.endsWith(u8, lib_name, ".dll");
    const is_so = std.mem.endsWith(u8, lib_name, ".so");

    if (!is_dll and !is_so) {
        return error.InvalidFileExtension;
    }

    switch (@import("builtin").os.tag) {
        .windows => {
            if (!is_dll) {
                return error.InvalidFileExtension;
            }
            return try loadWindowsDll(T, lib_name, symbol_name);
        },
        .linux, .macos => {
            if (!is_so) {
                return error.InvalidFileExtension;
            }
            return try loadUnixLib(T, lib_name, symbol_name);
        },
        else => return error.UnsupportedPlatform,
    }
}

fn loadWindowsDll(comptime T: type, lib_name: [:0]const u8, symbol_name: [:0]const u8) LoadLibError!struct { handle: LibHandle, func: T } {
    const lib_handle = c.LoadLibraryA(lib_name.ptr) orelse {
        return error.LibraryLoadFailed;
    };

    const symbol = c.GetProcAddress(lib_handle, symbol_name.ptr) orelse {
        _ = c.FreeLibrary(lib_handle);
        return error.SymbolNotFound;
    };

    const func: T = @ptrCast(symbol);
    return .{ .handle = lib_handle, .func = func };
}

fn loadUnixLib(comptime T: type, lib_name: [:0]const u8, symbol_name: [:0]const u8) LoadLibError!struct { handle: LibHandle, func: T } {
    const lib_handle = c.dlopen(lib_name.ptr, c.RTLD_LAZY) orelse {
        return error.LibraryLoadFailed;
    };

    const symbol = c.dlsym(lib_handle, symbol_name.ptr) orelse {
        _ = c.dlclose(lib_handle);
        return error.SymbolNotFound;
    };

    const func: T = @ptrCast(symbol);
    return .{ .handle = lib_handle, .func = func };
}

// Load enabled modules from a ModuleConfig slice
pub fn loadModules(comptime T: type, allocator: std.mem.Allocator, configs: []const config_loader.ModuleConfig, symbol_name: [:0]const u8) LoadLibError![]LoadedModule {
    var loaded_modules = std.ArrayList(LoadedModule).init(allocator);
    errdefer {
        for (loaded_modules.items) |module| {
            if (@import("builtin").os.tag == .windows) {
                _ = c.FreeLibrary(module.handle);
            } else {
                _ = c.dlclose(module.handle);
            }
        }
        loaded_modules.deinit();
    }

    for (configs) |config| {
        if (!config.is_enabled) continue;

        const result = try loadDynamicLibrary(T, config.file_path, symbol_name);
        try loaded_modules.append(LoadedModule{
            .name = config.name,
            .handle = result.handle,
            .func = result.func,
        });
    }

    return loaded_modules.toOwnedSlice();
}
