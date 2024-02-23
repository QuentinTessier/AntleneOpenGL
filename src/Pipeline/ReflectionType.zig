const std = @import("std");
const gl = @import("../gl4_6.zig");
const ShaderStage = @import("PipelineInformation.zig").ShaderStage;

pub const ShaderInput = struct {
    name: []const u8,
    location: i32,
    type: GLSLType,
};

pub const ShaderOutput = struct {
    name: []const u8,
    location: usize,
    type: GLSLType,
};

pub const MemoryAccess = enum {
    coherent,
    @"volatile",
    restrict,
    readonly,
    writeonly,
};

pub const ShaderStorageBufferBinding = struct {
    binding: usize,
    // memory_access: MemoryAccess,
};

pub const UniformBufferBinding = struct {
    binding: usize,
};

pub const SamplerBinding = struct {
    binding: usize,
};

pub const GLSLType = enum(u32) {
    i32 = gl.INT,
    f32 = gl.FLOAT,
    vec2f32 = gl.FLOAT_VEC2,
    vec3f32 = gl.FLOAT_VEC3,
    vec4f32 = gl.FLOAT_VEC4,

    pub fn getGLType(comptime glsl_type: GLSLType) gl.GLenum {
        return switch (glsl_type) {
            .f32, .vec2f32, .vec3f32, .vec4f32 => gl.FLOAT,
            .i32 => gl.INT,
        };
    }

    pub fn getSize(comptime glsl_type: GLSLType) comptime_int {
        return switch (glsl_type) {
            .f32, .i32 => 1,
            .vec2f32 => 2,
            .vec3f32 => 3,
            .vec4f32 => 4,
        };
    }
};
