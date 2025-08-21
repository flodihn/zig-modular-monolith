// main.zig
// Main entry point for the Modular Monolith Framework, orchestrating module loading and lifecycle.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith

const std = @import("std");
const logger = @import("common.zig").logger;
const Monolith = @import("monolith.zig").Monolith;
const ModuleLoader = @import("module_loader.zig").ModuleLoader;
const ConfigLoader = @import("config_loader.zig").ConfigLoader;
const InternalEventSystem = @import("event_system/internal_event_system.zig").InternalEventSystem;

// Global atomic flag for SIGINT
var should_exit = std.atomic.Value(bool).init(false);

// Signal handler for SIGINT
fn handleSigint(sig: i32, info: *const std.posix.siginfo_t, context: ?*const anyopaque) callconv(.C) void {
    _ = sig;
    _ = info;
    _ = context; // Unused parameters
    should_exit.store(true, .release);
    logger.info("Received SIGINT, stopping the modular monolith...", .{});
}

pub fn main() !void {
    var error_occurred: ?anyerror = null;

    defer {
        if (error_occurred) |err| {
            logger.info("Modular monolith stopped due to error {}.", .{err});
        } else {
            logger.info("Modular monolith successfully stopped.", .{});
        }
    }

    logger.info("Starting the modular monolith...", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            logger.err("Memory leak detected!\n", .{});
        }
    }

    const allocator = gpa.allocator();

    const event_allocator = std.heap.ArenaAllocator.init(allocator);
    defer event_allocator.deinit();

    const act = std.posix.Sigaction{
        .handler = .{ .sigaction = handleSigint },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
    logger.info("SIGINT handler registered, press control-c to stop the modular monolith.", .{});

    var config_loader = ConfigLoader.init(allocator) catch |err| {
        error_occurred = err;
        return;
    };
    defer config_loader.deinit();

    var module_loader = ModuleLoader.init(allocator) catch |err| {
        error_occurred = err;
        return;
    };
    defer module_loader.deinit();

    var internal_event_system = InternalEventSystem.init(
        allocator,
        event_allocator,
        &module_loader,
    ) catch |err| {
        error_occurred = err;
        return;
    };
    defer internal_event_system.deinit();

    var monolith: Monolith = try Monolith.init(
        allocator,
        event_allocator,
        &config_loader,
        &module_loader,
        &internal_event_system,
    );

    monolith.interface = monolith.createInterface();

    monolith.load() catch |err| {
        error_occurred = err;
        return;
    };

    monolith.start() catch |err| {
        error_occurred = err;
        return;
    };

    logger.info("Running the modular monolith...", .{});
    while (try monolith.run()) {
        try monolith.internal_event_system.pumpEvents();
        std.time.sleep(10 * std.time.ns_per_ms);

        if (should_exit.load(.acquire)) {
            break;
        }
    }

    // Call start for each module
    // for (modules) |module| {
    //     module.interface.start(&monolith_instance);
    // }

    // Send a test event from main
    //monolith_instance.eventSystem.sendEvent(&monolith_instance.eventSystem, "Main", .{ .event_type = "TestEvent", .data = "Sent from main" });
}
