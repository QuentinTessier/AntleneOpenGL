const std = @import("std");
const gl = @import("../gl4_6.zig");

pub const TextureBarrier = struct {
    pub fn inlineFn() void {
        gl.textureBarrier();
    }
}.inlineFn;
