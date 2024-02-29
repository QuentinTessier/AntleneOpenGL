const std = @import("std");
const gl = @import("../gl4_6.zig");
const ReflectionType = @import("../Pipeline/ReflectionType.zig");

const TMPShaderIO = struct {
    name: []const u8,
    location: i32,
    type: ReflectionType.GLSLType,
};

pub fn shaderInput(allocator: std.mem.Allocator, program: u32, writer: anytype) !void {
    var nActiveResources: i32 = 0;
    gl.getProgramInterfaceiv(program, gl.PROGRAM_INPUT, gl.ACTIVE_RESOURCES, @ptrCast(&nActiveResources));
    var array = std.ArrayList(TMPShaderIO).init(allocator);
    defer {
        for (array.items) |item| {
            allocator.free(item.name);
        }
        array.deinit();
    }

    try writer.print("\tpub const Input: []const ReflectionType.ShaderInput = &.{{\n", .{});
    for (0..@intCast(nActiveResources)) |i| {
        const name = blk: {
            const name_length: i32 = name_length_blk: {
                const property: i32 = gl.NAME_LENGTH;
                var len: i32 = 0;

                gl.getProgramResourceiv(
                    program,
                    gl.PROGRAM_INPUT,
                    @intCast(i),
                    1,
                    @ptrCast(&property),
                    1,
                    null,
                    @ptrCast(&len),
                );
                break :name_length_blk len;
            };

            const name: []const u8 = name_blk: {
                const name_array = try allocator.alloc(u8, @intCast(name_length));
                gl.getProgramResourceName(
                    program,
                    gl.PROGRAM_INPUT,
                    @intCast(i),
                    @intCast(name_array.len),
                    null,
                    name_array.ptr,
                );
                break :name_blk name_array;
            };
            break :blk name;
        };
        try array.append(.{
            .name = name,
            .location = gl.getAttribLocation(program, name.ptr),
            .type = blk: {
                const property: i32 = gl.TYPE;
                var t: i32 = 0;

                gl.getProgramResourceiv(
                    program,
                    gl.PROGRAM_INPUT,
                    @intCast(i),
                    1,
                    @ptrCast(&property),
                    1,
                    null,
                    @ptrCast(&t),
                );
                break :blk @as(ReflectionType.GLSLType, @enumFromInt(t));
            },
        });
    }
    std.sort.insertion(TMPShaderIO, array.items, void{}, struct {
        pub fn order(_: void, lhs: TMPShaderIO, rhs: TMPShaderIO) bool {
            return lhs.location < rhs.location;
        }
    }.order);
    for (array.items) |item| {
        if (item.location == -1) continue;
        var buffer: [64]u8 = [1]u8{0} ** 64;
        const e = try std.fmt.bufPrint(&buffer, "{}", .{item.type});
        const index = std.mem.lastIndexOf(u8, e, ".") orelse 0;

        try writer.print("\t\t.{{ .name = \"{s}\", .location = {}, .type = {s} }},\n", .{ item.name[0 .. item.name.len - 1], item.location, e[index..] });
    }

    try writer.print("\t}};\n\n", .{});
}

pub fn shaderOutput(allocator: std.mem.Allocator, program: u32, writer: anytype) !void {
    var nActiveResources: i32 = 0;
    gl.getProgramInterfaceiv(program, gl.PROGRAM_OUTPUT, gl.ACTIVE_RESOURCES, @ptrCast(&nActiveResources));
    var array = std.ArrayList(TMPShaderIO).init(allocator);
    defer {
        for (array.items) |item| {
            allocator.free(item.name);
        }
        array.deinit();
    }

    try writer.print("\tpub const Output: []const ReflectionType.ShaderOutput = &.{{\n", .{});
    for (0..@intCast(nActiveResources)) |i| {
        const name = blk: {
            const name_length: i32 = name_length_blk: {
                const property: i32 = gl.NAME_LENGTH;
                var len: i32 = 0;

                gl.getProgramResourceiv(
                    program,
                    gl.PROGRAM_OUTPUT,
                    @intCast(i),
                    1,
                    @ptrCast(&property),
                    1,
                    null,
                    @ptrCast(&len),
                );
                break :name_length_blk len;
            };

            const name: []const u8 = name_blk: {
                const name_array = try allocator.alloc(u8, @intCast(name_length));
                gl.getProgramResourceName(
                    program,
                    gl.PROGRAM_OUTPUT,
                    @intCast(i),
                    @intCast(name_array.len),
                    null,
                    name_array.ptr,
                );
                break :name_blk name_array;
            };
            break :blk name;
        };
        try array.append(.{
            .name = name,
            .location = gl.getAttribLocation(program, name.ptr),
            .type = blk: {
                const property: i32 = gl.TYPE;
                var t: i32 = 0;

                gl.getProgramResourceiv(
                    program,
                    gl.PROGRAM_OUTPUT,
                    @intCast(i),
                    1,
                    @ptrCast(&property),
                    1,
                    null,
                    @ptrCast(&t),
                );
                break :blk @as(ReflectionType.GLSLType, @enumFromInt(t));
            },
        });
    }
    std.sort.insertion(TMPShaderIO, array.items, void{}, struct {
        pub fn order(_: void, lhs: TMPShaderIO, rhs: TMPShaderIO) bool {
            return lhs.location < rhs.location;
        }
    }.order);
    for (array.items) |item| {
        if (item.location == -1) continue;
        var buffer: [64]u8 = [1]u8{0} ** 64;
        const e = try std.fmt.bufPrint(&buffer, "{}", .{item.type});
        const index = std.mem.lastIndexOf(u8, e, ".") orelse 0;

        try writer.print("\t\t.{{ .name = \"{s}\", .location = {}, .type = {s} }},\n", .{ item.name[0 .. item.name.len - 1], item.location, e[index..] });
    }

    try writer.print("\t}};\n\n", .{});
}
