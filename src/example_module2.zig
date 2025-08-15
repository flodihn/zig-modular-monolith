// example_module.zig
// Example module for the Modular Monolith Framework, demonstrating event handling.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith
const std = @import("std");
const MonolithInterface = @import("common.zig").MonolithInterface;
const Event = @import("event_system/event.zig").Event;

const ModuleState = struct {
    counter: i32,
    name: [*:0]const u8,
    custom_value: i32 = 0,
    other_value: []const u8 = "",
};

// Use var to allow modification, stored in global data section
var module_state = ModuleState{
    .counter = 0,
    .name = "ExampleModule2",
    .custom_value = 0,
    .other_value = "",
};

pub export fn start(monolith: *const MonolithInterface) callconv(.C) void {
    std.debug.print("Module2 '{s}' started, initial counter: {}\n", .{ module_state.name, module_state.counter });
    monolith.sendEvent(.{ .event_type = "jean", .data = 200 });
    //monolith.internal_event_system.sendEvent(.{ .event_type = "ModuleStarted", .data = "ExampleModule started" });
    monolith.sendEvent(.{ .event_type = "olle", .data = 22 });
}

pub export fn stop() callconv(.C) void {
    std.debug.print("Module2 '{s}' stopped, final counter: {}\n", .{ module_state.name, module_state.counter });
}

pub export fn update(delta_time: f32) callconv(.C) void {
    module_state.counter += 1;
    std.debug.print("Module2 '{s}' updated, delta_time: {d:.3}, counter: {}\n", .{ module_state.name, delta_time, module_state.counter });
}

pub export fn onEvent(event: Event) callconv(.C) void {
    std.debug.print("Module2 '{s}' received event '{any}'\n", .{ module_state.name, event.event_type });
}
