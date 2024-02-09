const std = @import("std");
const gl = @import("gl4_6.zig");
const Context = @import("Context.zig");

pub const PipelineHandle = Context.PipelineHandle;
pub const Texture = Context.Texture;
pub const Sampler = @import("Resources/Sampler.zig");
pub const Buffer = @import("Resources/Buffer.zig");

const PipelineInformation = @import("Pipeline/PipelineInformation.zig");

var __initialized: bool = false;
var __context: Context = undefined;

fn messageCallback(source: gl.GLenum, _type: gl.GLenum, id: gl.GLuint, severity: gl.GLenum, length: gl.GLsizei, message: [*:0]const u8, _: ?*anyopaque) callconv(.C) void {
    std.log.info("{} {} {} {} {} : {s}", .{ source, _type, id, severity, length, message });
}

pub fn init(allocator: std.mem.Allocator, loadFunc: *const fn (void, [:0]const u8) ?gl.FunctionPointer) !void {
    if (!__initialized) {
        try gl.load(void{}, loadFunc);
        gl.enable(gl.DEBUG_OUTPUT);
        gl.debugMessageCallback(messageCallback, null);

        __context = Context.init(allocator);
        __initialized = true;
    }
}

pub fn deinit() void {
    __context.deinit();
    __initialized = false;
}

pub const Resources = struct {
    pub fn CreateGraphicPipeline(info: PipelineInformation.GraphicPipelineInformation) !PipelineHandle {
        const p = try __context.caches.createGraphicPipeline(__context.allocator, info);
        return p;
    }

    pub fn CreateTexture(info: Texture.TextureCreateInfo) Texture {
        return __context.createTexture(info);
    }

    pub fn CreateSampler(state: Sampler.SamplerState) !u64 {
        const s = try __context.caches.createSampler(__context.allocator, state);
        return s;
    }

    pub fn CreateBuffer(name: ?[]const u8, data: ?[]const u8, flags: Buffer.BufferStorageFlags) Buffer {
        return Buffer.init(name, data, flags);
    }
};

pub const Rendering = struct {
    pub fn toSwapchain(info: Context.SwapchainRenderingInformation, pass: anytype) !void {
        try __context.renderToSwapchain(info, pass);
    }
};

pub const Commands = struct {
    pub fn BindGraphicPipeline(handle: PipelineHandle) !void {
        try __context.bindGraphicPipeline(handle);
    }

    pub fn BindTexture(name: []const u8, texture: Texture) !void {
        try __context.bindTexture(name, texture);
    }

    pub fn BindSampledTexture(name: []const u8, texture: Texture, sampler: u64) !void {
        try __context.bindSampledTexture(name, texture, sampler);
    }

    pub const BufferBindingInformation = union(enum(u32)) {
        whole: void,
        range: struct {
            offset: usize,
            size: usize,
        },
    };

    pub fn BindStorageBuffer(binding: u32, buffer: Buffer, info: BufferBindingInformation) void {
        switch (info) {
            .whole => gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, binding, buffer.handle),
            .range => |range| gl.bindBufferRange(gl.SHADER_STORAGE_BUFFER, binding, buffer.handle, @intCast(range.offset), @intCast(range.size)),
        }
    }

    pub fn BindUniformBuffer(binding: u32, buffer: Buffer, info: BufferBindingInformation) void {
        switch (info) {
            .whole => gl.bindBufferBase(gl.UNIFORM_BUFFER, binding, buffer.handle),
            .range => |range| gl.bindBufferRange(gl.UNIFORM_BUFFER, binding, buffer.handle, @intCast(range.offset), @intCast(range.size)),
        }
    }

    pub fn BindVertexBuffer(binding: u32, buffer: Buffer, offset: usize, stride: usize) void {
        gl.vertexArrayVertexBuffer(
            __context.currentVertexArrayObject.handle,
            binding,
            buffer.handle,
            @intCast(offset),
            @intCast(stride),
        );
    }

    pub fn BindVertexBuffers(binding: u32, buffers: []const Buffer, offsets: []const i32, strides: []const i32) void {
        var buffers_handles: [8]u32 = [1]u32{0} ** 8;
        std.debug.assert(buffers.len < 8);
        for (buffers, 0..) |b, i| {
            buffers_handles[i] = b.handle;
        }
        gl.vertexArrayVertexBuffers(
            __context.currentVertexArrayObject.handle,
            binding,
            @intCast(buffers.len),
            (&buffers_handles).ptr,
            offsets.ptr,
            strides.ptr,
        );
    }

    pub fn BindIndexBuffer(buffer: Buffer, element_type: Context.ElementType) void {
        gl.vertexArrayElementBuffer(__context.currentVertexArrayObject.handle, buffer.handle);
        __context.currentElementType = element_type;
    }

    pub fn Draw(first: usize, count: usize, instanceCount: usize, baseInstance: usize) void {
        gl.drawArraysInstancedBaseInstance(
            @intFromEnum(__context.currentTopology),
            @intCast(first),
            @intCast(count),
            @intCast(instanceCount),
            @intCast(baseInstance),
        );
    }

    pub fn DrawArrayIndirect(commandBuffer: Buffer, drawCount: usize, stride: usize) void {
        gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, commandBuffer.handle);
        gl.multiDrawArraysIndirect(@intFromEnum(__context.currentTopology), null, @intCast(drawCount), @intCast(stride));
        gl.drawArraysIndirect(@intFromEnum(__context.currentTopology), null);
    }

    pub fn DrawElements(count: usize, instanceCount: usize, firstIndex: usize, baseVertex: usize, baseInstance: usize) void {
        gl.drawElementsInstancedBaseVertexBaseInstance(
            @intFromEnum(__context.currentTopology),
            @intCast(count),
            @intFromEnum(__context.currentElementType),
            @ptrFromInt(firstIndex * __context.currentElementType.getSize()),
            @intCast(instanceCount),
            @intCast(baseVertex),
            @intCast(baseInstance),
        );
    }

    pub fn DrawIndirect(commands: Buffer, commandOffset: usize, commandCount: usize, commandStride: usize) void {
        gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, commands.handle);
        gl.multiDrawArraysIndirect(
            @intFromEnum(__context.currentTopology),
            @ptrFromInt(commandOffset * commandStride),
            @intCast(commandCount),
            @intCast(commandStride),
        );
    }

    //pub fn DrawIndirectCount(commands: Buffer, commandOffset: usize, count: Buffer, countOffset: usize, commandCount: usize, commandStride: usize) void {
    //    gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, commands.handle);
    //    gl.bindBuffer(gl.PARAMETER_BUFFER, count.handle);
    //    gl.multiDrawArraysIndirectCount(
    //        @intFromEnum(__context.currentTopology),
    //        @ptrFromInt(commandOffset * commandStride),
    //        @intCast(countOffset),
    //        @intCast(commandCount),
    //        @intCast(commandStride),
    //    );
    //}

    pub fn DrawElementsIndirect(commands: Buffer, commandOffset: usize, commandCount: usize, commandStride: usize) void {
        gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, commands.handle);
        gl.multiDrawElementsIndirect(
            @intFromEnum(__context.currentTopology),
            @ptrFromInt(commandOffset * commandStride),
            @intCast(commandCount),
            @intCast(commandStride),
        );
    }
};
