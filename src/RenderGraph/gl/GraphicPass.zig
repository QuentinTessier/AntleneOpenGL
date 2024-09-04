const std = @import("std");
const gl = @import("../../gl4_6.zig");

pub const GlGraphicPass = @This();

pub const Attachment = union(enum) {
    External: u32,
    Global: []const u8,
    Local: u32,
};

program: u32,

// Example:
// const pass = GraphicPass.init("pass.json", userdata); // Load data from disk
// const rendergraph_resources = pass.resources(); // Get resources needed for this pass (e.g: Color buffer, depth buffer, ...)
//
// const rendergraph_pass = builder.pass("pass", &pass); // Add this pass to the render graph builder.
