const std = @import("std");
const gl = @import("../gl4_6.zig");
const ShaderSource = @import("../Pipeline/PipelineInformation.zig").ShaderSource;
const ShaderStage = @import("../Pipeline/PipelineInformation.zig").ShaderStage;
const ReflectionType = @import("../Pipeline/ReflectionType.zig");

const Shader = @import("../Resources/Shader.zig");
const ReflectSource = @import("./ReflectSource.zig");
const ReflectIO = @import("./ReflectInputOutput.zig");
const ReflectDataBlock = @import("./ReflectBlocks.zig");
const ReflectSampler = @import("./ReflectSampler.zig");

pub const ShaderInformation = struct {
    stage: ShaderStage,
    path: []const u8,
    source: ShaderSource,
};

pub const ReflectionInformation = struct {
    libraryName: []const u8 = "Graphics",
    namespace: []const u8 = "Pipeline",
    shaderType: Shader.ShaderType,
    source: ReflectSource.StoreShaderSource,
    shaders: []const []const u8,
};

pub fn reflect(allocator: std.mem.Allocator, information: ReflectionInformation, writer: anytype) !void {
    var shaders = try allocator.alloc(u32, information.shaders.len);
    var shadersInformation = try allocator.alloc(ShaderInformation, information.shaders.len);
    for (information.shaders, 0..) |shader, index| {
        switch (information.shaderType) {
            .glsl => {
                const tmp = try Shader.fromGLSLFileKeepSource(allocator, shader);
                shaders[index] = tmp.handle;
                shadersInformation[index] = .{ .stage = tmp.stage, .path = shader, .source = .{ .glsl = tmp.source } };
            },
            .spirv => {
                const tmp = try Shader.fromSPIRVFileKeepSource(allocator, shader);
                shaders[index] = tmp.handle;
                shadersInformation[index] = .{ .stage = tmp.stage, .path = shader, .source = .{ .spirv = tmp.source } };
            },
        }
    }
    const program = try Shader.linkProgram(shaders);

    defer {
        for (shaders) |shader| {
            gl.deleteShader(shader);
        }
        allocator.free(shaders);
        for (shadersInformation) |info| {
            switch (info.source) {
                .glsl => |glsl| allocator.free(glsl),
                .spirv => |spirv| allocator.free(spirv),
            }
        }
        allocator.free(shadersInformation);
        gl.deleteProgram(program);
    }

    try writer.print("const ReflectionType = @import(\"{s}\").ReflectionType;\n\n", .{information.libraryName});
    try writer.print("pub const {s} = struct {{\n", .{information.namespace});

    try ReflectIO.shaderInput(allocator, program, writer);
    try ReflectIO.shaderOutput(allocator, program, writer);
    try ReflectDataBlock.shaderStorageBlock(allocator, program, writer);
    try ReflectDataBlock.uniformBlock(allocator, program, writer);
    try ReflectSampler.samplers(allocator, program, writer);
    try ReflectSource.reflectShaderData(information.source, shadersInformation, writer);

    try writer.print("}};\n", .{});
}
