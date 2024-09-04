const std = @import("std");
const gl = @import("../gl4_6.zig");
const ShaderStage = @import("../Pipeline/PipelineInformation.zig").ShaderStage;
const ReflectionType = @import("../Pipeline/ReflectionType.zig");

pub const ShaderType = enum {
    glsl,
    spirv,
};

pub fn fromGLSLSource(stage: ShaderStage, source: []const u8) !u32 {
    const shader = gl.createShader(@intFromEnum(stage));

    gl.shaderSource(shader, 1, @ptrCast(&source.ptr), @ptrCast(&source.len));
    gl.compileShader(shader);

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

pub fn fromSPIRVSource(stage: ShaderStage, source: []const u8) !u32 {
    const shader = gl.createShader(@intFromEnum(stage));
    gl.shaderBinary(
        1,
        @ptrCast(&shader),
        gl.SHADER_BINARY_FORMAT_SPIR_V,
        source.ptr,
        @intCast(source.len),
    );
    gl.specializeShader(shader, "main", 0, null, null);

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

pub fn getGLSLShaderStage(path: []const u8) !ShaderStage {
    if (std.mem.endsWith(u8, path, ".vert")) {
        return .Vertex;
    } else if (std.mem.endsWith(u8, path, ".frag")) {
        return .Fragment;
    } else if (std.mem.endsWith(u8, path, ".comp")) {
        return .Compute;
    } else {
        return error.UnrecognizedGLSLExtension;
    }
}

pub fn getSPIRVShaderStage(path: []const u8) !ShaderStage {
    if (std.mem.startsWith(u8, path, "vert")) {
        return .Vertex;
    } else if (std.mem.startsWith(u8, path, "frag")) {
        return .Fragment;
    } else if (std.mem.startsWith(u8, path, "comp")) {
        return .Compute;
    } else {
        return error.UnrecognizedSPIRVExtension;
    }
}

pub fn fromGLSLFile(allocator: std.mem.Allocator, path: []const u8) !u32 {
    const stage = try getGLSLShaderStage(path);
    const source = blk: {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1_000_000);
        break :blk content;
    };
    defer allocator.free(source);

    return fromGLSLSource(stage, source);
}

pub fn fromGLSLFileKeepSource(allocator: std.mem.Allocator, path: []const u8) !struct { handle: u32, stage: ShaderStage, source: []const u8 } {
    const stage = try getGLSLShaderStage(path);
    const source = blk: {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1_000_000);
        break :blk content;
    };

    return .{
        .handle = try fromGLSLSource(stage, source),
        .stage = stage,
        .source = source,
    };
}

pub fn fromSPIRVFile(allocator: std.mem.Allocator, path: []const u8) !u32 {
    if (!std.mem.endsWith(u8, path, ".spv")) return error.UnrecognizedSPIRVExtension;

    const stage = blk: {
        const filename = filename_blk: {
            const index = if (std.mem.lastIndexOf(u8, path, "/")) |i| i + 1 else 0;
            break :filename_blk path[index..];
        };
        break :blk try getSPIRVShaderStage(filename);
    };

    const source = blk: {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1_000_000);
        break :blk content;
    };
    defer allocator.free(source);

    return fromSPIRVSource(stage, source);
}

pub fn fromSPIRVFileKeepSource(allocator: std.mem.Allocator, path: []const u8) !struct { handle: u32, stage: ShaderStage, source: []const u32 } {
    if (!std.mem.endsWith(u8, path, ".spv")) return error.UnrecognizedSPIRVExtension;

    const stage = blk: {
        const filename = filename_blk: {
            const index = if (std.mem.lastIndexOf(u8, path, "/")) |i| i + 1 else 0;
            break :filename_blk path[index..];
        };
        break :blk try getSPIRVShaderStage(filename);
    };

    const source = blk: {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const fileSize = try file.getEndPos();
        const content = try allocator.alloc(u32, @divExact(fileSize, 4));

        _ = try file.readAll(std.mem.sliceAsBytes(content));
        break :blk content;
    };

    return .{
        .handle = try fromSPIRVSource(stage, std.mem.sliceAsBytes(source)),
        .stage = stage,
        .source = source,
    };
}

pub fn fromFile(allocator: std.mem.Allocator, path: []const u8) !u32 {
    if (std.mem.endsWith(u8, path, ".spv")) {
        return fromSPIRVFile(allocator, path);
    } else {
        return fromGLSLFile(allocator, path);
    }
}

pub fn loadFile(allocator: std.mem.Allocator, comptime SourceType: ShaderType, path: []const u8) !(blk: {
    switch (SourceType) {
        .glsl => break :blk []u8,
        .spirv => break :blk []u32,
    }
}) {
    return switch (SourceType) {
        .glsl => blk: {
            var file = try std.fs.cwd().openFile(path, .{});
            defer file.close();

            const fileSize = try file.getEndPos();
            const content = try allocator.alloc(u8, fileSize + 1);
            _ = try file.readAll(std.mem.sliceAsBytes(content));
            content[fileSize] = 0;
            break :blk content;
        },
        .spirv => blk: {
            var file = try std.fs.cwd().openFile(path, .{});
            defer file.close();

            const fileSize = try file.getEndPos();
            const content = try allocator.alloc(u32, @divExact(fileSize, 4));

            _ = try file.readAll(std.mem.sliceAsBytes(content));
            break :blk content;
        },
    };
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
    return program;
}

pub fn getProgramFromReflected(comptime Reflection: type, allocator: std.mem.Allocator) !u32 {
    if (!@hasDecl(Reflection, "ShaderData")) @panic("All Reflection type should have a ShaderData declaration");

    const ShaderData = Reflection.ShaderData;
    if (@typeInfo(@TypeOf(ShaderData)) != .Array) @panic("All Reflection.ShaderData should be a slice of either ShaderPath or ShaderStorage");
    switch (@typeInfo(@TypeOf(ShaderData)).Array.child) {
        ReflectionType.ShaderPath => {
            var shaders: [ShaderData.len]u32 = [1]u32{0} ** ShaderData.len;
            errdefer {
                for (shaders) |shader| {
                    gl.deleteShader(shader);
                }
            }
            for (ShaderData, 0..) |path, i| {
                shaders[i] = try fromFile(allocator, path);
            }
            const program = try linkProgram(&shaders);
            for (shaders) |shader| {
                gl.deleteShader(shader);
            }
            return program;
        },
        ReflectionType.ShaderStorage => {
            var shaders: [ShaderData.len]u32 = [1]u32{0} ** ShaderData.len;
            errdefer {
                for (shaders) |shader| {
                    gl.deleteShader(shader);
                }
            }

            for (ShaderData, 0..) |storage, i| {
                shaders[i] = switch (storage.source) {
                    .glsl => try fromGLSLSource(storage.stage, storage.slice()),
                    .spirv => try fromSPIRVSource(storage.stage, storage.slice()),
                };
            }
            const program = try linkProgram(&shaders);
            for (shaders) |shader| {
                gl.deleteShader(shader);
            }
            return program;
        },
        else => @panic("Invalid ShaderData type"),
    }
}
