const std = @import("std");
const gl = @import("../gl4_6.zig");
const PipelineVertexInputState = @import("../Pipeline/PipelineInformation.zig").PipelineVertexInputState;

const VertexArrayObject = @This();

handle: u32,
hash: u64,

pub inline fn hash(vertexInputState: PipelineVertexInputState) u64 {
    const bytes = std.mem.sliceAsBytes(vertexInputState.vertexAttributeDescription);
    return std.hash.Murmur2_64.hash(bytes);
}

pub fn init(vertexInputState: PipelineVertexInputState) VertexArrayObject {
    var vertexArrayObject: u32 = 0;
    gl.createVertexArrays(1, @ptrCast(&vertexArrayObject));

    for (vertexInputState.vertexAttributeDescription) |input| {
        std.log.info("VertexArrayObject({}) : layout(location = {}) {}x{}", .{ vertexArrayObject, input.location, input.format, input.size });
        gl.enableVertexArrayAttrib(vertexArrayObject, input.location);
        gl.vertexArrayAttribBinding(vertexArrayObject, input.location, input.binding);
        gl.vertexArrayAttribFormat(vertexArrayObject, input.location, @intCast(input.size), @intFromEnum(input.format), gl.FALSE, input.offset);
    }

    return .{
        .handle = vertexArrayObject,
        .hash = hash(vertexInputState),
    };
}

pub inline fn deinit(self: VertexArrayObject) void {
    gl.deleteVertexArrays(1, @ptrCast(&self.handle));
}
