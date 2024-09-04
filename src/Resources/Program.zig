const std = @import("std");
const gl = @import("../gl4_6.zig");
const ReflectionType = @import("../Pipeline/ReflectionType.zig");

pub const Program = @This();

handle: u32,
vertexInput: []ProgramInput,

// TODO: SPIRV Specialization
pub const ShaderSource = union(enum(u32)) {
    glsl: []const u8,
    spirv: []const u32,

    pub fn len(self: ShaderSource) usize {
        return switch (self) {
            .glsl => |glsl| glsl.len,
            .spirv => |spirv| spirv.len * 4,
        };
    }

    pub fn slice(self: ShaderSource) []const u8 {
        return switch (self) {
            .glsl => |glsl| glsl,
            .spirv => |spirv| std.mem.sliceAsBytes(spirv),
        };
    }
};

pub const ProgramStages = struct {
    vertex: ShaderSource,
    geometry: ?ShaderSource = null,
    tesselation: ?struct {
        control: ShaderSource,
        evaluation: ShaderSource,
    } = null,
    fragment: ShaderSource,
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

pub fn init(stages: ProgramStages) !Program {
    const vertex = try compileShader(gl.VERTEX_SHADER_BIT, stages.vertex);
    const fragment = try compileShader(gl.FRAGMENT_SHADER_BIT, stages.fragment);

    const geometry: ?u32 = if (stages.geometry) |geometry| try compileShader(gl.GEOMETRY_SHADER_BIT, geometry) else null;
    const control: ?u32 = if (stages.tesselation) |tess| try compileShader(gl.TESS_CONTROL_SHADER_BIT, tess.control) else null;
    const evaluation: ?u32 = if (stages.tesselation) |tess| try compileShader(gl.TESS_CONTROL_SHADER_BIT, tess.evaluation) else null;

    const handle = gl.createProgram();

    gl.attachShader(handle, vertex);
    gl.attachShader(handle, fragment);

    if (geometry) |g| gl.attachShader(handle, g);
    if (control) |c| gl.attachShader(handle, c);
    if (evaluation) |e| gl.attachShader(handle, e);

    gl.linkProgram(handle);
    {
        var success: i32 = 0;
        gl.getProgramiv(handle, gl.LINK_STATUS, &success);
        if (success != gl.TRUE) {
            var size: isize = 0;
            var buffer: [1024]u8 = undefined;
            gl.getProgramInfoLog(handle, 1024, @ptrCast(&size), (&buffer).ptr);
            std.log.err("Failed to link program: {s}", .{buffer[0..@intCast(size)]});
            return error.ProgramLinkingFailed;
        }
    }

    gl.deleteShader(vertex);
    gl.deleteShader(fragment);
    gl.deleteShader(if (geometry) |g| g else 0);
    gl.deleteShader(if (control) |c| c else 0);
    gl.deleteShader(if (evaluation) |e| e else 0);
    return .{
        .handle = handle,
        .reflection = void{},
    };
}

pub const ProgramInput = struct {
    location: u32,
    type: ReflectionType.GLSLType,
    offset: u32,
};

fn reflectInput(allocator: std.mem.Allocator, handle: u32) []ProgramInput {
    var active: i32 = 0;
    var name: [256]u8 = [1]u8{0} ** 256;
    gl.getProgramInterfaceiv(handle, gl.PROGRAM_INPUT, gl.ACTIVE_RESOURCES, @ptrCast(&active));

    if (active == 0) return &.{};

    const array = std.ArrayList(ProgramInput).initCapacity(allocator, @intCast(active));
    for (0..@intCast(active)) |i| {
        const length: i32 = 0;
        gl.getProgramResourceName(
            handle,
            gl.PROGRAM_INPUT,
            @intCast(i),
            255,
            @ptrCast(&length),
            (&name).ptr,
        );

        const location: i32 = gl.getAttribLocation(handle, (&name).ptr);
        const dataType: i32 = blk: {
            const property: i32 = gl.TYPE;
            var t: i32 = 0;

            gl.getProgramResourceiv(
                handle,
                gl.PROGRAM_INPUT,
                @intCast(i),
                1,
                @ptrCast(&property),
                1,
                null,
                @ptrCast(&t),
            );
            break :blk @as(ReflectionType.GLSLType, @enumFromInt(t));
        };
    }
}
