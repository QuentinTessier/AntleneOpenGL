const std = @import("std");
const gl = @import("gl4_6.zig");

pub const ComputePipeline = @import("./Pipeline/ComputePipeline.zig");
pub const GraphicPipeline = @import("./Pipeline/GraphicPipeline.zig");
const PipelineInformation = @import("./Pipeline/PipelineInformation.zig");

pub const Buffer = @import("Resources/Buffer.zig");
pub const SamplerObject = @import("Resources/Sampler.zig");
pub const Texture = @import("Resources/Texture.zig");
pub const VertexArrayObject = @import("Resources/VertexArrayObject.zig");

const Sampler = @import("./Resources/Sampler.zig");

pub const Caches = @This();

pub const PipelineType = enum(u1) {
    Graphics,
    Compute,
};

pub const PipelineHandle = packed struct(u16) {
    type: PipelineType,
    id: u15,

    pub fn toU16(self: PipelineHandle) u16 {
        return std.mem.bytesToValue(u16, std.mem.asBytes(&self));
    }
};

pipelineCounter: u15 = 0,
graphicPipelineCache: std.AutoHashMapUnmanaged(u16, GraphicPipeline) = .{},
computePipelineCache: std.AutoHashMapUnmanaged(u16, ComputePipeline) = .{},
vertexArrayObjectCache: std.AutoHashMapUnmanaged(u64, VertexArrayObject) = .{},
samplerObjectCache: std.AutoArrayHashMapUnmanaged(u64, SamplerObject) = .{},

pub fn init() Caches {
    return .{};
}

pub fn deinit(self: *Caches, allocator: std.mem.Allocator) void {
    {
        var ite = self.graphicPipelineCache.iterator();
        while (ite.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        self.graphicPipelineCache.deinit(allocator);
    }
    {
        var ite = self.computePipelineCache.iterator();
        while (ite.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        self.computePipelineCache.deinit(allocator);
    }
    {
        var ite = self.vertexArrayObjectCache.iterator();
        while (ite.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.vertexArrayObjectCache.deinit(allocator);
    }
    {
        var ite = self.samplerObjectCache.iterator();
        while (ite.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.samplerObjectCache.deinit(allocator);
    }
}

pub fn createGraphicPipeline(self: *Caches, allocator: std.mem.Allocator, info: PipelineInformation.GraphicPipelineInformation) !PipelineHandle {
    const id = PipelineHandle{
        .type = .Graphics,
        .id = self.pipelineCounter,
    };

    const entry = try self.graphicPipelineCache.getOrPut(allocator, id.toU16());
    if (!entry.found_existing) {
        std.log.info("Creating new graphics pipeline with id: {}", .{id});
        var pipeline = try GraphicPipeline.init(allocator, info);

        const vao_hash = VertexArrayObject.hash(info.vertexInputState);
        const vao_entry = try self.vertexArrayObjectCache.getOrPut(allocator, vao_hash);
        if (!vao_entry.found_existing) {
            vao_entry.value_ptr.* = VertexArrayObject.init(info.vertexInputState);
        }
        pipeline.vaoHash = vao_hash;
        self.pipelineCounter += 1;
        entry.value_ptr.* = pipeline;
    }

    return id;
}

pub fn createComputePipeline(self: *Caches, allocator: std.mem.Allocator, info: PipelineInformation.ComputePipelineInformation) !PipelineHandle {
    const id = PipelineHandle{
        .type = .Compute,
        .id = self.pipelineCounter,
    };

    const entry = try self.computePipelineCache.getOrPut(allocator, id);
    if (!entry.found_existing) {
        std.log.info("Creating new compute shader with id: {}", .{id});
        const pipeline = ComputePipeline.init(info);
        self.pipelineCounter += 1;
        entry.value_ptr.* = pipeline;
    }
    return id;
}

pub fn createSampler(self: *Caches, allocator: std.mem.Allocator, state: Sampler.SamplerState) !u64 {
    //const sampler = Sampler.init(state);
    const id = Sampler.hash(state);

    const entry = try self.samplerObjectCache.getOrPut(allocator, id);
    if (!entry.found_existing) {
        entry.value_ptr.* = Sampler.init(state);
    }

    return id;
}
