// module_loader.zig
// Loads and manages dynamic modules for the Modular Monolith Framework.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith
const std = @import("std");
const logger = @import("common.zig").logger;
const Module = @import("common.zig").Module;
const ModuleConfig = @import("common.zig").ModuleConfig;

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
const ONEVENT_SYMBOL: [:0]const u8 = "onEvent";

pub const ModuleLoader = struct {
    allocator: std.mem.Allocator,
    modules: std.ArrayList(*Module),

    pub const c = if (@import("builtin").os.tag == .windows)
        @cImport({
            @cInclude("windows.h");
        })
    else
        @cImport({
            @cInclude("dlfcn.h");
        });

    pub fn init(allocator: std.mem.Allocator) !ModuleLoader {
        return ModuleLoader{
            .allocator = allocator,
            .modules = std.ArrayList(*Module).init(allocator),
        };
    }

    pub fn deinit(self: *ModuleLoader) void {
        for (self.modules.items) |module| {
            if (@import("builtin").os.tag == .windows) {
                _ = c.FreeLibrary(module.handle);
            } else {
                _ = c.dlclose(module.handle);
            }
            self.allocator.destroy(module);
        }
        self.modules.deinit();
    }

    pub fn loadModules(self: *ModuleLoader, module_configs: std.ArrayList(*ModuleConfig)) LoadLibError!void {
        errdefer {
            self.deinit();
        }

        for (module_configs.items) |module_config| {
            if (!module_config.is_enabled) continue;

            const module = try self.loadDynamicLibrary(module_config);
            try self.modules.append(module);
            logger.info("Successfully loaded module: {s}", .{module.name});
        }
    }

    fn loadDynamicLibrary(self: *ModuleLoader, moduleConfig: *ModuleConfig) LoadLibError!*Module {
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
                return try self.loadWindowsDll(moduleConfig);
            },
            .linux => {
                if (is_dll or is_dylib) {
                    return error.InvalidFileExtension;
                }
                return try self.loadUnixLib(moduleConfig);
            },
            .macos => {
                if (is_dll) {
                    return error.InvalidFileExtension;
                }
                return try self.loadUnixLib(moduleConfig);
            },
            else => return error.UnsupportedPlatform,
        }
    }

    fn loadWindowsDll(self: *ModuleLoader, moduleConfig: *ModuleConfig) LoadLibError!*Module {
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
        const onEvent = c.GetProcAddress(lib_handle, ONEVENT_SYMBOL.ptr);

        const module = try self.allocator.create(Module);
        errdefer self.allocator.destroy(module);

        module.* = Module{
            .name = moduleConfig.name,
            .handle = lib_handle,
            .start = @ptrCast(@alignCast(start)),
            .stop = @ptrCast(@alignCast(stop)),
            .update = @ptrCast(@alignCast(update)),
            .onEvent = if (onEvent) |ptr| @ptrCast(@alignCast(ptr)) else null,
        };

        return module;
    }

    fn loadUnixLib(self: *ModuleLoader, moduleConfig: *ModuleConfig) LoadLibError!*Module {
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
        const onEvent = c.dlsym(lib_handle, ONEVENT_SYMBOL.ptr);

        const module = try self.allocator.create(Module);
        errdefer self.allocator.destroy(module);

        module.* = Module{
            .name = moduleConfig.name,
            .handle = lib_handle,
            .start = @ptrCast(@alignCast(start)),
            .stop = @ptrCast(@alignCast(stop)),
            .update = @ptrCast(@alignCast(update)),
            .onEvent = if (onEvent) |ptr| @ptrCast(@alignCast(ptr)) else null,
        };

        return module;
    }
};
