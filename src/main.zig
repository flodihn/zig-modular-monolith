// main.zig
// Main entry point for the Modular Monolith Framework, orchestrating module loading and lifecycle.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith

const std = @import("std");
const logger = @import("common.zig").logger;
const Monolith = @import("common.zig").Monolith;
const ModuleLoader = @import("module_loader.zig").ModuleLoader;
const ConfigLoader = @import("config_loader.zig").ConfigLoader;
const InternalEventSystem = @import("event_system/internal_event_system.zig").InternalEventSystem;

pub fn main() !void {
    logger.info("Starting the modular monolith...", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            logger.err("Memory leak detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    // Initialize the core components
    var config_loader = try ConfigLoader.init(allocator);
    defer config_loader.deinit();

    try config_loader.loadConfig("modules.config");

    var event_system = try InternalEventSystem.init(allocator);
    defer event_system.deinit();

    var module_loader = try ModuleLoader.init(allocator);
    defer module_loader.deinit();

    // Initialize Monolith struct
    //const monolith_instance = monolith.Monolith{
    //    .configLoader = config_loader_instance,
    //    .moduleLoader = module_loader_instance,
    //    .eventSystem = event_system_instance,
    //};

    // defer {
    //     for (configs) |config| {
    //         config.deinit(allocator);
    //     }
    //     allocator.free(configs);
    // }

    // Load modules
    try module_loader.loadModules(config_loader.module_configs);
    // std.debug.print("Number of modules loaded: {d}.\n", .{modules.len});
    // defer {
    //     for (modules) |module| {
    //         module.interface.stop();
    //         module.deinit();
    //     }
    //     allocator.free(modules);
    //     event_system_instance.deinitEventSystem();
    // }

    // Initialize event system with loaded modules
    //event_system_instance.initEventSystem(allocator, modules);

    // Call start for each module
    // for (modules) |module| {
    //     module.interface.start(&monolith_instance);
    // }

    // Send a test event from main
    //monolith_instance.eventSystem.sendEvent(&monolith_instance.eventSystem, "Main", .{ .event_type = "TestEvent", .data = "Sent from main" });
}
