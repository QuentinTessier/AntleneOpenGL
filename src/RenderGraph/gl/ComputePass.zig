const std = @import("std");
const gl = @import("../../gl4_6.zig");

pub const GlComputePass = @This();

program: u32,
