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

const MyEvent = struct {
    data1: [*:0]const u8,
    data2: i32,
    data3: f32,
    data4: u8,
};

// Use var to allow modification, stored in global data section
var module_state = ModuleState{
    .counter = 0,
    .name = "ExampleModule2",
    .custom_value = 0,
    .other_value = "",
};

pub export fn start(monolith: *const MonolithInterface) callconv(.C) void {
    _ = monolith;
    std.debug.print("Module2 '{s}' started, initial counter: {}\n", .{ module_state.name, module_state.counter });
    //monolith.sendEvent(.{ .event_type = "jean", .data = 200 });
    //monolith.sendEvent(.{ .event_type = "Module2Started", .data = "ExampleModule2 started" });
    //monolith.sendEvent(.{ .event_type = "olle", .data = 22 });
}

pub export fn stop() callconv(.C) void {
    std.debug.print("Module2 '{s}' stopped, final counter: {}\n", .{ module_state.name, module_state.counter });
}

pub export fn update(delta_time: f32) callconv(.C) void {
    module_state.counter += 1;
    std.debug.print("Module2 '{s}' updated, delta_time: {d:.3}, counter: {}\n", .{ module_state.name, delta_time, module_state.counter });
}

pub export fn onEvent(monolith: *MonolithInterface, event: Event) callconv(.C) void {
    std.debug.print("Module2 '{s}' received event '{any}'\n", .{ module_state.name, event.event_type });

    const event_slice = std.mem.span(event.event_type);

    if (std.mem.eql(u8, event_slice, "ExampleModule.Started")) {
        const data = monolith.getEventData(MyEvent, event) catch |err| {
            std.debug.print("Error decoding event data {}\n", .{err});
            return;
        };
        std.debug.print("ExampleModule2 Decoded data: {s}, {} {} {}\n", .{ data.data1, data.data2, data.data3, data.data4 });
    }

    if (std.mem.eql(u8, event_slice, "Event2")) {
        const data = monolith.getEventData(MyEvent, event) catch |err| {
            std.debug.print("Error decoding event data {}\n", .{err});
            return;
        };
        std.debug.print("ExampleModule2 Decoded data: {s}, {} {} {}\n", .{ data.data1, data.data2, data.data3, data.data4 });
    }
}
