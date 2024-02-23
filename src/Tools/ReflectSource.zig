const std = @import("std");
const gl = @import("../gl4_6.zig");
const ShaderSource = @import("../Pipeline/PipelineInformation.zig").ShaderSource;
const ShaderStage = @import("../Pipeline/PipelineInformation.zig").ShaderStage;
const ReflectionType = @import("../Pipeline/ReflectionType.zig");
const ShaderInformation = @import("./ReflectShaderToStruct.zig").ShaderInformation;

pub const StoreShaderSource = enum {
    None,
    ShaderSource,
    ProgramBinary,
};

pub fn reflectProgram(allocator: std.mem.Allocator, _: []const u8, program: u32, writer: anytype) !void {
    const len = blk: {
        var length: i32 = 0;
        gl.getProgramiv(program, gl.PROGRAM_BINARY_LENGTH, @ptrCast(&length));
        break :blk length;
    };

    var format: gl.GLsizei = 0;

    const buffer = try allocator.alloc(u32, @intCast(@divFloor(len, 4)));
    defer allocator.free(buffer);

    gl.getProgramBinary(program, @intCast(len), null, @ptrCast(&format), buffer.ptr);

    try writer.print("\tpub const ProgramBinary: [{}]u32 = .{{", .{buffer.len});
    for (buffer) |data| {
        try writer.print("0x{X},", .{data});
    }
    try writer.print("\n\t}};\n", .{});
}

pub fn reflectShaderSource(shadersInformation: []const ShaderInformation, writer: anytype) !void {
    for (shadersInformation) |info| {
        const stage_name = switch (info.stage) {
            .Vertex => "VertexShaderSource",
            .Fragment => "FragmentShaderSource",
            .Compute => "ComputeShaderSource",
        };

        switch (info.source) {
            .glsl => |glsl| try writer.print("\tpub const {s}: []const u8 = \"{s}\"", .{ stage_name, glsl }),
            .spirv => |spirv| {
                try writer.print("\tpub const {s}: []const u32 = &.{{\n", .{stage_name});
                for (spirv) |opcode| {
                    try writer.print("\t\t0x{X},\n", .{opcode});
                }
                try writer.print("\t}};\n", .{});
            },
        }
    }
}
