const std = @import("std");
const gl = @import("../gl4_6.zig");
const Information = @import("./PipelineInformation.zig");

pub const ComputePipeline = @This();

handle: u32,

uniformBlocks: std.StringArrayHashMapUnmanaged(u32) = .{},
shaderStorageBlocks: std.StringArrayHashMapUnmanaged(u32) = .{},
samplers: std.StringArrayHashMapUnmanaged(u32) = .{},

pub fn init(allocator: std.mem.Allocator, info: Information.ComputePipelineInformation) !ComputePipeline {
    const shader = try Information.compileShader(gl.COMPUTE_SHADER, info.computeShaderSource);
    const program = try Information.linkProgram(&.{shader});

    if (std.debug.runtime_safety) {
        if (info.name) |name| {
            gl.objectLabel(gl.PROGRAM, program, @intCast(name.len), name.ptr);
        }
    }

    return .{
        .handle = program,
        .uniformBlocks = try Information.reflectInterface(allocator, program, gl.UNIFORM_BLOCK),
        .shaderStorageBlocks = try Information.reflectInterface(allocator, program, gl.SHADER_STORAGE_BLOCK),
        .samplers = try Information.reflectInterface(allocator, program, gl.UNIFORM),
    };
}

pub fn deinit(self: *ComputePipeline, allocator: std.mem.Allocator) void {
    gl.deleteProgram(self.handle);
    for (self.uniformBlocks.keys()) |name| {
        allocator.free(name);
    }
    self.uniformBlocks.deinit(allocator);

    for (self.shaderStorageBlocks.keys()) |name| {
        allocator.free(name);
    }
    self.shaderStorageBlocks.deinit(allocator);

    for (self.samplers.keys()) |name| {
        allocator.free(name);
    }
    self.samplers.deinit(allocator);
}
