const std = @import("std");
const gl = @import("../gl4_6.zig");

const Texture = @import("Texture.zig");

const ColorAttachment = @import("../Context.zig").ColorAttachment;
const PipelineInformation = @import("../Pipeline/PipelineInformation.zig");

pub const Framebuffer = @This();

pub const FramebufferCreateInfo = struct {
    colorAttachment: []const Texture,
    depth: ?Texture,
    stencil: ?Texture,
};

allocator: std.mem.Allocator,
handle: u32,
colorAttachments: []Texture = .{},
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

pub fn init(allocator: std.mem.Allocator, name: ?[]const u8, colorAttachment: []const Texture, depth: ?Texture, stencil: ?Texture) !Framebuffer {
    var framebuffer: Framebuffer = undefined;
    framebuffer.allocator = allocator;
    framebuffer.colorAttachments = try allocator.alloc(Texture, colorAttachment.len);
    var drawBuffers: []gl.GLenum = try allocator.alloc(gl.GLenum, colorAttachment.len);
    defer allocator.free(drawBuffers);

    for (colorAttachment, 0..) |attachment, index| {
        framebuffer.colorAttachments[index] = attachment;
    }
    framebuffer.depthTexture = depth;
    framebuffer.stencilTexture = stencil;

    gl.createFramebuffers(1, @ptrCast(&framebuffer.handle));
    for (framebuffer.colorAttachments, 0..) |attachment, i| {
        gl.namedFramebufferTexture(framebuffer.handle, @intCast(gl.COLOR_ATTACHMENT0 + i), attachment.handle, 0);
        drawBuffers[i] = @intCast(gl.COLOR_ATTACHMENT0 + i);
    }
    gl.namedFramebufferDrawBuffers(framebuffer.handle, @intCast(drawBuffers.len), drawBuffers.ptr);
    if (depth != null and stencil != null and depth.?.handle == stencil.?.handle) {
        gl.namedFramebufferTexture(framebuffer.handle, gl.DEPTH_STENCIL_ATTACHMENT, depth.?.handle, 0);
        framebuffer.stencilTexture = depth;
        framebuffer.depthTexture = depth;
    } else if (depth) |d| {
        gl.namedFramebufferTexture(framebuffer.handle, gl.DEPTH_ATTACHMENT, d.handle, 0);
        framebuffer.depthTexture = depth;
    } else if (stencil) |s| {
        gl.namedFramebufferTexture(framebuffer.handle, gl.DEPTH_ATTACHMENT, s.handle, 0);
        framebuffer.stencilTexture = stencil;
    }
    if (name) |label| {
        gl.objectLabel(gl.FRAMEBUFFER, framebuffer.handle, @intCast(label.len), label.ptr);
    }
    return framebuffer;
}

pub fn deinit(self: Framebuffer) void {
    self.allocator.free(self.colorAttachments);
    gl.deleteFramebuffers(1, @ptrCast(&self.handle));
}

pub fn hasTexture(self: Framebuffer, texture: Texture) bool {
    for (self.colorAttachments) |attachment| {
        if (attachment.handle == texture.handle) return true;
    }
    return ((self.depthTexture != null and self.depthTexture.?.handle == texture.handle) or (self.stencilTexture != null and self.stencilTexture.?.handle == texture.handle));
}
