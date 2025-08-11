// internal_event_system.zig
// Implements the internal event system for broadcasting events between modules in the same monolith.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith
const std = @import("std");
const event = @import("event.zig");
const common = @import("../common.zig");

pub const InternalEventSystem = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !InternalEventSystem {
        return InternalEventSystem{ .allocator = allocator };
    }

    pub fn deinit(self: *InternalEventSystem) void {
        _ = self;
        // if (self.allocator) |alloc| {
        //     if (self.loaded_modules) |mods| {
        //         alloc.free(mods);
        //     }
        // }
        //self.allocator = null;
        std.debug.print("Event system deinitialized\n", .{});
    }

    pub fn sendEvent(self: *InternalEventSystem, sender_name: [*:0]const u8, evt: event.Event) callconv(.C) void {
        _ = self;
        // if (self.loaded_modules == null or self.allocator == null) {
        //     std.debug.print("Error: Event system not initialized\n", .{});
        //     return;
        // }

        std.debug.print("Broadcasting event '{s}' from module '{s}' with data: {s}\n", .{ evt.event_type, sender_name, evt.data });
        // for (self.loaded_modules.?) |module| {
        //     if (!std.mem.eql(u8, std.mem.span(sender_name), std.mem.span(module.name))) {
        //         if (module.interface.onEvent) |callback| {
        //             std.debug.print("Sending event '{s}' to module '{s}'\n", .{ evt.event_type, module.name });
        //             callback(evt);
        //         }
        //     }
        // }
    }

    pub fn pumpEvents(self: *InternalEventSystem) !void {
        _ = self;
    }
};
