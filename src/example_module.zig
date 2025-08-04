// example_module.zig
const std = @import("std");
const config_loader = @import("config_loader.zig");

const ModuleState = struct {
    counter: i32,
    name: [:0]const u8,
    custom_value: i32 = 0,
    other_value: []const u8 = "",
};

// Use var to allow modification, stored in global data section
var module_state = ModuleState{
    .counter = 0,
    .name = "ExampleModule",
    .custom_value = 0,
    .other_value = "",
};

pub export fn start(config: ?[*]const config_loader.KeyValue, config_len: usize, findConfigValue: ?*const fn (config: ?[*]const config_loader.KeyValue, config_len: usize, key: [*:0]const u8) callconv(.C) ?[*:0]const u8) callconv(.C) void {
    std.debug.print("Module '{s}' started, initial counter: {}\n", .{ module_state.name, module_state.counter });

    if (config != null and findConfigValue != null) {
        if (findConfigValue.?(config, config_len, "module_custom_value")) |value| {
            module_state.custom_value = std.fmt.parseInt(i32, std.mem.span(value), 10) catch 0;
            std.debug.print("Module '{s}' got module_custom_value: {}\n", .{ module_state.name, module_state.custom_value });
        }
        if (findConfigValue.?(config, config_len, "some_other_module_value")) |value| {
            module_state.other_value = std.mem.span(value);
            std.debug.print("Module '{s}' got some_other_module_value: {s}\n", .{ module_state.name, module_state.other_value });
        }
    }
}

pub export fn stop() callconv(.C) void {
    std.debug.print("Module '{s}' stopped, final counter: {}\n", .{ module_state.name, module_state.counter });
}

pub export fn update(delta_time: f32) callconv(.C) void {
    module_state.counter += 1;
    std.debug.print("Module '{s}' updated, delta_time: {d:.3}, counter: {}\n", .{ module_state.name, delta_time, module_state.counter });
}
