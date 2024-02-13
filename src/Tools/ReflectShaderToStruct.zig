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

pub fn reflectInterface(allocator: std.mem.Allocator, program: u32, interface: gl.GLenum) !std.StringArrayHashMapUnmanaged(u32) {
    var nActiveResources: i32 = 0;
    gl.getProgramInterfaceiv(program, interface, gl.ACTIVE_RESOURCES, @ptrCast(&nActiveResources));

    var resources: std.StringArrayHashMapUnmanaged(u32) = .{};
    for (0..@intCast(nActiveResources)) |i| {
        var name_length: i32 = 0;

        const property: i32 = gl.NAME_LENGTH;
        gl.getProgramResourceiv(
            program,
            interface,
            @intCast(i),
            1,
            @ptrCast(&property),
            1,
            null,
            @ptrCast(&name_length),
        );

        const name = try allocator.alloc(u8, @intCast(name_length));
        gl.getProgramResourceName(
            program,
            interface,
            @intCast(i),
            @intCast(name.len),
            null,
            name.ptr,
        );

        if (interface == gl.UNIFORM_BLOCK or interface == gl.SHADER_STORAGE_BLOCK) {
            const binding_property: i32 = gl.BUFFER_BINDING;
            var binding: i32 = -1;
            gl.getProgramResourceiv(
                program,
                interface,
                @intCast(i),
                1,
                @ptrCast(&binding_property),
                1,
                null,
                @ptrCast(&binding),
            );
            try resources.put(allocator, name, @intCast(binding));
        } else if (interface == gl.UNIFORM) {
            const location = gl.getProgramResourceLocation(program, interface, name.ptr);

            if (location >= 0) {
                try resources.put(allocator, name, @intCast(location));
            } else {
                allocator.free(name);
            }
        }
    }
    return resources;
}

pub fn reflect(allocator: std.mem.Allocator, namespace: []const u8, information: []const ShaderInformation, stream: *std.io.StreamSource) !void {
    var writer = stream.writer();
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

    var reflected = ReflectedProgram{
        .uniformBlocks = try reflectInterface(allocator, program, gl.UNIFORM_BLOCK),
        .shaderStorageBlocks = try reflectInterface(allocator, program, gl.SHADER_STORAGE_BLOCK),
        .samplers = try reflectInterface(allocator, program, gl.UNIFORM),
    };
    defer reflected.deinit(allocator);

    try writer.print("pub const {s} = struct {{\n", .{namespace});
    {
        var ite = reflected.shaderStorageBlocks.iterator();
        while (ite.next()) |entry| {
            try writer.print("\tpub const {s}: u32 = {};\n", .{ entry.key_ptr.*[0 .. entry.key_ptr.*.len - 1], entry.value_ptr.* });
        }
    }
    {
        var ite = reflected.uniformBlocks.iterator();
        while (ite.next()) |entry| {
            try writer.print("\tpub const {s}: u32 = {};\n", .{ entry.key_ptr.*[0 .. entry.key_ptr.*.len - 1], entry.value_ptr.* });
        }
    }
    {
        var ite = reflected.samplers.iterator();
        while (ite.next()) |entry| {
            try writer.print("\tpub const {s}: u32 = {};\n", .{ entry.key_ptr.*[0 .. entry.key_ptr.*.len - 1], entry.value_ptr.* });
        }
    }
    try writer.print("}};\n", .{});
}
