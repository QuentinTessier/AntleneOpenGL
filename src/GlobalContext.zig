const std = @import("std");
pub const gl = @import("gl4_6.zig");
const Context = @import("Context.zig");

const DebugMessenger = @import("./Debug/Messenger.zig");
const DebugGroup = @import("./Debug/Group.zig");

pub const glFunctionPointer = gl.FunctionPointer;
pub const Texture = Context.Texture;
pub const Extent = Texture.Extent;
pub const GraphicPipeline = @import("Pipeline/GraphicPipeline.zig");
pub const ComputePipeline = @import("Pipeline/ComputePipeline.zig");
pub const Sampler = @import("Resources/Sampler.zig");
pub const Buffer = @import("Resources/Buffer.zig");
pub const Framebuffer = @import("Resources/Framebuffer.zig");
pub const SparseTextureArray = @import("Resources/SparseArrayTexture.zig");

pub const Tools = @import("Tools/ReflectShaderToStruct.zig");
pub const ReflectionType = @import("Pipeline/ReflectionType.zig");

const PipelineInformation = @import("Pipeline/PipelineInformation.zig");

var __initialized: bool = false;
var __context: Context = undefined;

pub fn init(allocator: std.mem.Allocator, comptime loadFunc: fn (void, [:0]const u8) ?glFunctionPointer) !void {
    if (!__initialized) {
        try gl.load(void{}, loadFunc);
        gl.enable(gl.DEBUG_OUTPUT);
        gl.debugMessageCallback(DebugMessenger.callback, null);

        __context = Context.init(allocator);
        __initialized = true;
    }
}

pub fn deinit() void {
    __context.deinit();
    __initialized = false;
}

pub const Resources = struct {
    pub fn CreateGraphicPipeline(info: PipelineInformation.GraphicPipelineInformation) !Context.GraphicPipeline {
        return __context.caches.createGraphicPipeline(__context.allocator, info);
    }

    pub fn CreateTexture(info: Texture.TextureCreateInfo) Texture {
        return __context.createTexture(info);
    }

    pub fn CreateSparseArrayTexture(size: usize) !SparseTextureArray {
        return SparseTextureArray.init(__context.allocator, size);
    }

    pub fn CreateSampler(state: Sampler.SamplerState) Sampler {
        return Sampler.init(state);
    }

    pub fn CreateBuffer(name: ?[]const u8, data: ?[]const u8, flags: Buffer.BufferStorageFlags) Buffer {
        return Buffer.init(name, data, flags);
    }

    pub inline fn CreateTypedBuffer(name: ?[]const u8, comptime T: type, data: ?[]const T, flags: Buffer.BufferStorageFlags) Buffer {
        return Buffer.typedInit(name, T, data, flags);
    }

    pub inline fn CreateFramebuffer(name: ?[]const u8, info: Framebuffer.FramebufferCreateInfo) !Framebuffer {
        return __context.createFramebuffer(name, info);
    }
};

pub const Rendering = struct {
    pub fn toSwapchain(info: Context.SwapchainRenderingInformation, pass: anytype) !void {
        try __context.renderToSwapchain(info, pass);
    }

    pub fn toFramebuffer(info: Context.FramebufferRenderingInformation, pass: anytype) !void {
        try __context.renderToFramebuffer(info, pass);
    }

    const Offset = struct {
        x: i32 = 0,
        y: i32 = 0,
        z: i32 = 0,
    };

    const BlitMask = struct {
        color: bool = true,
        depth: bool = false,
        stencil: bool = false,
    };

    const BlitFilter = enum(u32) {
        nearest = gl.NEAREST,
        linear = gl.LINEAR,
    };

    pub fn BlitFramebufferToSwapchain(framebuffer: Framebuffer, sourceOffset: Offset, targetOffset: Offset, sourceExtent: Extent(i32), targetExtent: Extent(i32), mask: BlitMask, filter: BlitFilter) void {
        var m: u32 = 0;
        m |= if (mask.color) gl.COLOR_BUFFER_BIT else 0;
        m |= if (mask.depth) gl.DEPTH_BUFFER_BIT else 0;
        m |= if (mask.stencil) gl.STENCIL_BUFFER_BIT else 0;

        gl.blitNamedFramebuffer(
            framebuffer.handle,
            0,
            sourceOffset.x,
            sourceOffset.y,
            sourceExtent.width,
            sourceExtent.height,
            targetOffset.x,
            targetOffset.y,
            targetExtent.width,
            targetExtent.height,
            m,
            @intFromEnum(filter),
        );
    }
};

pub const Commands = struct {
    pub fn BindGraphicPipeline(pipeline: Context.GraphicPipeline) void {
        __context.bindGraphicPipeline(pipeline);
    }

    pub fn BindComputePipeline(pipeline: Context.ComputePipeline) void {
        __context.bindComputePipeline(pipeline);
    }

    pub fn BindTexture(name: []const u8, texture: Texture) !void {
        try __context.bindTexture(name, texture);
    }

    pub fn BindSampledTexture(name: []const u8, texture: Texture, sampler: u64) !void {
        try __context.bindSampledTexture(name, texture, sampler);
    }

    pub fn BindReflectedSampledTexture(comptime ReflectedProgram: type, comptime tag: anytype, texture: Texture, sampler: u64) !void {
        const name = @tagName(tag);
        if (!@hasDecl(ReflectedProgram, name)) @panic("Trying to bind SampledTexture to reflected shader " ++ @typeName(ReflectedProgram) ++ ", " ++ name ++ " isn't defined.");

        const sampler_object = try __context.getSampler(sampler);
        try __context.bindSampledTextureBase(@field(ReflectedProgram, name), texture, sampler_object.handle);
    }

    pub fn BindReflectedTexture(comptime ReflectedProgram: type, comptime tag: anytype, texture: Texture) !void {
        const name = @tagName(tag);
        if (!@hasDecl(ReflectedProgram, name)) @panic("Trying to bind SampledTexture to reflected shader " ++ @typeName(ReflectedProgram) ++ ", " ++ name ++ " isn't defined.");

        try __context.bindTextureBase(@field(ReflectedProgram, name), texture);
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
            __context.bondVertexArrayObject.handle,
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
            __context.bondVertexArrayObject.handle,
            binding,
            @intCast(buffers.len),
            (&buffers_handles).ptr,
            offsets.ptr,
            strides.ptr,
        );
    }

    pub fn BindIndexBuffer(buffer: Buffer, element_type: Context.ElementType) void {
        gl.vertexArrayElementBuffer(__context.bondVertexArrayObject.handle, buffer.handle);
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

    pub fn Dispatch(x: u32, y: u32, z: u32) void {
        gl.dispatchCompute(x, y, z);
    }

    pub fn DispatchIndirect(commands: Buffer, commandOffset: usize) void {
        gl.bindBuffer(gl.DISPATCH_INDIRECT_BUFFER, commands.handle);
        gl.dispatchComputeIndirect(@intCast(commandOffset));
    }
};
