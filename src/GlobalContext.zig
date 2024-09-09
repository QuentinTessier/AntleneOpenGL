const std = @import("std");
pub const gl = @import("gl4_6.zig");
const Context = @import("Context.zig");

const DebugMessenger = @import("./Debug/Messenger.zig");
pub const DebugGroup = @import("./Debug/Group.zig");
const MB = @import("./Resources/MemoryBarrier.zig");

pub const glFunctionPointer = gl.FunctionPointer;
pub const Texture = Context.Texture;
pub const Extent = Texture.Extent;
pub const GraphicPipeline = @import("Pipeline/GraphicPipeline.zig");
pub const TypedGraphicPipeline = @import("Pipeline/TypedGraphicPipeline.zig").TypedGraphicPipeline;
pub const ComputePipeline = @import("Pipeline/ComputePipeline.zig");
pub const Sampler = @import("Resources/Sampler.zig");

pub const Buffer = @import("Resources/Buffer.zig");
pub const MappedBuffer = @import("Resources/MappedBuffer.zig");
pub const DynamicBuffer = @import("Resources/DynamicBuffer.zig");
pub const StaticBuffer = @import("Resources/StaticBuffer.zig");

pub const Framebuffer = @import("Resources/Framebuffer.zig");
pub const Shader = @import("Resources/Shader.zig");
pub const SparseTextureArray = @import("Resources/SparseArrayTexture.zig");

pub const Tools = @import("Tools/ReflectShaderToStruct.zig");
pub const ReflectionType = @import("Pipeline/ReflectionType.zig");

pub const ElementType = Context.ElementType;

const PipelineInformation = @import("Pipeline/PipelineInformation.zig");

var __initialized: bool = false;
var __context: Context = undefined;
var __glLib: std.DynLib = undefined;

fn checkExtensionSupport() bool {
    var n: i32 = 0;
    gl.getIntegerv(gl.NUM_EXTENSIONS, @ptrCast(&n));

    var found: bool = false;
    for (0..@intCast(n)) |index| {
        const ext = gl.getStringi(gl.EXTENSIONS, @intCast(index));
        if (ext) |name| {
            const len = std.mem.len(name);
            if (std.mem.startsWith(u8, name[0..len], "GL_ARB_bindless_texture")) {
                found = true;
                break;
            }
        }
    }
    return found;
}

const InternalLoadContext = struct {
    lib: *std.DynLib,
    loadFunc: *const fn (void, [:0]const u8) ?glFunctionPointer,
};

fn internalLoadFunc(ctx: InternalLoadContext, name: [:0]const u8) ?glFunctionPointer {
    const wglPtr = ctx.loadFunc(void{}, name);
    if (wglPtr) |ptr| {
        return ptr;
    } else {
        return ctx.lib.lookup(glFunctionPointer, name);
    }
}

pub fn init(allocator: std.mem.Allocator, comptime loadFunc: fn (void, [:0]const u8) ?glFunctionPointer) !void {
    if (!__initialized) {
        __glLib = try std.DynLib.open("opengl32.dll");

        try gl.load(InternalLoadContext{ .lib = &__glLib, .loadFunc = &loadFunc }, internalLoadFunc);

        try gl.GL_ARB_bindless_texture.load(InternalLoadContext{ .lib = &__glLib, .loadFunc = &loadFunc }, internalLoadFunc);

        gl.enable(gl.DEBUG_OUTPUT);
        gl.debugMessageCallback(DebugMessenger.callback, null);

        __context = Context.init(allocator);
        __initialized = true;
    }
}

pub fn deinit() void {
    __context.deinit();
    __initialized = false;
    __glLib.close();
}

pub fn resizeFramebuffer(width: i32, height: i32) void {
    __context.swapchainSize = .{ width, height };
}

pub const Resources = struct {
    pub fn CreateGraphicPipeline(info: PipelineInformation.GraphicPipelineInformation) !Context.GraphicPipeline {
        return __context.caches.createGraphicPipeline(__context.allocator, info);
    }

    pub fn CreateTypedGraphicPipeline(comptime Reflection: type, info: PipelineInformation.TypedGraphicPipelineInformation) !TypedGraphicPipeline(Reflection) {
        return __context.caches.createTypedGraphicPipeline(Reflection, __context.allocator, info);
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

    pub fn CreateMappedBuffer(name: ?[]const u8, comptime T: type, data: union(enum) { size: usize, ptr: []const T }, flags: MappedBuffer.Flags) !MappedBuffer {
        return switch (data) {
            .size => |size| MappedBuffer.initEmpty(name, T, size, flags),
            .ptr => |ptr| MappedBuffer.init(name, T, ptr, flags),
        };
    }

    pub fn CreateDynamicBuffer(name: ?[]const u8, data: union(enum) { size: usize, ptr: []const u8 }, stride: usize) DynamicBuffer {
        return switch (data) {
            .size => |size| DynamicBuffer.initEmpty(name, size, stride),
            .ptr => |ptr| DynamicBuffer.init(name, ptr, stride),
        };
    }

    pub fn CreateStaticBuffer(name: ?[]const u8, data: []const u8, stride: usize) StaticBuffer {
        return StaticBuffer.init(name, data, stride);
    }

    pub inline fn CreateFramebuffer(name: ?[]const u8, info: Framebuffer.FramebufferCreateInfo) !Framebuffer {
        return __context.createFramebuffer(name, info);
    }

    pub const DrawElementsIndirectCommand = extern struct {
        count: u32,
        instanceCount: u32,
        firstIndex: u32,
        baseVertex: i32,
        baseInstance: u32,
    };

    pub const HostMemory = struct {
        // [len]DrawElementsIndirectCommand + [1]u32{ __drawCount }
        pub const DrawElementsIndirectCommandList = extern struct {
            data: []u8,

            pub fn getCount(self: *DrawElementsIndirectCommandList) usize {
                return @divExact(self.data.len - 4, @sizeOf(DrawElementsIndirectCommand));
            }

            pub fn getCommands(self: *DrawElementsIndirectCommandList) []DrawElementsIndirectCommand {
                const len = self.getCount();
                return std.mem.bytesAsSlice(DrawElementsIndirectCommand, self.data[0 .. len - 4]);
            }

            pub fn getOffsetToDrawCount(self: *const DrawElementsIndirectCommand) usize {
                const len = self.getCount();
                const offset = @sizeOf(DrawElementsIndirectCommand) * len;
                const drawCount: u32 = std.mem.bytesToValue(u32, self.data[offset..]);

                return @intCast(drawCount);
            }
        };

        // Doesn't have to be managed since memory is HostMemory and user should be able to keep track of it's command buffers
        pub fn CreateDrawElementsIndirectCommandList(allocator: std.mem.Allocator, count: u32) !DrawElementsIndirectCommandList {
            const memory = try allocator.alloc(u8, @sizeOf(DrawElementsIndirectCommand) * @as(usize, @intCast(count)) + @sizeOf(u32));
            @memset(memory, 0);

            const start = @sizeOf(DrawElementsIndirectCommand) * count;
            const drawCount: *u32 = std.mem.bytesAsValue(u32, memory[start .. start + 4]);
            drawCount.* = count;
            return .{
                .data = memory,
            };
        }
    };
};

pub const Rendering = struct {
    pub fn toSwapchain(info: Context.SwapchainRenderingInformation, pass: anytype, extraArgs: anytype) !void {
        try __context.renderToSwapchain(info, pass, extraArgs);
    }

    pub fn toFramebuffer(info: Context.FramebufferRenderingInformation, pass: anytype, extraArgs: anytype) !void {
        try __context.renderToFramebuffer(info, pass, extraArgs);
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

    pub fn BindTypedGraphicPipeline(pipeline: anytype) void {
        __context.bindGraphicPipeline(pipeline.toGraphicPipeline());
    }

    pub fn BindNamedTexture(name: []const u8, texture: Texture) !void {
        try __context.bindTexture(name, texture);
    }

    pub fn BindTexture(location: u32, texture: Texture) void {
        __context.bindTextureBase(location, texture);
    }

    pub fn BindNamedSampledTexture(name: []const u8, texture: Texture, sampler: u64) !void {
        try __context.bindSampledTexture(name, texture, sampler);
    }

    pub fn BindSampledTexture(location: u32, texture: Texture, sampler: Sampler) void {
        __context.bindSampledTextureBase(location, texture, sampler);
    }

    pub const BufferBindingType = enum {
        whole,
        range,
    };

    pub const BufferRange = struct {
        offset: u32 = 0,
        size: u32 = 0,
    };

    pub const BufferBindingInfo = union(enum) {
        _whole: void,
        _range: BufferRange,

        pub fn whole() BufferBindingInfo {
            return .{ ._whole = void{} };
        }

        pub fn range(offset: u32, size: u32) BufferBindingInfo {
            return .{ ._range = .{ .offset = offset, .size = size } };
        }
    };

    pub fn BindStorageBuffer(binding: u32, buffer: Buffer, info: BufferBindingInfo) void {
        switch (info) {
            ._whole => gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, binding, buffer.handle),
            ._range => |range| gl.bindBufferRange(gl.SHADER_STORAGE_BUFFER, binding, buffer.handle, @intCast(range.offset), @intCast(range.size)),
        }
    }

    pub fn BindUniformBuffer(binding: u32, buffer: Buffer, info: BufferBindingInfo) void {
        switch (info) {
            ._whole => gl.bindBufferBase(gl.UNIFORM_BUFFER, binding, buffer.handle),
            ._range => |range| gl.bindBufferRange(gl.UNIFORM_BUFFER, binding, buffer.handle, @intCast(range.offset), @intCast(range.size)),
        }
    }

    pub fn BindVertexBuffer(binding: u32, buffer: Buffer, offset: usize, stride: ?i32) void {
        gl.vertexArrayVertexBuffer(
            __context.bondVertexArrayObject.handle,
            binding,
            buffer.handle,
            @intCast(offset),
            if (stride) |s| s else @as(i32, @intCast(buffer.stride)),
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

    pub fn DrawElements(count: u32, instanceCount: u32, firstIndex: u32, baseVertex: i32, baseInstance: u32) void {
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

    // pub fn DrawIndirectCount(commands: Buffer, commandOffset: usize, count: Buffer, countOffset: usize, commandCount: usize, commandStride: usize) void {
    //     gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, commands.handle);
    //     gl.bindBuffer(gl.PARAMETER_BUFFER, count.handle);
    //     gl.multiDrawArraysIndirectCount(
    //         @intFromEnum(__context.currentTopology),
    //         @ptrFromInt(commandOffset * commandStride),
    //         @intCast(countOffset),
    //         @intCast(commandCount),
    //         @intCast(commandStride),
    //     );
    // }

    pub fn MultiDrawElementsIndirectCountHostMemory(commands: Resources.HostMemory.DrawElementsIndirectCommandList, maxDrawCount: usize) void {
        gl.multiDrawElementsIndirectCount(
            @intFromEnum(__context.currentTopology),
            @intFromEnum(__context.currentElementType),
            commands.data.ptr,
            @intCast(commands.getOffsetToDrawCount()),
            @intCast(maxDrawCount),
            0,
        );
    }

    pub fn MultiDrawElementsIndirectCountHostMemory2(commands: []const Resources.DrawElementsIndirectCommand, maxDrawCount: usize) void {
        gl.multiDrawElementsIndirectCount(
            @intFromEnum(__context.currentTopology),
            @intFromEnum(__context.currentElementType),
            commands.data.ptr,
            @intCast(commands.len),
            @intCast(maxDrawCount),
            0,
        );
    }

    pub fn DrawElementsIndirect(commands: Buffer, commandOffset: usize, commandCount: usize, commandStride: usize) void {
        gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, commands.handle);
        gl.multiDrawElementsIndirect(
            @intFromEnum(__context.currentTopology),
            @intFromEnum(__context.currentElementType),
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

    pub fn TextureBarrier() void {
        return @import("./Resources/TextureBarrier.zig").TextureBarrier();
    }

    pub fn MemoryBarrier(flags: MB.Flags) void {
        return MB.MemoryBarrier(flags);
    }
};
