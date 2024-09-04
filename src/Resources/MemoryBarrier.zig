const std = @import("std");
const gl = @import("../gl4_6.zig");

pub const Flags = packed struct(u32) {
    vertex_attrib_array: bool = false,
    element_array: bool = false,
    uniform: bool = false,
    texture_fetch: bool = false,
    shader_image_access: bool = false,
    command: bool = false,
    pixel_buffer: bool = false,
    texture_update: bool = false,
    framebuffer: bool = false,
    transform_feedback: bool = false,
    atomic_counter: bool = false,
    shader_storage: bool = false,
    query_buffer: bool = false,

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(u32));
        std.debug.assert(@bitSizeOf(@This()) == @bitSizeOf(u32));
    }

    pub fn all() Flags {
        const x: u32 = gl.ALL_BARRIER_BITS;
        return @bitCast(x);
    }
};

pub const MemoryBarrier = struct {
    pub fn inlineFn(flags: Flags) void {
        gl.memoryBarrier(@bitCast(flags));
    }
}.inlineFn;
