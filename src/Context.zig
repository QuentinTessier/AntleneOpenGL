const std = @import("std");
const gl = @import("gl4_6.zig");
const Caches = @import("Caches.zig");

pub const VertexArrayObject = @import("Resources/VertexArrayObject.zig");
pub const GraphicPipeline = @import("Pipeline/GraphicPipeline.zig");
pub const PipelineHandle = Caches.PipelineHandle;
const PrimitiveTopology = @import("Pipeline/PipelineInformation.zig").PrimitiveTopology;
const ColorComponentFlags = @import("Pipeline/PipelineInformation.zig").ColorComponentFlags;
pub const Texture = @import("Resources/Texture.zig");

pub const Context = @This();

pub const AttachementLoadOp = enum(u32) {
    keep,
    clear,
    dontCare,
};

pub const SwapchainRenderingInformation = struct {
    colorLoadOp: AttachementLoadOp = .keep,
    clearColor: @Vector(4, f32) = .{ 0.0, 0.0, 0.0, 1.0 },

    depthLoadOp: AttachementLoadOp = .keep,
    clearDepthValue: f32 = 0.0,

    stencilLoadOp: AttachementLoadOp = .keep,
    clearStencilValue: u32 = 0,
};

pub const FramebufferRenderingInformation = struct {
    colorLoadOp: []const AttachementLoadOp,
    clearColor: []const @Vector(4, f32),

    depthLoadOp: AttachementLoadOp = .keep,
    clearDepthValue: f32 = 0.0,

    stencilLoadOp: AttachementLoadOp = .keep,
    clearStencilValue: u32 = 0,
};

pub const ElementType = enum(u32) {
    _u16 = gl.UNSIGNED_SHORT,
    _u32 = gl.UNSIGNED_INT,

    pub fn getSize(self: ElementType) usize {
        return switch (self) {
            ._u16 => @sizeOf(u16),
            ._u32 => @sizeOf(u32),
        };
    }
};

allocator: std.mem.Allocator,
caches: Caches = .{},

previousPipeline: Caches.PipelineHandle = .{ .type = .Compute, .id = std.math.maxInt(u15) },
pipelineDebugGroupPushed: bool = false,

currentTopology: PrimitiveTopology = .triangle,
currentVertexArrayObjectHash: u64 = undefined,
currentVertexArrayObject: VertexArrayObject = undefined,
currentElementType: ElementType = ._u16,
lastDepthMask: bool = true,
lastStencilWriteMask: [2]i32 = .{ -1, -1 },
lastColorMask: [8]ColorComponentFlags = undefined,

pub fn init(allocator: std.mem.Allocator) Context {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Context) void {
    self.caches.deinit(self.allocator);
}

pub fn createTexture(_: *Context, info: Texture.TextureCreateInfo) Texture {
    return Texture.init(info);
}

fn glEnableOrDisable(option: gl.GLenum, b: bool) void {
    if (b) {
        gl.enable(option);
    } else {
        gl.disable(option);
    }
}

pub fn renderToSwapchain(_: *Context, info: SwapchainRenderingInformation, pass: anytype) !void {
    const T: type = @TypeOf(pass);
    comptime {
        if (@typeInfo(T) != .Struct or !@hasDecl(T, "execute")) {
            @compileError("RenderToSwapchain(info: SwapchainRenderingInformation, pass: Pass) should have\n\tPass = struct {\n\t\tstates: PipelineOrOtherObjects,\n\t\t..., \n\t\tpub fn execute(pass: struct {}) !void {...}\n\t};");
        }
    }
    switch (info.colorLoadOp) {
        .keep => {},
        .clear => {
            gl.clearNamedFramebufferfv(0, gl.COLOR, 0, @ptrCast(&info.clearColor));
        },
        .dontCare => {
            const value: u32 = gl.COLOR;
            gl.invalidateFramebuffer(0, 1, @ptrCast(&value));
        },
    }
    try @call(.auto, T.execute, .{pass});
}

pub fn bindGraphicPipeline(self: *Context, pipeline: Caches.PipelineHandle) !void {
    std.debug.assert(pipeline.type == .Graphics);

    const current = self.caches.graphicPipelineCache.get(pipeline.toU16()) orelse return error.InvalidPipelineHandle;
    const previous = self.caches.graphicPipelineCache.get(self.previousPipeline.toU16());

    if (self.previousPipeline.type == .Compute or self.previousPipeline.id != pipeline.id) {
        gl.useProgram(current.handle);
    }

    if (self.previousPipeline.toU16() == pipeline.toU16()) return;

    // TODO: Push debug group

    if (previous == null) {
        gl.enable(gl.FRAMEBUFFER_SRGB);
    }

    if (previous == null or current.inputAssemblyState.enableRestart != previous.?.inputAssemblyState.enableRestart) {
        if (current.inputAssemblyState.enableRestart) gl.enable(gl.PRIMITIVE_RESTART_FIXED_INDEX) else gl.disable(gl.PRIMITIVE_RESTART_FIXED_INDEX);
    }
    self.currentTopology = current.inputAssemblyState.topology;

    // TODO: Multisampling state
    if (previous) |previous_pipeline| {
        GraphicPipeline.updateInputAssemblyState(current.inputAssemblyState, previous_pipeline.inputAssemblyState);
        GraphicPipeline.updateRasterizationState(current.rasterizationState, previous_pipeline.rasterizationState);
        GraphicPipeline.updateDepthState(current.depthState, previous_pipeline.depthState, &self.lastDepthMask);
        GraphicPipeline.updateStencilState(current.stencilState, previous_pipeline.stencilState, &self.lastStencilWriteMask);
        GraphicPipeline.updateColorBlendState(current.colorBlendState, previous_pipeline.colorBlendState, &self.lastColorMask);
    } else {
        GraphicPipeline.updateInputAssemblyState(current.inputAssemblyState, null);
        GraphicPipeline.updateRasterizationState(current.rasterizationState, null);
        GraphicPipeline.updateDepthState(current.depthState, null, &self.lastDepthMask);
        GraphicPipeline.updateStencilState(current.stencilState, null, &self.lastStencilWriteMask);
        GraphicPipeline.updateColorBlendState(current.colorBlendState, null, &self.lastColorMask);
    }
    self.currentTopology = current.inputAssemblyState.topology;

    if (current.vaoHash != self.currentVertexArrayObjectHash) {
        const vao = self.caches.vertexArrayObjectCache.get(current.vaoHash) orelse return error.MissingVertexArrayObject;
        gl.bindVertexArray(vao.handle);
        self.currentVertexArrayObjectHash = current.vaoHash;
        self.currentVertexArrayObject = vao;
    }

    self.previousPipeline = pipeline;
}

pub fn bindComputePipeline(self: *Context, pipeline: Caches.PipelineHandle) !void {
    std.debug.assert(pipeline.type == .Compute);

    const current = self.caches.computePipelineCache.get(pipeline.toU16()) orelse return error.InvalidPipelineHandle;
    if (self.previousPipeline.type == .Graphics or self.previousPipeline.id != pipeline.id) {
        gl.useProgram(current.handle);
    }
}

pub fn bindTextureBase(_: *Context, index: u32, texture: Texture, sampler: ?u32) void {
    gl.bindTextureUnit(index, texture.handle);
    if (sampler) |s| {
        gl.bindSampler(index, s);
    }
}

pub fn bindTexture(self: *Context, name: []const u8, texture: Texture) !void {
    const samplers: std.StringHashMap(u32) = switch (self.previousPipeline.type) {
        .Compute => blk: {
            const p = self.caches.computePipelineCache.get(self.previousPipeline.toU16()) orelse {
                std.log.err("The current binded pipeline is invalid or missing", .{});
                return error.InvalidOrMissingGraphicPipeline;
            };
            break :blk p.sampler;
        },
        .Graphics => blk: {
            const p = self.caches.graphicPipelineCache.get(self.previousPipeline.toU16()) orelse {
                std.log.err("The current binded pipeline is invalid or missing", .{});
                return error.InvalidOrMissingGraphicPipeline;
            };
            break :blk p.sampler;
        },
    };
    const binding = samplers.get(name) orelse {
        std.log.err("Failed to find texture binding point named: {s}", .{name});
        return error.NoNamedTextureBinding;
    };
    self.bindTextureBase(binding, texture, null);
}

pub fn bindSampledTexture(self: *Context, name: []const u8, texture: Texture, sampler: u64) !void {
    const samplers: std.StringHashMap(u32) = switch (self.previousPipeline.type) {
        .Compute => blk: {
            const p = self.caches.computePipelineCache.get(self.previousPipeline.toU16()) orelse {
                std.log.err("The current binded pipeline is invalid or missing", .{});
                return error.InvalidOrMissingGraphicPipeline;
            };
            break :blk p.sampler;
        },
        .Graphics => blk: {
            const p = self.caches.graphicPipelineCache.get(self.previousPipeline.toU16()) orelse {
                std.log.err("The current binded pipeline is invalid or missing", .{});
                return error.InvalidOrMissingGraphicPipeline;
            };
            break :blk p.sampler;
        },
    };
    const binding = samplers.get(name) orelse {
        std.log.err("Failed to find texture binding point named: {s}", .{name});
        return error.NoNamedTextureBinding;
    };
    const s = self.caches.samplerObjectCache.get(sampler) orelse return error.MissingSampler;
    self.bindTextureBase(binding, texture, s.handle);
}
