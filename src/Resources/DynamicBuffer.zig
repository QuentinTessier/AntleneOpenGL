const std = @import("std");
const gl = @import("../gl4_6.zig");
const Buffer = @import("./Buffer.zig");

pub const DynamicBuffer = @This();

handle: u32,
size: usize,
stride: usize = 0,

pub fn init(name: ?[]const u8, data: []const u8, stride: usize) DynamicBuffer {
    var buffer: DynamicBuffer = std.mem.zeroInit(DynamicBuffer, .{
        .size = data.len,
        .stride = stride,
    });

    gl.createBuffers(1, @ptrCast(&buffer.handle));
    gl.namedBufferStorage(buffer.handle, @intCast(data.len), data.ptr, gl.DYNAMIC_STORAGE_BIT);

    if (name) |label| {
        gl.objectLabel(gl.BUFFER, buffer.handle, @intCast(label.len), label.ptr);
    }

    return buffer;
}

pub fn initEmpty(name: ?[]const u8, size: usize, stride: usize) DynamicBuffer {
    var buffer: DynamicBuffer = std.mem.zeroInit(DynamicBuffer, .{
        .size = size,
        .stride = stride,
    });

    gl.createBuffers(1, @ptrCast(&buffer.handle));
    gl.namedBufferStorage(buffer.handle, @intCast(size), null, gl.DYNAMIC_STORAGE_BIT);

    if (name) |label| {
        gl.objectLabel(gl.BUFFER, buffer.handle, @intCast(label.len), label.ptr);
    }

    return buffer;
}

pub fn deinit(self: DynamicBuffer) void {
    gl.deleteBuffers(1, @ptrCast(&self.handle));
}

pub fn update(self: *DynamicBuffer, data: []const u8, offset: usize) void {
    std.debug.assert(offset + data.len <= self.size);

    gl.namedBufferSubData(self.handle, @intCast(offset), @intCast(data.len), data.ptr);
}

pub fn toBuffer(self: DynamicBuffer) Buffer {
    return .{
        .handle = self.handle,
        .size = self.size,
        .stride = self.stride,
    };
}
