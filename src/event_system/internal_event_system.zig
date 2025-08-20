// internal_event_system.zig
// Implements the internal event system for broadcasting events between modules in the same monolith.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith
const std = @import("std");
const ModuleLoader = @import("../module_loader.zig").ModuleLoader;
const logger = @import("../common.zig").logger;
const Event = @import("event.zig").Event;

const Fifo = std.fifo.LinearFifo(Event, .Dynamic);
const Mutex = std.Thread.Mutex;

pub const InternalEventSystem = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    event_queue_mutex: Mutex,
    event_queue: Fifo,
    module_loader: *ModuleLoader,

    pub fn init(allocator: std.mem.Allocator, module_loader: *ModuleLoader) !InternalEventSystem {
        return InternalEventSystem{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .event_queue_mutex = Mutex{},
            .event_queue = Fifo.init(allocator),
            .module_loader = module_loader,
        };
    }

    pub fn deinit(self: *InternalEventSystem) void {
        self.arena.deinit();
        self.event_queue.deinit();
        std.debug.print("Event system deinitialized\n", .{});
    }

    pub fn sendEvent(self: *InternalEventSystem, event: Event) callconv(.C) void {
        self.event_queue_mutex.lock();
        defer self.event_queue_mutex.unlock();

        // Deep copy before queuing to own the strings because modules might
        // have stack allocated the strings.
        //const copied_event = self.deepCopyEvent(event) catch |err| {
        //    logger.err("Error deep copying event: {}", .{err});
        //    return;
        //};

        self.event_queue.writeItem(event) catch |err| {
            logger.err("Error writing event to queue: {}", .{err});
            return;
        };
    }

    pub fn sendRequest(self: *InternalEventSystem, event: Event) callconv(.C) void {
        _ = self;
        _ = event;
    }

    pub fn sendResponse(self: *InternalEventSystem, event: Event) callconv(.C) void {
        _ = self;
        _ = event;
    }

    pub fn pumpEvents(self: *InternalEventSystem) !void {
        self.event_queue_mutex.lock();
        defer self.event_queue_mutex.unlock();

        while (self.event_queue.count > 0) {
            const event_opt = self.event_queue.readItem();
            if (event_opt == null) return;
            const event = event_opt.?;

            // Broadcast to modules
            for (self.module_loader.modules.items) |module| {
                if (module.onEvent) |onEvent| {
                    onEvent(event);
                }
            }
        }

        _ = self.arena.reset(.retain_capacity);
    }

    // fn deepCopyEvent(self: *InternalEventSystem, event: Event) !Event {
    //     const allocator = self.arena.allocator();

    //     const event_type_slice = std.mem.span(event.event_type);
    //     const event_type_copy = try allocator.dupeZ(u8, event_type_slice);

    //     const data_slice = std.mem.span(event.data);
    //     const data_copy = try self.allocator.dupe(u8, data_slice);

    //     return Event{
    //         .event_type = event_type_copy,
    //         .data = data_copy,
    //     };
    // }
};
