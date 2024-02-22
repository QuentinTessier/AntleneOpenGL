const std = @import("std");
const gl = @import("../gl4_6.zig");

pub const ReflectedProgram = struct {
    uniformBlocks: std.StringArrayHashMapUnmanaged(u32) = .{},
    shaderStorageBlocks: std.StringArrayHashMapUnmanaged(u32) = .{},
    samplers: std.StringArrayHashMapUnmanaged(u32) = .{},

    pub fn deinit(self: *ReflectedProgram, allocator: std.mem.Allocator) void {
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
};

pub const ShaderSource = union(enum(u32)) {
    glsl: []const u8,
    spirv: []const u8,
};

pub const ShaderStage = enum(u32) {
    vertex = gl.VERTEX_SHADER,
    fragment = gl.FRAGMENT_SHADER,

    compute = gl.COMPUTE_SHADER,
};

pub const ShaderInformation = struct {
    stage: ShaderStage,
    source: ShaderSource,
};

pub fn compileShader(stage: u32, source: ShaderSource) !u32 {
    const shader = gl.createShader(stage);
    switch (source) {
        .spirv => |spirv| {
            gl.shaderBinary(
                1,
                @ptrCast(&shader),
                gl.SHADER_BINARY_FORMAT_SPIR_V,
                spirv.ptr,
                @intCast(spirv.len),
            );
            gl.specializeShader(shader, "main", 0, null, null);
        },
        .glsl => |glsl| {
            gl.shaderSource(shader, 1, @ptrCast(&glsl.ptr), null);
            gl.compileShader(shader);
        },
    }

    var success: i32 = 0;
    gl.getShaderiv(shader, gl.COMPILE_STATUS, @ptrCast(&success));
    if (success != gl.TRUE) {
        var buffer: [1024]u8 = undefined;
        gl.getShaderInfoLog(shader, 1024, null, (&buffer).ptr);
        std.log.err("{s}", .{buffer});
        return error.FailedShaderCompilation;
    }

    return shader;
}

pub fn linkProgram(shaders: []const u32) !u32 {
    const program = gl.createProgram();
    for (shaders) |shader| {
        gl.attachShader(program, shader);
    }
    gl.linkProgram(program);
    {
        var success: i32 = 0;
        gl.getProgramiv(program, gl.LINK_STATUS, &success);
        if (success != gl.TRUE) {
            var size: isize = 0;
            var buffer: [1024]u8 = undefined;
            gl.getProgramInfoLog(program, 1024, @ptrCast(&size), (&buffer).ptr);
            std.log.err("Failed to link program: {s}", .{buffer[0..@intCast(size)]});
            return error.ProgramLinkingFailed;
        }
    }
    for (shaders) |shader| {
        gl.deleteShader(shader);
    }
    return program;
}

pub fn reflectShaderStorageBlock(allocator: std.mem.Allocator, program: u32, writer: anytype) !void {
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

pub fn reflectUniformBlock(allocator: std.mem.Allocator, program: u32, writer: anytype) !void {
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

pub fn reflectSamplers(allocator: std.mem.Allocator, program: u32, writer: anytype) !void {
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

        const location = gl.getProgramResourceLocation(program, gl.UNIFORM, name.ptr);
        if (location >= 0) {
            try writer.print("\t\tpub const {s}: ReflectionType.UniformBufferBinding = .{{ .binding = {} }};\n", .{ name[0 .. name.len - 1], location });
        }
    }
    try writer.print("\t}};\n\n", .{});
}

pub fn reflect(allocator: std.mem.Allocator, namespace: []const u8, library_name: []const u8, information: []const ShaderInformation, writer: anytype) !void {
    var shaders = try allocator.alloc(u32, information.len);
    for (information, 0..) |info, index| {
        shaders[index] = try compileShader(@intFromEnum(info.stage), info.source);
    }
    defer {
        for (shaders) |shader| {
            gl.deleteShader(shader);
        }
        allocator.free(shaders);
    }

    const program = try linkProgram(shaders);
    defer gl.deleteProgram(program);

    try writer.print("const ReflectionType = @import(\"{s}\").ReflectionType;\n\n", .{library_name});
    try writer.print("pub const {s} = struct {{\n", .{namespace});

    {
        try reflectShaderStorageBlock(allocator, program, writer);
    }

    {
        try reflectUniformBlock(allocator, program, writer);
    }

    {
        try reflectSamplers(allocator, program, writer);
    }

    try writer.print("}};\n", .{});
}
