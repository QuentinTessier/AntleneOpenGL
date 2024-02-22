const std = @import("std");

pub const ShaderStage = enum(u32) {
    Vertex,
    Fragment,
};

pub const ShaderInput = struct {
    stage: ShaderStage,
    location: usize,
    size: usize,
    type: type,
};

pub const ShaderOutput = struct {
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
