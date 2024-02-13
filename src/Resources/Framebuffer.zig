const std = @import("std");
const gl = @import("../gl4_6.zig");

const Texture = @import("Texture.zig");

const ColorAttachment = @import("../Context.zig").ColorAttachment;
const PipelineInformation = @import("../Pipeline/PipelineInformation.zig");

pub const Framebuffer = @This();

handle: u32,
colorAttachments: std.ArrayListUnmanaged(Texture) = .{},
depthTexture: ?Texture = null,
stencilTexture: ?Texture = null,

pub fn hash(colorAttachment: []const ColorAttachment, depth: ?Texture, stencil: ?Texture) u64 {
    std.debug.assert(colorAttachment.len <= 8);
    var handles: [10]u32 = [1]u32{0} ** 10;

    for (colorAttachment, 0..) |attachment, index| {
        handles[index] = attachment.texture.handle;
    }
    if (depth) |texture| handles[8] = texture.handle;
    if (stencil) |texture| handles[9] = texture.handle;

    return std.hash.Murmur2_64.hash(std.mem.sliceAsBytes(&handles));
}

pub fn init(allocator: std.mem.Allocator, colorAttachment: []const ColorAttachment, depth: ?Texture, stencil: ?Texture) !Framebuffer {
    var framebuffer: Framebuffer = undefined;
    framebuffer.colorAttachments = .{};

    for (colorAttachment) |attachment| {
        framebuffer.colorAttachments.append(allocator, attachment.texture);
    }
    framebuffer.depthTexture = depth;
    framebuffer.stencilTexture = stencil;
}
