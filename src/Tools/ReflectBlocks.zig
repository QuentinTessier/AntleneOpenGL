const std = @import("std");
const gl = @import("../gl4_6.zig");
const ReflectionType = @import("../Pipeline/ReflectionType.zig");

pub fn shaderStorageBlock(allocator: std.mem.Allocator, program: u32, writer: anytype) !void {
    var nActiveResources: i32 = 0;
    gl.getProgramInterfaceiv(program, gl.SHADER_STORAGE_BLOCK, gl.ACTIVE_RESOURCES, @ptrCast(&nActiveResources));

    try writer.print("\tpub const ShaderStorageBlocks = struct {{\n", .{});
    for (0..@intCast(nActiveResources)) |i| {
        const name_length: i32 = blk: {
            const property: i32 = gl.NAME_LENGTH;
            var len: i32 = 0;

            gl.getProgramResourceiv(
                program,
                gl.SHADER_STORAGE_BLOCK,
                @intCast(i),
                1,
                @ptrCast(&property),
                1,
                null,
                @ptrCast(&len),
            );
            break :blk len;
        };

        const name: []const u8 = blk: {
            const array = try allocator.alloc(u8, @intCast(name_length));
            gl.getProgramResourceName(
                program,
                gl.SHADER_STORAGE_BLOCK,
                @intCast(i),
                @intCast(array.len),
                null,
                array.ptr,
            );
            break :blk array;
        };
        defer allocator.free(name);

        const binding: i32 = blk: {
            const property: i32 = gl.BUFFER_BINDING;
            var b: i32 = 0;

            gl.getProgramResourceiv(
                program,
                gl.SHADER_STORAGE_BLOCK,
                @intCast(i),
                1,
                @ptrCast(&property),
                1,
                null,
                @ptrCast(&b),
            );
            break :blk b;
        };

        try writer.print("\t\tpub const {s}: ReflectionType.ShaderStorageBufferBinding = .{{ .binding = {} }};\n", .{ name[0 .. name.len - 1], binding });
    }
    try writer.print("\t}};\n\n", .{});
}

pub fn uniformBlock(allocator: std.mem.Allocator, program: u32, writer: anytype) !void {
    var nActiveResources: i32 = 0;
    gl.getProgramInterfaceiv(program, gl.UNIFORM_BLOCK, gl.ACTIVE_RESOURCES, @ptrCast(&nActiveResources));

    try writer.print("\tpub const UniformBlocks = struct {{\n", .{});
    for (0..@intCast(nActiveResources)) |i| {
        const name_length: i32 = blk: {
            const property: i32 = gl.NAME_LENGTH;
            var len: i32 = 0;

            gl.getProgramResourceiv(
                program,
                gl.UNIFORM_BLOCK,
                @intCast(i),
                1,
                @ptrCast(&property),
                1,
                null,
                @ptrCast(&len),
            );
            break :blk len;
        };

        const name: []const u8 = blk: {
            const array = try allocator.alloc(u8, @intCast(name_length));
            gl.getProgramResourceName(
                program,
                gl.UNIFORM_BLOCK,
                @intCast(i),
                @intCast(array.len),
                null,
                array.ptr,
            );
            break :blk array;
        };
        defer allocator.free(name);

        const binding: i32 = blk: {
            const property: i32 = gl.BUFFER_BINDING;
            var b: i32 = 0;

            gl.getProgramResourceiv(
                program,
                gl.UNIFORM_BLOCK,
                @intCast(i),
                1,
                @ptrCast(&property),
                1,
                null,
                @ptrCast(&b),
            );
            break :blk b;
        };

        try writer.print("\t\tpub const {s}: ReflectionType.UniformBufferBinding = .{{ .binding = {} }};\n", .{ name[0 .. name.len - 1], binding });
    }
    try writer.print("\t}};\n\n", .{});
}
