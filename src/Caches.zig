const std = @import("std");
const gl = @import("gl4_6.zig");

pub const ComputePipeline = @import("./Pipeline/ComputePipeline.zig");
pub const GraphicPipeline = @import("./Pipeline/GraphicPipeline.zig");
pub const TypedGraphicPipeline = @import("./Pipeline/TypedGraphicPipeline.zig").TypedGraphicPipeline;
const PipelineInformation = @import("./Pipeline/PipelineInformation.zig");

pub const Buffer = @import("Resources/Buffer.zig");
pub const SamplerObject = @import("Resources/Sampler.zig");
pub const Texture = @import("Resources/Texture.zig");
pub const VertexArrayObject = @import("Resources/VertexArrayObject.zig");
pub const Framebuffer = @import("Resources/Framebuffer.zig");

const Sampler = @import("./Resources/Sampler.zig");

pub const Caches = @This();

pub const PipelineType = enum(u8) {
    Graphics,
    Compute,
};

vertexArrayObjectCache: std.AutoHashMapUnmanaged(u64, VertexArrayObject) = .{},

pub fn init() Caches {
    return .{};
}

pub fn deinit(self: *Caches, allocator: std.mem.Allocator) void {
    {
        var ite = self.vertexArrayObjectCache.iterator();
        while (ite.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.vertexArrayObjectCache.deinit(allocator);
    }
}

pub fn createGraphicPipeline(self: *Caches, allocator: std.mem.Allocator, info: PipelineInformation.GraphicPipelineInformation) !GraphicPipeline {
    const vao_hash = VertexArrayObject.hash(info.vertexInputState);
    const vao_entry = try self.vertexArrayObjectCache.getOrPut(allocator, vao_hash);
    if (!vao_entry.found_existing) {
        vao_entry.value_ptr.* = VertexArrayObject.init(info.vertexInputState);
    }
    return GraphicPipeline.init(allocator, info, vao_entry.value_ptr.*);
}

pub fn createTypedGraphicPipeline(self: *Caches, comptime Reflection: type, allocator: std.mem.Allocator, info: PipelineInformation.TypedGraphicPipelineInformation) !TypedGraphicPipeline(Reflection) {
    const vertexInputState = comptime PipelineInformation.PipelineVertexInputState.fromReflected(Reflection);
    const vao_hash = VertexArrayObject.hash(vertexInputState);
    const vao_entry = try self.vertexArrayObjectCache.getOrPut(allocator, vao_hash);
    if (!vao_entry.found_existing) {
        vao_entry.value_ptr.* = VertexArrayObject.init(vertexInputState);
    }
    return TypedGraphicPipeline(Reflection).init(allocator, info, vertexInputState, vao_entry.value_ptr.*);
}

pub fn createComputePipeline(_: *Caches, _: std.mem.Allocator, info: PipelineInformation.ComputePipelineInformation) !ComputePipeline {
    return ComputePipeline.init(info);
}
