const std = @import("std");
const gl = @import("gl4_6.zig");
const Caches = @import("Caches.zig");

pub const VertexArrayObject = @import("Resources/VertexArrayObject.zig");
pub const GraphicPipeline = @import("Pipeline/GraphicPipeline.zig");
pub const ComputePipeline = @import("Pipeline/ComputePipeline.zig");
const PrimitiveTopology = @import("Pipeline/PipelineInformation.zig").PrimitiveTopology;
const ColorComponentFlags = @import("Pipeline/PipelineInformation.zig").ColorComponentFlags;
pub const Texture = @import("Resources/Texture.zig");

pub const Context = @This();

pub const AttachementLoadOp = enum(u32) {
    keep,
    clear,
    dontCare,
};

pub const DepthRange = enum(u32) {
    NegativeOneToOne = gl.NEGATIVE_ONE_TO_ONE,
    ZeroToOne = gl.ZERO_TO_ONE,
};

pub const Viewport = struct {
    extent: struct {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    },
    minDepth: f32 = 0.0,
    maxDepth: f32 = 1.0,
    depthRange: DepthRange = .NegativeOneToOne,
};

pub const SwapchainRenderingInformation = struct {
    colorLoadOp: AttachementLoadOp = .keep,
    clearColor: @Vector(4, f32) = .{ 0.0, 0.0, 0.0, 1.0 },
    depthLoadOp: AttachementLoadOp = .keep,
    clearDepthValue: f32 = 0.0,
    stencilLoadOp: AttachementLoadOp = .keep,
    clearStencilValue: u32 = 0,
    viewport: Viewport,
};

pub const ColorAttachment = struct {
    texture: Texture,
    colorLoadOp: AttachementLoadOp = .keep,
    clearColor: @Vector(4, f32) = .{ 0.0, 0.0, 0.0, 1.0 },
};

pub const FramebufferRenderingInformation = struct {
    colorAttachments: []const ColorAttachment,

    depthLoadOp: AttachementLoadOp = .keep,
    clearDepthValue: f32 = 0.0,

    stencilLoadOp: AttachementLoadOp = .keep,
    clearStencilValue: u32 = 0,
};

pub const ElementType = enum(u32) {
    u16 = gl.UNSIGNED_SHORT,
    u32 = gl.UNSIGNED_INT,

    pub fn getSize(self: ElementType) usize {
        return switch (self) {
            .u16 => @sizeOf(u16),
            .u32 => @sizeOf(u32),
        };
    }
};

const PipelineType = enum {
    Compute,
    Graphics,
};

const Pipeline = union(PipelineType) {
    Compute: ComputePipeline,
    Graphics: GraphicPipeline,
};

allocator: std.mem.Allocator,
caches: Caches = .{},

previousPipeline: ?Pipeline = null,
pipelineDebugGroupPushed: bool = false,

currentTopology: PrimitiveTopology = .triangle,
bondVertexArrayObject: VertexArrayObject = undefined,
currentElementType: ElementType = .u16,
lastDepthMask: bool = true,
lastStencilWriteMask: [2]i32 = .{ -1, -1 },
lastColorMask: [8]ColorComponentFlags = undefined,

previousViewport: ?Viewport = null,

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

pub fn renderToSwapchain(self: *Context, info: SwapchainRenderingInformation, pass: anytype) !void {
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
    switch (info.depthLoadOp) {
        .keep => {},
        .clear => {
            gl.clearNamedFramebufferfv(0, gl.DEPTH, 0, @ptrCast(&info.clearColor));
        },
        .dontCare => {
            const value: u32 = gl.DEPTH;
            gl.invalidateFramebuffer(0, 1, @ptrCast(&value));
        },
    }

    self.updateViewport(info.viewport);

    try @call(.auto, T.execute, .{pass});
}

pub fn bindGraphicPipeline(self: *Context, pipeline: GraphicPipeline) void {
    if (self.previousPipeline) |previousPipeline| {
        switch (previousPipeline) {
            .Compute => {
                gl.useProgram(pipeline.handle);

                GraphicPipeline.updateInputAssemblyState(pipeline.inputAssemblyState, null);
                GraphicPipeline.updateRasterizationState(pipeline.rasterizationState, null);
                GraphicPipeline.updateDepthState(pipeline.depthState, null, &self.lastDepthMask);
                GraphicPipeline.updateStencilState(pipeline.stencilState, null, &self.lastStencilWriteMask);
                GraphicPipeline.updateColorBlendState(pipeline.colorBlendState, null, &self.lastColorMask);
                self.currentTopology = pipeline.inputAssemblyState.topology;
                if (self.bondVertexArrayObject.hash != pipeline.vao.hash) {
                    gl.bindVertexArray(pipeline.vao.handle);
                    self.bondVertexArrayObject = pipeline.vao;
                }
            },
            .Graphics => |previous| {
                if (pipeline.hash == previous.hash) {
                    return;
                } else {
                    gl.useProgram(pipeline.handle);
                }
                GraphicPipeline.updateInputAssemblyState(pipeline.inputAssemblyState, previous.inputAssemblyState);
                GraphicPipeline.updateRasterizationState(pipeline.rasterizationState, previous.rasterizationState);
                GraphicPipeline.updateDepthState(pipeline.depthState, previous.depthState, &self.lastDepthMask);
                GraphicPipeline.updateStencilState(pipeline.stencilState, previous.stencilState, &self.lastStencilWriteMask);
                GraphicPipeline.updateColorBlendState(pipeline.colorBlendState, previous.colorBlendState, &self.lastColorMask);
                self.currentTopology = pipeline.inputAssemblyState.topology;
                if (self.bondVertexArrayObject.hash != pipeline.vao.hash) {
                    gl.bindVertexArray(pipeline.vao.handle);
                    self.bondVertexArrayObject = pipeline.vao;
                }
            },
        }
    } else {
        gl.useProgram(pipeline.handle);
        gl.enable(gl.FRAMEBUFFER_SRGB);
        GraphicPipeline.updateInputAssemblyState(pipeline.inputAssemblyState, null);
        GraphicPipeline.updateRasterizationState(pipeline.rasterizationState, null);
        GraphicPipeline.updateDepthState(pipeline.depthState, null, &self.lastDepthMask);
        GraphicPipeline.updateStencilState(pipeline.stencilState, null, &self.lastStencilWriteMask);
        GraphicPipeline.updateColorBlendState(pipeline.colorBlendState, null, &self.lastColorMask);
        self.currentTopology = pipeline.inputAssemblyState.topology;
        gl.bindVertexArray(pipeline.vao.handle);
        self.bondVertexArrayObject = pipeline.vao;
    }
    self.previousPipeline = .{ .Graphics = pipeline };
}

pub fn bindComputePipeline(self: *Context, pipeline: ComputePipeline) void {
    if (self.previousPipeline) |previousPipeline| {
        switch (previousPipeline) {
            .Compute => |previous| {
                if (pipeline.hash == previous.hash) {
                    return;
                } else {
                    gl.useProgram(pipeline.handle);
                }
            },
            .Graphics => gl.useProgram(pipeline.handle),
        }
    } else {
        gl.useProgram(pipeline.handle);
    }
    self.previousPipeline = .{ .Compute = pipeline };
}

pub fn bindTextureBase(_: *Context, index: u32, texture: Texture) void {
    gl.bindTextureUnit(index, texture.handle);
}

pub fn bindSampledTextureBase(_: *Context, index: u32, texture: Texture, s: u32) void {
    gl.bindTextureUnit(index, texture.handle);
    gl.bindSampler(index, s);
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
    self.bindTextureBase(binding, texture);
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
    self.bindSampledTextureBase(binding, texture, s.handle);
}

pub fn getSampler(self: *Context, sampler: u64) !Caches.SamplerObject {
    return self.caches.samplerObjectCache.get(sampler) orelse error.MissingSampler;
}

pub fn updateViewport(self: *Context, viewport: Viewport) void {
    if (self.previousViewport) |*previousViewport| {
        if (!std.mem.eql(u8, std.mem.asBytes(&previousViewport.extent), std.mem.asBytes(&viewport.extent))) {
            gl.viewport(
                @intCast(viewport.extent.x),
                @intCast(viewport.extent.y),
                @intCast(viewport.extent.width),
                @intCast(viewport.extent.height),
            );
            self.previousViewport.?.extent = viewport.extent;
        }
        if (previousViewport.maxDepth != viewport.maxDepth or previousViewport.minDepth != viewport.minDepth) {
            gl.depthRangef(viewport.minDepth, viewport.maxDepth);
            previousViewport.maxDepth = viewport.maxDepth;
            previousViewport.minDepth = viewport.minDepth;
        }
        if (previousViewport.depthRange != viewport.depthRange) {
            gl.clipControl(gl.LOWER_LEFT, @intFromEnum(viewport.depthRange));
            previousViewport.depthRange = viewport.depthRange;
        }
    } else {
        gl.viewport(
            @intCast(viewport.extent.x),
            @intCast(viewport.extent.y),
            @intCast(viewport.extent.width),
            @intCast(viewport.extent.height),
        );
        //gl.depthRangef(viewport.minDepth, viewport.maxDepth);
        //gl.clipControl(gl.LOWER_LEFT, @intFromEnum(viewport.depthRange));
        self.previousViewport = viewport;
    }
}
