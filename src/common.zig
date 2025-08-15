// common.zig
// Defines shared types and interfaces for the Modular Monolith Framework.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith
const std = @import("std");
const InternalEventSystem = @import("event_system/internal_event_system.zig").InternalEventSystem;
const ModuleLoader = @import("module_loader.zig").ModuleLoader;
const ConfigLoader = @import("config_loader.zig").ConfigLoader;
const Event = @import("event_system/event.zig").Event;

pub const logger = std.log.scoped(.modular_monolith);

pub const c = if (@import("builtin").os.tag == .windows)
    @cImport({
        @cInclude("windows.h");
    })
else
    @cImport({
        @cInclude("dlfcn.h");
    });

pub const MonolithInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        sendEvent: *const fn (ptr: *anyopaque, event: Event) void,
        sendRequest: *const fn (ptr: *anyopaque, event: Event) void,
        sendResponse: *const fn (ptr: *anyopaque, event: Event) void,
    };

    pub fn sendEvent(self: *const MonolithInterface, event: Event) void {
        self.vtable.sendEvent(self.ptr, event);
    }
};

pub const ModuleConfig = struct {
    name: []const u8 = &.{},
    file_path: [:0]const u8 = &.{},
    is_enabled: bool = false,
};

pub const Module = struct {
    name: []const u8,
    handle: LibHandle,
    start: *const fn (monolith_interface: *const MonolithInterface) callconv(.C) void,
    stop: *const fn () callconv(.C) void,
    update: *const fn (delta_time: f32) callconv(.C) void,
    onEvent: ?*const fn (event: Event) callconv(.C) void,
    pub const LibHandle = if (@import("builtin").os.tag == .windows) c.HMODULE else ?*anyopaque;
};
