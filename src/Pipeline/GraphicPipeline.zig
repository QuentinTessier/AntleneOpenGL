const std = @import("std");
const gl = @import("../gl4_6.zig");
const Information = @import("./PipelineInformation.zig");

const VertexArrayObject = @import("../Resources/VertexArrayObject.zig");

pub const GraphicPipelineInformation = Information.GraphicPipelineInformation;

pub const Handle = u32;

pub const GraphicPipeline = @This();

handle: Handle,
hash: u64,
vao: VertexArrayObject,

inputAssemblyState: Information.PipelineInputAssemblyState,
vertexInputState: Information.PipelineVertexInputState,
rasterizationState: Information.PipelineRasterizationState,
multiSampleState: Information.PipelineMultisampleState,
depthState: Information.PipelineDepthState,
stencilState: Information.PipelineStencilState,
colorBlendState: Information.PipelineColorBlendState,

uniformBlocks: std.StringArrayHashMapUnmanaged(Handle) = .{},
shaderStorageBlocks: std.StringArrayHashMapUnmanaged(Handle) = .{},
samplers: std.StringArrayHashMapUnmanaged(Handle) = .{},

// Try to create all pipeline up-front, since we need to alloc to generate the hash.
// We needs a better way to create a repeatable id or something of the sort.
pub inline fn hash(allocator: std.mem.Allocator, info: GraphicPipelineInformation) !u64 {
    const size =
        @sizeOf(Information.PipelineInputAssemblyState) +
        @sizeOf(Information.PipelineRasterizationState) +
        @sizeOf(Information.PipelineMultisampleState) +
        @sizeOf(Information.PipelineDepthState) +
        @sizeOf(Information.PipelineStencilState) +
        @sizeOf(Information.PipelineColorBlendState) +
        @sizeOf(Information.VertexInputAttributeDescription) * info.vertexInputState.vertexAttributeDescription.len +
        info.vertexShaderSource.len() + info.fragmentShaderSource.len();

    const buffer = try allocator.alloc(u8, size);
    defer allocator.free(buffer);
    var offset: usize = 0;

    @memcpy(buffer[0..@sizeOf(Information.PipelineInputAssemblyState)], std.mem.asBytes(&info.inputAssemblyState));
    offset += @sizeOf(Information.PipelineInputAssemblyState);

    @memcpy(buffer[offset .. offset + @sizeOf(Information.VertexInputAttributeDescription) * info.vertexInputState.vertexAttributeDescription.len], std.mem.sliceAsBytes(info.vertexInputState.vertexAttributeDescription));
    offset += @sizeOf(Information.VertexInputAttributeDescription) * info.vertexInputState.vertexAttributeDescription.len;

    @memcpy(buffer[offset .. offset + @sizeOf(Information.PipelineRasterizationState)], std.mem.asBytes(&info.rasterizationState));
    offset += @sizeOf(Information.PipelineRasterizationState);

    @memcpy(buffer[offset .. offset + @sizeOf(Information.PipelineMultisampleState)], std.mem.asBytes(&info.multiSampleState));
    offset += @sizeOf(Information.PipelineMultisampleState);

    @memcpy(buffer[offset .. offset + @sizeOf(Information.PipelineDepthState)], std.mem.asBytes(&info.depthState));
    offset += @sizeOf(Information.PipelineDepthState);

    @memcpy(buffer[offset .. offset + @sizeOf(Information.PipelineStencilState)], std.mem.asBytes(&info.stencilState));
    offset += @sizeOf(Information.PipelineStencilState);

    @memcpy(buffer[offset .. offset + @sizeOf(Information.PipelineColorBlendState)], std.mem.asBytes(&info.colorBlendState));
    offset += @sizeOf(Information.PipelineColorBlendState);

    @memcpy(buffer[offset .. offset + info.vertexShaderSource.len()], info.vertexShaderSource.slice());
    offset += info.vertexShaderSource.len();

    @memcpy(buffer[offset .. offset + info.fragmentShaderSource.len()], info.fragmentShaderSource.slice());
    offset += info.fragmentShaderSource.len();

    return std.hash.Murmur2_64.hash(buffer);
}

pub fn init(allocator: std.mem.Allocator, info: GraphicPipelineInformation, vao: VertexArrayObject) !GraphicPipeline {
    const vertex_shader = try Information.compileShader(gl.VERTEX_SHADER, info.vertexShaderSource);
    errdefer gl.deleteShader(vertex_shader);
    const fragment_shader = try Information.compileShader(gl.FRAGMENT_SHADER, info.fragmentShaderSource);
    errdefer gl.deleteShader(fragment_shader);
    const program = try Information.linkProgram(&.{ vertex_shader, fragment_shader });
    errdefer gl.deleteProgram(program);

    if (std.debug.runtime_safety) {
        if (info.name) |name| {
            gl.objectLabel(gl.PROGRAM, program, @intCast(name.len), name.ptr);
        }
    }

    const h = try hash(allocator, info);
    std.log.info("Created new pipeline with hash {}", .{h});
    return .{
        .handle = program,
        .hash = h,
        .vao = vao,
        .inputAssemblyState = info.inputAssemblyState,
        .vertexInputState = info.vertexInputState,
        .rasterizationState = info.rasterizationState,
        .multiSampleState = info.multiSampleState,
        .depthState = info.depthState,
        .stencilState = info.stencilState,
        .colorBlendState = info.colorBlendState,
        .uniformBlocks = try Information.reflectInterface(allocator, program, gl.UNIFORM_BLOCK),
        .shaderStorageBlocks = try Information.reflectInterface(allocator, program, gl.SHADER_STORAGE_BLOCK),
        .samplers = try Information.reflectInterface(allocator, program, gl.UNIFORM),
    };
}

pub fn deinit(self: *GraphicPipeline, allocator: std.mem.Allocator) void {
    gl.deleteProgram(self.handle);
    for (self.uniformBlocks.keys()) |name| {
        allocator.free(name);
    }
    self.uniformBlocks.deinit(allocator);

    for (self.shaderStorageBlocks.keys()) |name| {
        allocator.free(name);
    }
    self.shaderStorageBlocks.deinit(allocator);

    for (self.samplers.keys()) |name| {
        allocator.free(name);
    }
    self.samplers.deinit(allocator);
}

pub fn buildVertexArrayObject(vertexInputState: Information.PipelineVertexInputState) u32 {
    var vertexArrayObject: u32 = 0;
    gl.createVertexArrays(1, @ptrCast(&vertexArrayObject));

    for (vertexInputState.vertexAttributeDescription) |input| {
        gl.enableVertexArrayAttrib(vertexArrayObject, input.location);
        gl.vertexArrayAttribBinding(vertexArrayObject, input.location, input.binding);
        gl.vertexArrayAttribFormat(vertexArrayObject, input.location, @intCast(input.size), @intFromEnum(input.format), gl.FALSE, input.offset);
    }

    return vertexArrayObject;
}

fn glEnableOrDisable(option: gl.GLenum, b: bool) void {
    if (b) {
        gl.enable(option);
    } else {
        gl.disable(option);
    }
}

pub fn updateInputAssemblyState(self: Information.PipelineInputAssemblyState, other: ?Information.PipelineInputAssemblyState) void {
    if (other) |current_state| {
        if (self.enableRestart != current_state.enableRestart) {
            glEnableOrDisable(gl.PRIMITIVE_RESTART_FIXED_INDEX, self.enableRestart);
        }
    } else {
        glEnableOrDisable(gl.PRIMITIVE_RESTART_FIXED_INDEX, self.enableRestart);
    }
}

pub fn updateRasterizationState(self: Information.PipelineRasterizationState, other: ?Information.PipelineRasterizationState) void {
    if (other) |current_state| {
        if (self.depthClampEnable != current_state.depthClampEnable) {
            glEnableOrDisable(gl.DEPTH_CLAMP, self.depthClampEnable);
        }

        if (self.polygonMode != current_state.polygonMode) {
            gl.polygonMode(gl.FRONT_AND_BACK, @intFromEnum(self.polygonMode));
        }

        if (self.cullMode != current_state.cullMode) {
            glEnableOrDisable(gl.CULL_FACE, self.cullMode != .none);
            if (self.cullMode != .none) {
                gl.cullFace(@intFromEnum(self.cullMode));
            }
        }

        if (self.frontFace != current_state.frontFace) {
            gl.frontFace(@intFromEnum(self.frontFace));
        }

        if (self.depthBiasEnable != current_state.depthBiasEnable) {
            glEnableOrDisable(gl.POLYGON_OFFSET_FILL, self.depthBiasEnable);
            glEnableOrDisable(gl.POLYGON_OFFSET_LINE, self.depthBiasEnable);
            glEnableOrDisable(gl.POLYGON_OFFSET_POINT, self.depthBiasEnable);
        }

        if (self.depthBiasConstantFactor != current_state.depthBiasConstantFactor or self.depthBiasSlopeFactor != current_state.depthBiasSlopeFactor) {
            gl.polygonOffset(self.depthBiasSlopeFactor, self.depthBiasConstantFactor);
        }

        if (self.lineWidth != current_state.lineWidth) {
            gl.lineWidth(self.lineWidth);
        }

        if (self.pointWidth != current_state.pointWidth) {
            gl.pointSize(self.pointWidth);
        }
    } else {
        glEnableOrDisable(gl.DEPTH_CLAMP, self.depthClampEnable);
        gl.polygonMode(gl.FRONT_AND_BACK, @intFromEnum(self.polygonMode));
        glEnableOrDisable(gl.CULL_FACE, self.cullMode != .none);
        if (self.cullMode != .none) {
            gl.cullFace(@intFromEnum(self.cullMode));
        }
        gl.frontFace(@intFromEnum(self.frontFace));
        glEnableOrDisable(gl.POLYGON_OFFSET_FILL, self.depthBiasEnable);
        glEnableOrDisable(gl.POLYGON_OFFSET_LINE, self.depthBiasEnable);
        glEnableOrDisable(gl.POLYGON_OFFSET_POINT, self.depthBiasEnable);
        gl.polygonOffset(self.depthBiasSlopeFactor, self.depthBiasConstantFactor);
        gl.lineWidth(self.lineWidth);
        gl.pointSize(self.pointWidth);
    }
}

pub fn updateDepthState(self: Information.PipelineDepthState, other: ?Information.PipelineDepthState, lastDepthMask: *bool) void {
    if (other) |current_state| {
        if (self.depthTestEnable != current_state.depthTestEnable) {
            glEnableOrDisable(gl.DEPTH_TEST, self.depthTestEnable);
        }

        if (self.depthWriteEnable != current_state.depthWriteEnable) {
            if (self.depthWriteEnable != lastDepthMask.*) {
                gl.depthMask(if (self.depthWriteEnable) gl.TRUE else gl.FALSE);
                lastDepthMask.* = self.depthWriteEnable;
            }
        }

        if (self.depthCompareOp != current_state.depthCompareOp) {
            gl.depthFunc(@intFromEnum(self.depthCompareOp));
        }
    } else {
        glEnableOrDisable(gl.DEPTH_TEST, self.depthTestEnable);
        gl.depthFunc(@intFromEnum(self.depthCompareOp));
        if (self.depthWriteEnable != lastDepthMask.*) {
            gl.depthMask(if (self.depthWriteEnable) gl.TRUE else gl.FALSE);
            lastDepthMask.* = self.depthWriteEnable;
        }
    }
}

pub fn updateStencilState(self: Information.PipelineStencilState, other: ?Information.PipelineStencilState, lastStencilWriteMask: *[2]i32) void {
    if (other) |current_state| {
        if (self.stencilTestEnable != current_state.stencilTestEnable) {
            glEnableOrDisable(gl.STENCIL_TEST, self.stencilTestEnable);
        }

        if (!current_state.stencilTestEnable or self.front.eq(current_state.front)) {
            gl.stencilOpSeparate(
                gl.FRONT,
                @intFromEnum(self.front.stencilFail),
                @intFromEnum(self.front.depthFail),
                @intFromEnum(self.front.stencilPass),
            );
            gl.stencilFuncSeparate(gl.FRONT, @intFromEnum(self.front.compareOp), self.front.reference, self.front.compareMask);
            if (self.front.writeMask != lastStencilWriteMask.*[0]) {
                gl.stencilMaskSeparate(gl.FRONT, @intCast(self.front.writeMask));
                lastStencilWriteMask.*[0] = self.front.writeMask;
            }
        }

        if (!current_state.stencilTestEnable or self.back.eq(current_state.back)) {
            gl.stencilOpSeparate(
                gl.BACK,
                @intFromEnum(self.back.stencilFail),
                @intFromEnum(self.back.depthFail),
                @intFromEnum(self.back.stencilPass),
            );
            gl.stencilFuncSeparate(gl.BACK, @intFromEnum(self.back.compareOp), self.back.reference, self.back.compareMask);
            if (self.back.writeMask != lastStencilWriteMask.*[1]) {
                gl.stencilMaskSeparate(gl.BACK, @intCast(self.back.writeMask));
                lastStencilWriteMask.*[0] = self.back.writeMask;
            }
        }
    } else {
        glEnableOrDisable(gl.STENCIL_TEST, self.stencilTestEnable);

        gl.stencilOpSeparate(
            gl.FRONT,
            @intFromEnum(self.front.stencilFail),
            @intFromEnum(self.front.depthFail),
            @intFromEnum(self.front.stencilPass),
        );
        gl.stencilFuncSeparate(gl.FRONT, @intFromEnum(self.front.compareOp), self.front.reference, self.front.compareMask);
        if (self.front.writeMask != lastStencilWriteMask.*[0]) {
            gl.stencilMaskSeparate(gl.FRONT, @intCast(self.front.writeMask));
            lastStencilWriteMask.*[0] = self.front.writeMask;
        }

        gl.stencilOpSeparate(
            gl.BACK,
            @intFromEnum(self.back.stencilFail),
            @intFromEnum(self.back.depthFail),
            @intFromEnum(self.back.stencilPass),
        );
        gl.stencilFuncSeparate(gl.BACK, @intFromEnum(self.back.compareOp), self.back.reference, self.back.compareMask);
        if (self.back.writeMask != lastStencilWriteMask.*[1]) {
            gl.stencilMaskSeparate(gl.BACK, @intCast(self.back.writeMask));
            lastStencilWriteMask.*[0] = self.back.writeMask;
        }
    }
}

pub fn updateColorBlendState(self: Information.PipelineColorBlendState, other: ?Information.PipelineColorBlendState, lastColorMask: *[8]Information.ColorComponentFlags) void {
    if (other) |current_state| {
        if (self.logicOpEnable != current_state.logicOpEnable) {
            glEnableOrDisable(gl.COLOR_LOGIC_OP, self.logicOpEnable);
            if (!current_state.logicOpEnable or (self.logicOpEnable and self.logicOp != current_state.logicOp)) {
                gl.logicOp(@intFromEnum(self.logicOp));
            }
        }

        if (!std.mem.eql(f32, &self.blendConstants, &current_state.blendConstants)) {
            gl.blendColor(self.blendConstants[0], self.blendConstants[1], self.blendConstants[2], self.blendConstants[3]);
        }

        if ((self.attachments.len == 0) != (current_state.attachments.len == 0)) {
            glEnableOrDisable(gl.BLEND, self.attachments.len != 0);
        }

        for (self.attachments, 0..) |attachment, index| {
            if (index < current_state.attachments.len and attachment.eq(current_state.attachments[index])) {
                continue;
            }

            if (attachment.blendEnable) {
                gl.blendFuncSeparatei(
                    @intCast(index),
                    @intFromEnum(attachment.srcRgbFactor),
                    @intFromEnum(attachment.dstRgbFactor),
                    @intFromEnum(attachment.srcAlphaFactor),
                    @intFromEnum(attachment.dstAlphaFactor),
                );
                gl.blendEquationSeparatei(@intCast(index), @intFromEnum(attachment.colorBlendOp), @intFromEnum(attachment.alphaBlendOp));
            } else {
                gl.blendFuncSeparatei(@intCast(index), gl.SRC_COLOR, gl.ZERO, gl.SRC_ALPHA, gl.ZERO);
                gl.blendEquationSeparatei(@intCast(index), gl.FUNC_ADD, gl.FUNC_ADD);
            }

            if (lastColorMask.*[index].eq(attachment.colorWriteMask)) {
                const r: gl.GLboolean = if (attachment.colorWriteMask.red) gl.TRUE else gl.FALSE;
                const g: gl.GLboolean = if (attachment.colorWriteMask.green) gl.TRUE else gl.FALSE;
                const b: gl.GLboolean = if (attachment.colorWriteMask.blue) gl.TRUE else gl.FALSE;
                const a: gl.GLboolean = if (attachment.colorWriteMask.alpha) gl.TRUE else gl.FALSE;
                gl.colorMaski(@intCast(index), r, g, b, a);
            }
        }
    } else {
        glEnableOrDisable(gl.COLOR_LOGIC_OP, self.logicOpEnable);
        if (self.logicOpEnable) {
            gl.logicOp(@intFromEnum(self.logicOp));
        }
        gl.blendColor(self.blendConstants[0], self.blendConstants[1], self.blendConstants[2], self.blendConstants[3]);

        for (self.attachments, 0..) |attachment, index| {
            if (attachment.blendEnable) {
                gl.blendFuncSeparatei(
                    @intCast(index),
                    @intFromEnum(attachment.srcRgbFactor),
                    @intFromEnum(attachment.dstRgbFactor),
                    @intFromEnum(attachment.srcAlphaFactor),
                    @intFromEnum(attachment.dstAlphaFactor),
                );
                gl.blendEquationSeparatei(@intCast(index), @intFromEnum(attachment.colorBlendOp), @intFromEnum(attachment.alphaBlendOp));
            } else {
                gl.blendFuncSeparatei(@intCast(index), gl.SRC_COLOR, gl.ZERO, gl.SRC_ALPHA, gl.ZERO);
                gl.blendEquationSeparatei(@intCast(index), gl.FUNC_ADD, gl.FUNC_ADD);
            }

            if (lastColorMask.*[index].eq(attachment.colorWriteMask)) {
                const r: gl.GLboolean = if (attachment.colorWriteMask.red) gl.TRUE else gl.FALSE;
                const g: gl.GLboolean = if (attachment.colorWriteMask.green) gl.TRUE else gl.FALSE;
                const b: gl.GLboolean = if (attachment.colorWriteMask.blue) gl.TRUE else gl.FALSE;
                const a: gl.GLboolean = if (attachment.colorWriteMask.alpha) gl.TRUE else gl.FALSE;
                gl.colorMaski(@intCast(index), r, g, b, a);
            }
        }
    }
}
