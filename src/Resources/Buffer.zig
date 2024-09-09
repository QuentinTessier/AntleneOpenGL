const std = @import("std");
const gl = @import("../gl4_6.zig");

pub const Buffer = @This();

handle: u32,
size: usize,
stride: usize,
