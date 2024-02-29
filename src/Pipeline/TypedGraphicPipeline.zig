const std = @import("std");
const Information = @import("PipelineInformation.zig");
const VertexArrayObject = @import("../Resources/VertexArrayObject.zig");
const hash = @import("GraphicPipeline.zig").hash;
const Shader = @import("../Resources/Shader.zig");

fn getShaderSource(comptime Reflection: type) u32 {
    if (@hasDecl(Reflection, "ShaderSource")) {}
}

pub fn TypedGraphicPipeline(comptime Reflection: type) type {
    return struct {
        handle: u32,
        hash: u64,
        vao: VertexArrayObject,

        inputAssemblyState: Information.PipelineInputAssemblyState,
        vertexInputState: Information.PipelineVertexInputState,
        rasterizationState: Information.PipelineRasterizationState,
        multiSampleState: Information.PipelineMultisampleState,
        depthState: Information.PipelineDepthState,
        stencilState: Information.PipelineStencilState,
        colorBlendState: Information.PipelineColorBlendState,

        pub fn init(allocator: std.mem.Allocator, info: Information.TypedGraphicPipelineInformation) !@This() {}
    };
}
