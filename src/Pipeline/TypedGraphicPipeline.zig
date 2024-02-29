const std = @import("std");
const gl = @import("../gl4_6.zig");
const Information = @import("PipelineInformation.zig");
const VertexArrayObject = @import("../Resources/VertexArrayObject.zig");
const hash = @import("GraphicPipeline.zig").hash;
const Shader = @import("../Resources/Shader.zig");
const GraphicPipeline = @import("./GraphicPipeline.zig");

pub fn TypedGraphicPipeline(comptime Reflection: type) type {
    return struct {
        pub const ReflectedType = Reflection;

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

        pub fn init(allocator: std.mem.Allocator, info: Information.TypedGraphicPipelineInformation, vertexInputState: Information.PipelineVertexInputState, vao: VertexArrayObject) !@This() {
            const program = try Shader.getProgramFromReflected(Reflection, allocator);

            if (std.debug.runtime_safety) {
                const typename = @typeName(Reflection);
                const index = std.mem.lastIndexOf(u8, typename, ".") orelse 0;
                const name = typename[index..];
                gl.objectLabel(gl.PROGRAM, program, @intCast(name.len), name.ptr);
            }

            return .{
                .handle = program,
                .hash = 0,
                .vao = vao,
                .inputAssemblyState = info.inputAssemblyState,
                .vertexInputState = vertexInputState,
                .rasterizationState = info.rasterizationState,
                .multiSampleState = info.multiSampleState,
                .depthState = info.depthState,
                .stencilState = info.stencilState,
                .colorBlendState = info.colorBlendState,
            };
        }

        pub fn deinit(self: @This()) void {
            gl.deleteProgram(self.handle);
        }

        pub fn toGraphicPipeline(self: @This()) GraphicPipeline {
            return .{
                .handle = self.handle,
                .hash = self.hash,
                .vao = self.vao,
                .inputAssemblyState = self.inputAssemblyState,
                .vertexInputState = self.vertexInputState,
                .rasterizationState = self.rasterizationState,
                .multiSampleState = self.multiSampleState,
                .depthState = self.depthState,
                .stencilState = self.stencilState,
                .colorBlendState = self.colorBlendState,
            };
        }
    };
}
