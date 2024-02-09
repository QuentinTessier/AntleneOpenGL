const std = @import("std");
const gl = @import("../gl4_6.zig");

const ColorAttachmentState = @import("Pipeline/PipelineInformation.zig").ColorAttachmentState;

pub const Framebuffer = @This();

handle: u32,
textures: []u32,
depthTexture: u32 = 0,
stencilTexture: u32 = 0,

pub fn init(allocator: std.mem.Allocator, attachments: []const ColorAttachmentState, width: u32, height: u32) !Framebuffer {
    var handle: u32 = 0;
    gl.createFramebuffers(1, @ptrCast(&handle));

    const textures = try allocator.alloc(u32, attachments.len);
    gl.createTextures(gl.TEXTURE_2D, @intCast(textures.len), textures.ptr);

    for (textures, 0..) |texture, i| {
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB32F, @intCast(width), @intCast(height), 0, gl.RGB, gl.FLOAT, null);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, @intCast(gl.COLOR_ATTACHMENT0 + i), gl.TEXTURE_2D, texture, 0);
    }
}
