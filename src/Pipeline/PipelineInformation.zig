const std = @import("std");
const gl = @import("../gl4_6.zig");
const ReflectionType = @import("./ReflectionType.zig");

pub const ShaderStage = enum(u32) {
    Vertex = gl.VERTEX_SHADER,
    Fragment = gl.FRAGMENT_SHADER,

    Compute = gl.COMPUTE_SHADER,
};

pub const VertexInputFormat = enum(u32) {
    i8 = gl.BYTE,
    u8 = gl.UNSIGNED_BYTE,
    i16 = gl.SHORT,
    u16 = gl.UNSIGNED_SHORT,
    i32 = gl.INT,
    u32 = gl.UNSIGNED_INT,
    fixed = gl.FIXED,
    f32 = gl.FLOAT,
    f64 = gl.DOUBLE,

    pub fn getSize(self: VertexInputFormat) u32 {
        return switch (self) {
            .i8, .u8 => 1,
            .i16, .u16 => 2,
            .i32, .u32, .f32, .fixed => 4,
            .f64 => 8,
        };
    }
};

pub const VertexInputAttributeDescription = struct {
    location: u32,
    binding: u32,
    format: VertexInputFormat,
    size: u32,
    offset: u32,
};

pub const PipelineVertexInputState = struct {
    vertexAttributeDescription: []const VertexInputAttributeDescription,

    const InputRate = struct {
        format: VertexInputFormat,
        count: u32,
        offset: u32,
    };
    fn getInputRate(input: ReflectionType.ShaderInput) InputRate {
        const format = switch (input.type) {
            .i32,
            .vec2_i32,
            .vec3_i32,
            .vec4_i32,
            => VertexInputFormat.i32,

            .u32,
            .vec2_u32,
            .vec3_u32,
            .vec4_u32,
            => VertexInputFormat.u32,

            .f32,
            .vec2_f32,
            .vec3_f32,
            .vec4_f32,
            .mat2_f32,
            .mat3_f32,
            .mat4_f32,
            .mat2x3_f32,
            .mat2x4_f32,
            .mat3x2_f32,
            .mat3x4_f32,
            .mat4x2_f32,
            .mat4x3_f32,
            => VertexInputFormat.f32,

            .f64,
            .mat2_f64,
            .mat3_f64,
            .mat4_f64,
            .mat2x3_f64,
            .mat2x4_f64,
            .mat3x2_f64,
            .mat3x4_f64,
            .mat4x2_f64,
            .mat4x3_f64,
            .vec2_f64,
            .vec3_f64,
            .vec4_f64,
            => VertexInputFormat.f64,

            else => VertexInputFormat.u8,
        };

        const count: u32 = switch (input.type) {
            .i32, .u32, .f32, .f64 => 1,
            .vec2_i32, .vec2_u32, .vec2_f32, .vec2_f64 => 2,
            .vec3_i32, .vec3_u32, .vec3_f32, .vec3_f64 => 3,
            .vec4_i32, .vec4_u32, .vec4_f32, .vec4_f64 => 4,
            else => 0,
        };

        const offset = format.getSize() * count;

        return .{
            .format = format,
            .count = count,
            .offset = offset,
        };
    }

    pub fn fromReflected(comptime Reflection: type) PipelineVertexInputState {
        if (!@hasDecl(Reflection, "Input")) @panic("Missing Input declaration");

        const Input = Reflection.Input;
        var vertexAttributeDescription: [Input.len]VertexInputAttributeDescription = [1]VertexInputAttributeDescription{undefined} ** Input.len;

        inline for (Input, 0..) |input, i| {
            const inputRate = getInputRate(input);
            vertexAttributeDescription[i] = .{
                .location = input.location,
                .binding = 0,
                .format = inputRate.format,
                .size = inputRate.count,
                .offset = inputRate.offset,
            };
        }

        return .{
            .vertexAttributeDescription = &vertexAttributeDescription,
        };
    }
};

pub const PrimitiveTopology = enum(u32) {
    triangle = gl.TRIANGLES,
    triangle_strip = gl.TRIANGLE_STRIP,
};

pub const PipelineInputAssemblyState = struct {
    topology: PrimitiveTopology = .triangle,
    enableRestart: bool = false,
};

pub const PolygonMode = enum(u32) {
    fill = gl.FILL,
    line = gl.LINE,
    point = gl.POINT,
};

pub const CullMode = enum(u32) {
    none = 0,
    back = gl.BACK,
    front = gl.FRONT,
};

pub const FrontFace = enum(u32) {
    clockWise = gl.CW,
    counterClockWise = gl.CCW,
};

pub const PipelineRasterizationState = struct {
    depthClampEnable: bool = true,
    polygonMode: PolygonMode = .fill,
    cullMode: CullMode = .back,
    frontFace: FrontFace = .counterClockWise,
    depthBiasEnable: bool = false,
    depthBiasConstantFactor: f32 = 0.0,
    depthBiasSlopeFactor: f32 = 0.0,
    lineWidth: f32 = 1.0,
    pointWidth: f32 = 1.0,
};

pub const PipelineMultisampleState = struct {
    sampleShadingEnable: bool = false,
    minSampleShading: f32 = 1.0,
    sampleMask: u32 = 0xFFFFFFFF,
    alphaToCoverageEnable: bool = false,
    alphaToOneEnable: bool = false,
};

pub const CompareOp = enum(u32) {
    never = gl.NEVER,
    less = gl.LESS,
    equal = gl.EQUAL,
    lessOrEqual = gl.LEQUAL,
    greater = gl.GREATER,
    notEqual = gl.NOTEQUAL,
    greaterOrEqual = gl.GEQUAL,
    always = gl.ALWAYS,
};

pub const StencilOp = enum(u32) {
    keep = gl.KEEP,
};

pub const PipelineDepthState = struct {
    depthTestEnable: bool = false,
    depthWriteEnable: bool = false,
    depthCompareOp: CompareOp = .less,
};

pub const StencilOperationState = struct {
    stencilFail: StencilOp = .keep,
    stencilPass: StencilOp = .keep,
    depthFail: StencilOp = .keep,

    compareOp: CompareOp = .always,

    compareMask: u32 = 0x0,
    writeMask: i32 = 0x0,
    reference: i32 = 0x0,

    pub fn eq(self: StencilOperationState, other: StencilOperationState) bool {
        const b1 = std.mem.asBytes(&self);
        const b2 = std.mem.asBytes(&other);

        return std.mem.eql(u8, b1, b2);
    }
};

pub const PipelineStencilState = struct {
    stencilTestEnable: bool = false,

    front: StencilOperationState = .{},
    back: StencilOperationState = .{},
};

pub const BlendFactor = enum(u32) {
    Zero = gl.ZERO,
    One = gl.ONE,
    SrcColor = gl.SRC_COLOR,
    OneMinusSrcColor = gl.ONE_MINUS_SRC_COLOR,
    DstColor = gl.DST_COLOR,
    OneMinusDstColor = gl.ONE_MINUS_DST_COLOR,
    SrcAlpha = gl.SRC_ALPHA,
    OneMinusSrcAlpha = gl.ONE_MINUS_SRC_ALPHA,
    DstAlpha = gl.DST_ALPHA,
    OneMinusDstAlpha = gl.ONE_MINUS_DST_ALPHA,
    ConstantColor = gl.CONSTANT_COLOR,
    OneMinusConstantColor = gl.ONE_MINUS_CONSTANT_COLOR,
    ConstantAlpha = gl.CONSTANT_ALPHA,
    OneMinusConstantAlpha = gl.ONE_MINUS_CONSTANT_ALPHA,
    SrcAlphaSaturate = gl.SRC_ALPHA_SATURATE,
};

pub const BlendOp = enum(u32) {
    Add = gl.FUNC_ADD,
    Substract = gl.FUNC_SUBTRACT,
    ReverseSubstract = gl.FUNC_REVERSE_SUBTRACT,
    Min = gl.MIN,
    Max = gl.MAX,
};

pub const ColorComponentFlags = packed struct(u32) {
    red: bool = true,
    green: bool = true,
    blue: bool = true,
    alpha: bool = true,
    __unused0: u28 = 0,

    pub fn eq(self: ColorComponentFlags, other: ColorComponentFlags) bool {
        return self.red == other.red and self.green == other.green and self.blue == other.blue and self.alpha == other.alpha;
    }
};

pub const LogicOp = enum(u32) {
    clear = gl.CLEAR,
    set = gl.SET,
    copy = gl.COPY,
    copyInverted = gl.COPY_INVERTED,
    noop = gl.NOOP,
    invert = gl.INVERT,
    and_ = gl.AND,
    nand = gl.NAND,
    or_ = gl.OR,
    nor = gl.NOR,
    xor = gl.XOR,
    equiv = gl.EQUIV,
    andReverse = gl.AND_REVERSE,
    andInverted = gl.AND_INVERTED,
    orReverse = gl.OR_REVERSE,
    OrInverted = gl.OR_INVERTED,
};

pub const ColorAttachmentState = struct {
    blendEnable: bool = false,
    srcRgbFactor: BlendFactor = .One,
    dstRgbFactor: BlendFactor = .Zero,
    colorBlendOp: BlendOp = .Add,
    srcAlphaFactor: BlendFactor = .One,
    dstAlphaFactor: BlendFactor = .Zero,
    alphaBlendOp: BlendOp = .Add,
    colorWriteMask: ColorComponentFlags = .{
        .red = true,
        .green = true,
        .blue = true,
        .alpha = true,
    },

    pub fn eq(self: ColorAttachmentState, other: ColorAttachmentState) bool {
        const b1 = std.mem.asBytes(&self);
        const b2 = std.mem.asBytes(&other);
        return std.mem.eql(u8, b1, b2);
    }
};

pub const PipelineColorBlendState = struct {
    logicOpEnable: bool = false,
    logicOp: LogicOp = .copy,
    attachments: []const ColorAttachmentState = &.{},
    blendConstants: [4]f32 = .{ 0, 0, 0, 0 },
};

pub const ShaderSource = union(enum(u32)) {
    glsl: []const u8,
    spirv: []const u32,

    pub fn len(self: ShaderSource) usize {
        return switch (self) {
            .glsl => |glsl| glsl.len,
            .spirv => |spirv| spirv.len * 4,
        };
    }

    pub fn slice(self: ShaderSource) []const u8 {
        return switch (self) {
            .glsl => |glsl| glsl,
            .spirv => |spirv| std.mem.sliceAsBytes(spirv),
        };
    }
};

pub const GraphicPipelineInformation = struct {
    name: ?[]const u8 = null,

    vertexShaderSource: ShaderSource,
    fragmentShaderSource: ShaderSource,

    inputAssemblyState: PipelineInputAssemblyState = .{},
    vertexInputState: PipelineVertexInputState,
    rasterizationState: PipelineRasterizationState = .{},
    multiSampleState: PipelineMultisampleState = .{},
    depthState: PipelineDepthState = .{},
    stencilState: PipelineStencilState = .{},
    colorBlendState: PipelineColorBlendState = .{},
};

pub const TypedGraphicPipelineInformation = struct {
    inputAssemblyState: PipelineInputAssemblyState = .{},
    rasterizationState: PipelineRasterizationState = .{},
    multiSampleState: PipelineMultisampleState = .{},
    depthState: PipelineDepthState = .{},
    stencilState: PipelineStencilState = .{},
    colorBlendState: PipelineColorBlendState = .{},
};

pub const ComputePipelineInformation = struct {
    name: ?[]const u8 = null,

    computeShaderSource: ShaderSource,
};

pub fn compileShader(stage: u32, source: ShaderSource) !u32 {
    const shader = gl.createShader(stage);
    switch (source) {
        .spirv => |spirv| {
            gl.shaderBinary(
                1,
                @ptrCast(&shader),
                gl.SHADER_BINARY_FORMAT_SPIR_V,
                spirv.ptr,
                @intCast(spirv.len),
            );
            gl.specializeShader(shader, "main", 0, null, null);
        },
        .glsl => |glsl| {
            gl.shaderSource(shader, 1, @ptrCast(&glsl.ptr), null);
            gl.compileShader(shader);
        },
    }

    var success: i32 = 0;
    gl.getShaderiv(shader, gl.COMPILE_STATUS, @ptrCast(&success));
    if (success != gl.TRUE) {
        var buffer: [1024]u8 = undefined;
        gl.getShaderInfoLog(shader, 1024, null, (&buffer).ptr);
        std.log.err("{s}", .{buffer});
        return error.FailedShaderCompilation;
    }

    return shader;
}

pub fn linkProgram(shaders: []const u32) !u32 {
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
    for (shaders) |shader| {
        gl.deleteShader(shader);
    }
    return program;
}

pub fn reflectInterface(allocator: std.mem.Allocator, program: u32, interface: gl.GLenum) !std.StringArrayHashMapUnmanaged(u32) {
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
            } else {
                allocator.free(name);
            }
        }
    }
    return resources;
}
