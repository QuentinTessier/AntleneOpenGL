const std = @import("std");
const gl = @import("../gl4_6.zig");
const ShaderStage = @import("PipelineInformation.zig").ShaderStage;
pub const ShaderType = @import("../Resources/Shader.zig").ShaderType;
const ShaderSource = @import("../Pipeline/PipelineInformation.zig").ShaderSource;

pub const ShaderInput = struct {
    name: []const u8,
    location: u32,
    type: GLSLType,
};

pub const ShaderOutput = struct {
    name: []const u8,
    location: u32,
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
    binding: u32,
    // memory_access: MemoryAccess,
};

pub const UniformBufferBinding = struct {
    binding: u32,
};

pub const SamplerBinding = struct {
    binding: usize,
    type: GLSLType,
};

pub const GLSLType = enum(u32) {
    i32 = gl.INT,
    u32 = gl.UNSIGNED_INT,
    f32 = gl.FLOAT,
    f64 = gl.DOUBLE,
    vec2_f32 = gl.FLOAT_VEC2,
    vec3_f32 = gl.FLOAT_VEC3,
    vec4_f32 = gl.FLOAT_VEC4,
    vec2_i32 = gl.INT_VEC2,
    vec3_i32 = gl.INT_VEC3,
    vec4_i32 = gl.INT_VEC4,
    bool = gl.BOOL,
    vec2_bool = gl.BOOL_VEC2,
    vec3_bool = gl.BOOL_VEC3,
    vec4_bool = gl.BOOL_VEC4,
    mat2_f32 = gl.FLOAT_MAT2,
    mat3_f32 = gl.FLOAT_MAT3,
    mat4_f32 = gl.FLOAT_MAT4,

    sampler1D = gl.SAMPLER_1D,
    sampler2D = gl.SAMPLER_2D,
    sampler3D = gl.SAMPLER_3D,
    samplerCube = gl.SAMPLER_CUBE,
    sampler1DShadow = gl.SAMPLER_1D_SHADOW,
    sampler2DShadow = gl.SAMPLER_2D_SHADOW,
    sampler2DRect = gl.SAMPLER_2D_RECT,
    sampler2DRectShadow = gl.SAMPLER_2D_RECT_SHADOW,

    mat2x3_f32 = gl.FLOAT_MAT2x3,
    mat2x4_f32 = gl.FLOAT_MAT2x4,
    mat3x2_f32 = gl.FLOAT_MAT3x2,
    mat3x4_f32 = gl.FLOAT_MAT3x4,
    mat4x2_f32 = gl.FLOAT_MAT4x2,
    mat4x3_f32 = gl.FLOAT_MAT4x3,

    sampler1DArray = gl.SAMPLER_1D_ARRAY,
    sampler2DArray = gl.SAMPLER_2D_ARRAY,
    samplerBuffer = gl.SAMPLER_BUFFER,
    sampler1DArrayShadow = gl.SAMPLER_1D_ARRAY_SHADOW,
    sampler2DArrayShadow = gl.SAMPLER_2D_ARRAY_SHADOW,
    samplerCubeShadow = gl.SAMPLER_CUBE_SHADOW,

    vec2_u32 = gl.UNSIGNED_INT_VEC2,
    vec3_u32 = gl.UNSIGNED_INT_VEC3,
    vec4_u32 = gl.UNSIGNED_INT_VEC4,

    sampler1D_i32 = gl.INT_SAMPLER_1D,
    sampler2D_i32 = gl.INT_SAMPLER_2D,
    sampler3D_i32 = gl.INT_SAMPLER_3D,
    samplerCube_i32 = gl.INT_SAMPLER_CUBE,
    sampler2DRect_i32 = gl.INT_SAMPLER_2D_RECT,
    sampler1DArray_i32 = gl.INT_SAMPLER_1D_ARRAY,
    sampler2DArray_i32 = gl.INT_SAMPLER_2D_ARRAY,
    samplerBuffer_i32 = gl.INT_SAMPLER_BUFFER,
    sampler1D_u32 = gl.UNSIGNED_INT_SAMPLER_1D,
    sampler2D_u32 = gl.UNSIGNED_INT_SAMPLER_2D,
    sampler3D_u32 = gl.UNSIGNED_INT_SAMPLER_3D,
    samplerCube_u32 = gl.UNSIGNED_INT_SAMPLER_CUBE,
    sampler2DRect_u32 = gl.UNSIGNED_INT_SAMPLER_2D_RECT,
    sampler1DArray_u32 = gl.UNSIGNED_INT_SAMPLER_1D_ARRAY,
    sampler2DArray_u32 = gl.UNSIGNED_INT_SAMPLER_2D_ARRAY,
    samplerBuffer_u32 = gl.UNSIGNED_INT_SAMPLER_BUFFER,

    mat2_f64 = gl.DOUBLE_MAT2,
    mat3_f64 = gl.DOUBLE_MAT3,
    mat4_f64 = gl.DOUBLE_MAT4,
    mat2x3_f64 = gl.DOUBLE_MAT2x3,
    mat2x4_f64 = gl.DOUBLE_MAT2x4,
    mat3x2_f64 = gl.DOUBLE_MAT3x2,
    mat3x4_f64 = gl.DOUBLE_MAT3x4,
    mat4x2_f64 = gl.DOUBLE_MAT4x2,
    mat4x3_f64 = gl.DOUBLE_MAT4x3,
    vec2_f64 = gl.DOUBLE_VEC2,
    vec3_f64 = gl.DOUBLE_VEC3,
    vec4_f64 = gl.DOUBLE_VEC4,

    samplerCubeMapArray = gl.SAMPLER_CUBE_MAP_ARRAY,
    samplerCubeMapArrayShadow = gl.SAMPLER_CUBE_MAP_ARRAY_SHADOW,
    samplerCubeMapArray_i32 = gl.INT_SAMPLER_CUBE_MAP_ARRAY,
    samplerCubeMapArrayShadow_i32 = gl.UNSIGNED_INT_SAMPLER_CUBE_MAP_ARRAY,

    image1D = gl.IMAGE_1D,
    image2D = gl.IMAGE_2D,
    image3D = gl.IMAGE_3D,
    image2DRect = gl.IMAGE_2D_RECT,
    imageCube = gl.IMAGE_CUBE,
    imageBuffer = gl.IMAGE_BUFFER,
    image1DArray = gl.IMAGE_1D_ARRAY,
    image2DArray = gl.IMAGE_2D_ARRAY,
    imageCubeMapArray = gl.IMAGE_CUBE_MAP_ARRAY,
    image2DMultiSample = gl.IMAGE_2D_MULTISAMPLE,
    image2DMultiSampleArray = gl.IMAGE_2D_MULTISAMPLE_ARRAY,
    image1D_i32 = gl.INT_IMAGE_1D,
    image2D_i32 = gl.INT_IMAGE_2D,
    image3D_i32 = gl.INT_IMAGE_3D,
    image2DRect_i32 = gl.INT_IMAGE_2D_RECT,
    imageCube_i32 = gl.INT_IMAGE_CUBE,
    imageBuffer_i32 = gl.INT_IMAGE_BUFFER,
    image1DArray_i32 = gl.INT_IMAGE_1D_ARRAY,
    image2DArray_i32 = gl.INT_IMAGE_2D_ARRAY,
    imageCubeMapArray_i32 = gl.INT_IMAGE_CUBE_MAP_ARRAY,
    image2DMultiSample_i32 = gl.INT_IMAGE_2D_MULTISAMPLE,
    image2DMultiSampleArray_i32 = gl.INT_IMAGE_2D_MULTISAMPLE_ARRAY,
    image1D_u32 = gl.UNSIGNED_INT_IMAGE_1D,
    image2D_u32 = gl.UNSIGNED_INT_IMAGE_2D,
    image3D_u32 = gl.UNSIGNED_INT_IMAGE_3D,
    image2DRect_u32 = gl.UNSIGNED_INT_IMAGE_2D_RECT,
    imageCube_u32 = gl.UNSIGNED_INT_IMAGE_CUBE,
    imageBuffer_u32 = gl.UNSIGNED_INT_IMAGE_BUFFER,
    image1DArray_u32 = gl.UNSIGNED_INT_IMAGE_1D_ARRAY,
    image2DArray_u32 = gl.UNSIGNED_INT_IMAGE_2D_ARRAY,
    imageCubeMapArray_u32 = gl.UNSIGNED_INT_IMAGE_CUBE_MAP_ARRAY,
    image2DMultiSample_u32 = gl.UNSIGNED_INT_IMAGE_2D_MULTISAMPLE,
    image2DMultiSampleArray_u32 = gl.UNSIGNED_INT_IMAGE_2D_MULTISAMPLE_ARRAY,

    sampler2DMultiSample = gl.SAMPLER_2D_MULTISAMPLE,
    sampler2DMultiSample_i32 = gl.INT_SAMPLER_2D_MULTISAMPLE,
    sampler2DMultiSample_u32 = gl.UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE,
    sampler2DMultiSampleArray = gl.SAMPLER_2D_MULTISAMPLE_ARRAY,
    sampler2DMultiSampleArray_i32 = gl.INT_SAMPLER_2D_MULTISAMPLE_ARRAY,
    sampler2DMultiSampleArray_u32 = gl.UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY,

    pub fn isSamplerOrImage(self: @This()) bool {
        return switch (self) {
            .sampler1D,
            .sampler2D,
            .sampler3D,
            .samplerCube,
            .sampler1DShadow,
            .sampler2DShadow,
            .sampler2DRect,
            .sampler2DRectShadow,
            .sampler1DArray,
            .sampler2DArray,
            .samplerBuffer,
            .sampler1DArrayShadow,
            .sampler2DArrayShadow,
            .samplerCubeShadow,
            .sampler1D_i32,
            .sampler2D_i32,
            .sampler3D_i32,
            .samplerCube_i32,
            .sampler2DRect_i32,
            .sampler1DArray_i32,
            .sampler2DArray_i32,
            .samplerBuffer_i32,
            .sampler1D_u32,
            .sampler2D_u32,
            .sampler3D_u32,
            .samplerCube_u32,
            .sampler2DRect_u32,
            .sampler1DArray_u32,
            .sampler2DArray_u32,
            .samplerBuffer_u32,
            .samplerCubeMapArray,
            .samplerCubeMapArrayShadow,
            .samplerCubeMapArray_i32,
            .samplerCubeMapArrayShadow_i32,
            .sampler2DMultiSample,
            .sampler2DMultiSample_i32,
            .sampler2DMultiSample_u32,
            .sampler2DMultiSampleArray,
            .sampler2DMultiSampleArray_i32,
            .sampler2DMultiSampleArray_u32,
            => true,
            .image1D,
            .image2D,
            .image3D,
            .image2DRect,
            .imageCube,
            .imageBuffer,
            .image1DArray,
            .image2DArray,
            .imageCubeMapArray,
            .image2DMultiSample,
            .image2DMultiSampleArray,
            .image1D_i32,
            .image2D_i32,
            .image3D_i32,
            .image2DRect_i32,
            .imageCube_i32,
            .imageBuffer_i32,
            .image1DArray_i32,
            .image2DArray_i32,
            .imageCubeMapArray_i32,
            .image2DMultiSample_i32,
            .image2DMultiSampleArray_i32,
            .image1D_u32,
            .image2D_u32,
            .image3D_u32,
            .image2DRect_u32,
            .imageCube_u32,
            .imageBuffer_u32,
            .image1DArray_u32,
            .image2DArray_u32,
            .imageCubeMapArray_u32,
            .image2DMultiSample_u32,
            .image2DMultiSampleArray_u32,
            => true,
            else => false,
        };
    }
};

pub const ShaderPath = []const u8;
pub const ShaderStorage = struct {
    stage: ShaderStage,
    source: ShaderSource,
};
