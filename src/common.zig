// common.zig
// Defines shared types and interfaces for the Modular Monolith Framework.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith
const std = @import("std");
const Mutex = std.Thread.Mutex;

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
    event_allocator: std.mem.Allocator,
    make_event_mutex: Mutex,
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        sendEvent: *const fn (ptr: *anyopaque, event: Event) void,
        sendRequest: *const fn (ptr: *anyopaque, event: Event) void,
        sendResponse: *const fn (ptr: *anyopaque, event: Event) void,
    };

    pub fn sendEvent(self: *MonolithInterface, event: Event) void {
        self.vtable.sendEvent(self.ptr, event);
    }

    pub fn makeEvent(self: *MonolithInterface, comptime T: type, event_type: [*:0]const u8, data: T) !Event {
        // Using the shared arena allocator here would make function not thread safe, it need a mutex
        // to prevent multiple allocations at the same time.
        self.make_event_mutex.lock();
        defer self.make_event_mutex.unlock();

        // TODO: Lets not force struct type, events should be able to send numbers and string if they want to.
        // if (@typeInfo(T) == .@"struct") {
        //     @compileError("Data must be a struct");
        // }

        const event_type_slice = std.mem.span(event_type);
        const event_type_copy = try self.event_allocator.dupeZ(u8, event_type_slice);

        const data_copy = try self.event_allocator.create(T);
        data_copy.* = data;
        const data_copy_ptr: ?*anyopaque = @ptrCast(data_copy);

        return Event{ .event_type = event_type_copy, .data_len = @sizeOf(T), .data = data_copy_ptr };
    }

    pub fn getEventData(self: *MonolithInterface, comptime T: type, event: Event) !T {
        _ = self;
        if (event.data_len != @sizeOf(T)) {
            return error.InvalidDataSize;
        }

        const type_ptr: *const T = @ptrCast(@alignCast(event.data.?));
        return type_ptr.*;
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
    onEvent: ?*const fn (monolith: *MonolithInterface, event: Event) callconv(.C) void,
    pub const LibHandle = if (@import("builtin").os.tag == .windows) c.HMODULE else ?*anyopaque;
};
