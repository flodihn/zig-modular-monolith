// monolith.zig
// Monolith struct used to store pointers to the rest of the system and contains
// functions to run it.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith
const std = @import("std");
const logger = @import("common.zig").logger;
const InternalEventSystem = @import("event_system/internal_event_system.zig").InternalEventSystem;
const MonolithInterface = @import("common.zig").MonolithInterface;
const ConfigLoader = @import("config_loader.zig").ConfigLoader;
const ModuleLoader = @import("module_loader.zig").ModuleLoader;
const Event = @import("event_system/event.zig").Event;

pub const Monolith = struct {
    allocator: std.mem.Allocator,
    config_loader: *ConfigLoader,
    module_loader: *ModuleLoader,
    internal_event_system: *InternalEventSystem,
    interface: MonolithInterface,

    pub fn init(
        allocator: std.mem.Allocator,
        config_loader: *ConfigLoader,
        module_loader: *ModuleLoader,
        internal_event_system: *InternalEventSystem,
    ) !Monolith {
        return Monolith{
            .allocator = allocator,
            .config_loader = config_loader,
            .module_loader = module_loader,
            .internal_event_system = internal_event_system,
            .interface = undefined, // Temporarily undefined; set immediately below.
        };
    }

    pub fn createInterface(self: *Monolith) MonolithInterface {
        const impl = struct {
            fn sendEventFn(ptr: *anyopaque, event: Event) void {
                const monolith: *Monolith = @ptrCast(@alignCast(ptr));
                // TODO: Also send on the external event handler if it exists.
                monolith.internal_event_system.sendEvent(event);
            }

            fn sendRequestFn(ptr: *anyopaque, event: Event) void {
                const monolith: *Monolith = @ptrCast(@alignCast(ptr));
                // TODO: Send on the external event handler if destination module does not exist in this monolith.
                monolith.internal_event_system.sendRequest(event);
            }

            fn sendResponseFn(ptr: *anyopaque, event: Event) void {
                const monolith: *Monolith = @ptrCast(@alignCast(ptr));
                // TODO: Send on the external eventhandler if destination module does not exist in this monolith.
                monolith.internal_event_system.sendResponse(event);
            }
        };

        return MonolithInterface{
            .ptr = @ptrCast(@alignCast(self)),
            .vtable = &comptime MonolithInterface.VTable{
                .sendEvent = impl.sendEventFn,
                .sendRequest = impl.sendRequestFn,
                .sendResponse = impl.sendResponseFn,
            },
        };
    }

    pub fn load(self: *const Monolith) !void {
        try self.config_loader.loadConfig("modules.config");
        try self.module_loader.loadModules(self.config_loader.module_configs);
    }

    pub fn start(self: *const Monolith) !void {
        for (self.module_loader.modules.items) |module| {
            module.start(&self.interface);
        }
    }

    pub fn run(self: *const Monolith) !bool {
        try self.internal_event_system.pumpEvents();
        return true;
    }
};
