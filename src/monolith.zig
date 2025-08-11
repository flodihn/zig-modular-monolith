// monolith.zig
// Monolith struct used to store pointers to the rest of the system and contains
// functions to run it.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith
const std = @import("std");
const logger = @import("common.zig").logger;
const ConfigLoader = @import("config_loader.zig").ConfigLoader;
const ModuleLoader = @import("module_loader.zig").ModuleLoader;
const InternalEventSystem = @import("event_system/internal_event_system.zig").InternalEventSystem;

pub const Monolith = struct {
    allocator: std.mem.Allocator,
    config_loader: *ConfigLoader,
    module_loader: *ModuleLoader,
    internal_event_system: *InternalEventSystem,

    pub fn init(allocator: std.mem.Allocator, config_loader: *ConfigLoader, module_loader: *ModuleLoader, internal_event_system: *InternalEventSystem) !Monolith {
        return Monolith{ .allocator = allocator, .config_loader = config_loader, .module_loader = module_loader, .internal_event_system = internal_event_system };
    }

    pub fn load(self: *const Monolith) !void {
        try self.config_loader.loadConfig("modules.config");
        try self.module_loader.loadModules(self.config_loader.module_configs);
    }

    pub fn run(self: *const Monolith) !bool {
        try self.internal_event_system.pumpEvents();
        return true;
    }
};
