const std = @import("std");
const ShaderStage = @import("PipelineInformation.zig").ShaderStage;

pub const ShaderInput = struct {
    name: []const u8,
    stage: ShaderStage,
    location: usize,
    size: usize,
    type: type,
};

pub const ShaderOutput = struct {
    name: []const u8,
    stage: ShaderStage,
    location: usize,
    size: usize,
    type: type,
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
