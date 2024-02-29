const std = @import("std");
const gl = @import("../gl4_6.zig");
const ReflectionType = @import("../Pipeline/ReflectionType.zig");

pub fn samplers(allocator: std.mem.Allocator, program: u32, writer: anytype) !void {
    var nActiveResources: i32 = 0;
    gl.getProgramInterfaceiv(program, gl.UNIFORM, gl.ACTIVE_RESOURCES, @ptrCast(&nActiveResources));

    try writer.print("\tpub const Samplers = struct {{\n", .{});
    for (0..@intCast(nActiveResources)) |i| {
        const name_length: i32 = blk: {
            const property: i32 = gl.NAME_LENGTH;
            var len: i32 = 0;

            gl.getProgramResourceiv(
                program,
                gl.UNIFORM,
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
                gl.UNIFORM,
                @intCast(i),
                @intCast(array.len),
                null,
                array.ptr,
            );
            break :blk array;
        };
        defer allocator.free(name);

        const glsl_type = blk: {
            const property: i32 = gl.TYPE;
            var t: i32 = 0;

            gl.getProgramResourceiv(
                program,
                gl.UNIFORM,
                @intCast(i),
                1,
                @ptrCast(&property),
                1,
                null,
                @ptrCast(&t),
            );
            break :blk @as(ReflectionType.GLSLType, @enumFromInt(t));
        };

        const location = gl.getProgramResourceLocation(program, gl.UNIFORM, name.ptr);
        if (location >= 0) {
            var buffer: [64]u8 = [1]u8{0} ** 64;
            const e = try std.fmt.bufPrint(&buffer, "{}", .{glsl_type});
            const index = std.mem.lastIndexOf(u8, e, ".") orelse 0;

            try writer.print("\t\tpub const {s}: ReflectionType.UniformBufferBinding = .{{ .binding = {}, .type = {s} }};\n", .{ name[0 .. name.len - 1], location, buffer[index..] });
        }
    }
    try writer.print("\t}};\n\n", .{});
}
