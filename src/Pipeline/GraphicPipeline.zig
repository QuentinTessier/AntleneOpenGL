const std = @import("std");
const gl = @import("../gl4_6.zig");
const Information = @import("./PipelineInformation.zig");

pub const GraphicPipelineInformation = Information.GraphicPipelineInformation;

pub const Handle = u32;

pub const GraphicPipeline = @This();

allocator: std.mem.Allocator,

handle: Handle,
vaoHash: u64,

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

fn compileShader(stage: u32, source: []const u8) !Handle {
    const shader = gl.createShader(stage);
    gl.shaderBinary(
        1,
        @ptrCast(&shader),
        gl.SHADER_BINARY_FORMAT_SPIR_V,
        source.ptr,
        @intCast(source.len),
    );
    gl.specializeShader(shader, "main", 0, null, null);
    {
        var success: i32 = 0;
        gl.getShaderiv(shader, gl.COMPILE_STATUS, @ptrCast(&success));
        if (success != gl.TRUE) {
            var buffer: [1024]u8 = undefined;
            gl.getShaderInfoLog(shader, 1024, null, (&buffer).ptr);
            std.log.err("{s}", .{buffer});
            return error.FailedShaderCompilation;
        }
    }
    return shader;
}

fn linkProgram(shaders: []const u32) !Handle {
    const program = gl.createProgram();
    for (shaders) |shader| {
        gl.attachShader(program, shader);
    }
    gl.linkProgram(program);
    {
        var success: i32 = 0;
        gl.getProgramiv(program, gl.LINK_STATUS, &success);
        if (success != gl.TRUE) {
            var size: isize = 0;
            var buffer: [1024]u8 = undefined;
            gl.getProgramInfoLog(program, 1024, @ptrCast(&size), (&buffer).ptr);
            std.log.err("Failed to link program: {s}", .{buffer[0..@intCast(size)]});
            return error.ProgramLinkingFailed;
        }
    }
    return program;
}

fn reflectInterface(allocator: std.mem.Allocator, program: u32, interface: gl.GLenum) !std.StringArrayHashMapUnmanaged(u32) {
    var nActiveResources: i32 = 0;
    gl.getProgramInterfaceiv(program, interface, gl.ACTIVE_RESOURCES, @ptrCast(&nActiveResources));

    var resources: std.StringArrayHashMapUnmanaged(u32) = .{};
    for (0..@intCast(nActiveResources)) |i| {
        var name_length: i32 = 0;

        const property: i32 = gl.NAME_LENGTH;
        gl.getProgramResourceiv(
            program,
            interface,
            @intCast(i),
            1,
            @ptrCast(&property),
            1,
            null,
            @ptrCast(&name_length),
        );

        const name = try allocator.alloc(u8, @intCast(name_length));
        gl.getProgramResourceName(
            program,
            interface,
            @intCast(i),
            @intCast(name.len),
            null,
            name.ptr,
        );

        if (interface == gl.UNIFORM_BLOCK or interface == gl.SHADER_STORAGE_BLOCK) {
            const binding_property: i32 = gl.BUFFER_BINDING;
            var binding: i32 = -1;
            gl.getProgramResourceiv(
                program,
                interface,
                @intCast(i),
                1,
                @ptrCast(&binding_property),
                1,
                null,
                @ptrCast(&binding),
            );
            try resources.put(allocator, name, @intCast(binding));
        } else if (interface == gl.UNIFORM) {
            const location = gl.getProgramResourceLocation(program, interface, name.ptr);

            if (location >= 0) {
                try resources.put(allocator, name, @intCast(location));
            }
        }
    }
    return resources;
}

pub fn init(allocator: std.mem.Allocator, info: GraphicPipelineInformation) !GraphicPipeline {
    const vertex_shader = try compileShader(gl.VERTEX_SHADER, info.vertexShaderSource);
    errdefer gl.deleteShader(vertex_shader);
    const fragment_shader = try compileShader(gl.FRAGMENT_SHADER, info.fragmentShaderSource);
    errdefer gl.deleteShader(fragment_shader);
    const program = try linkProgram(&.{ vertex_shader, fragment_shader });
    errdefer gl.deleteProgram(program);

    if (std.debug.runtime_safety) {
        if (info.name) |name| {
            gl.objectLabel(gl.PROGRAM, program, @intCast(name.len), name.ptr);
        }
    }

    return .{
        .allocator = allocator,
        .handle = program,
        .vaoHash = 0,
        .inputAssemblyState = info.inputAssemblyState,
        .vertexInputState = info.vertexInputState,
        .rasterizationState = info.rasterizationState,
        .multiSampleState = info.multiSampleState,
        .depthState = info.depthState,
        .stencilState = info.stencilState,
        .colorBlendState = info.colorBlendState,
        .uniformBlocks = try reflectInterface(allocator, program, gl.UNIFORM_BLOCK),
        .shaderStorageBlocks = try reflectInterface(allocator, program, gl.SHADER_STORAGE_BLOCK),
        .samplers = try reflectInterface(allocator, program, gl.UNIFORM),
    };
}

pub fn deinit(self: *GraphicPipeline) void {
    gl.deleteProgram(self.handle);
    for (self.uniformBlocks.keys()) |name| {
        self.allocator.free(name);
    }
    self.uniformBlocks.deinit(self.allocator);

    for (self.shaderStorageBlocks.keys()) |name| {
        self.allocator.free(name);
    }
    self.shaderStorageBlocks.deinit(self.allocator);

    for (self.samplers.keys()) |name| {
        self.allocator.free(name);
    }
    self.samplers.deinit(self.allocator);
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
