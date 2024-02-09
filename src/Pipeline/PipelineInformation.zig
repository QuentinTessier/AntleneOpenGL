const std = @import("std");
const gl = @import("../gl4_6.zig");

pub const VertexInputFormat = enum(u32) {
    float = gl.FLOAT,
};

pub const VertexInputAttributeDescription = struct {
    location: u32,
    binding: u32,
    format: VertexInputFormat, // TODO: fill and use the VertexInputFormat enum
    size: u32,
    offset: u32,
};

pub const PipelineVertexInputState = struct {
    vertexAttributeDescription: []const VertexInputAttributeDescription,
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

pub const GraphicPipelineInformation = struct {
    name: ?[]const u8 = null,

    vertexShaderSource: []const u8,
    fragmentShaderSource: []const u8,

    inputAssemblyState: PipelineInputAssemblyState = .{},
    vertexInputState: PipelineVertexInputState,
    rasterizationState: PipelineRasterizationState = .{},
    multiSampleState: PipelineMultisampleState = .{},
    depthState: PipelineDepthState = .{},
    stencilState: PipelineStencilState = .{},
    colorBlendState: PipelineColorBlendState = .{},
};
