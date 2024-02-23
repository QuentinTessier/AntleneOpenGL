const std = @import("std");
const Information = @import("./PipelineInformation.zig");
const ReflectionType = @import("./ReflectionType.zig");

pub fn VAOFromReflectShader(comptime Input: []ReflectionType.ShaderInput) []const Information.VertexInputAttributeDescription {
    _ = Input;
    return &.{};
}

pub fn TypedGraphicPipeline(comptime ReflectedShader: type) type {
    return struct {};
}
