// event.zig
// Defines the Event structure for module communication in the Modular Monolith Framework.
// Copyright (c) 2025 Christian Flodihn
// Licensed under the MIT License. See LICENSE.txt in the project root for details.
// Part of the Modular Monolith Framework: https://github.com/flodihn/zig-modular-monolith

pub const Event = extern struct {
    event_type: [*:0]const u8,
    data: [*:0]const u8,
};
