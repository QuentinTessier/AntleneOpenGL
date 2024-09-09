const std = @import("std");
const gl = @import("../gl4_6.zig");
const Buffer = @import("./Buffer.zig");

pub const MappedBuffer = @This();

pub const Flags = packed struct(u8) {
    read: bool = false,
    write: bool = false,
    explicitFlush: bool = false,
    unsynchronized: bool = false,

    pub fn toNamedBufferStorage(self: Flags) u32 {
        var flagsGL: u32 = gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;

        if (self.read) {
            flagsGL |= gl.MAP_READ_BIT;
        } else if (self.write) {
            flagsGL |= gl.MAP_WRITE_BIT;
        }
    }

    pub fn toMapNamedBuffer(self: Flags) u32 {
        var flagsGL: u32 = gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;

        if (self.read) {
            flagsGL |= gl.MAP_READ_BIT;
        } else if (self.write) {
            flagsGL |= gl.MAP_WRITE_BIT;
        } else if (self.explicitFlush) {
            flagsGL |= gl.MAP_FLUSH_EXPLICIT_BIT;
        } else if (self.unsynchronized) {
            flagsGL |= gl.MAP_UNSYNCHRONIZED_BIT;
        }

        return flagsGL;
    }
};

handle: u32,
size: usize,
stride: usize = 0,
flags: Flags,
ptr: [*]u8,

pub fn init(name: ?[]const u8, comptime T: type, data: []const T, flags: Flags) !MappedBuffer {
    var buffer: MappedBuffer = std.mem.zeroInit(MappedBuffer, .{
        .flags = flags,
        .size = data.len * @sizeOf(T),
        .stride = @sizeOf(T),
    });

    gl.createBuffers(1, @ptrCast(&buffer.handle));
    gl.namedBufferStorage(buffer.handle, @intCast(data.len * @sizeOf(T)), data.ptr, flags.toNamedBufferStorage());

    const ptr = gl.mapNamedBuffer(buffer.handle, flags.toMapNamedBuffer());
    if (ptr == null) {
        gl.deleteBuffers(1, @ptrCast(&buffer.handle));
        return error.FailedToMap;
    }

    buffer.ptr = ptr.?;
    if (name) |label| {
        gl.objectLabel(gl.BUFFER, buffer.handle, @intCast(label.len), label.ptr);
    }

    return buffer;
}

pub fn initEmpty(name: ?[]const u8, comptime T: type, count: usize, flags: Flags) !MappedBuffer {
    var buffer: MappedBuffer = std.mem.zeroInit(MappedBuffer, .{
        .flags = flags,
        .size = count * @sizeOf(T),
        .stride = @sizeOf(T),
    });

    const glFlags = flags.toGL();
    gl.createBuffers(1, @ptrCast(&buffer.handle));
    gl.namedBufferStorage(buffer.handle, @intCast(count * @sizeOf(T)), null, glFlags);

    const ptr = gl.mapNamedBuffer(buffer.handle, glFlags);
    if (ptr == null) {
        gl.deleteBuffers(1, @ptrCast(&buffer.handle));
        return error.FailedToMap;
    }

    buffer.ptr = ptr.?;
    if (name) |label| {
        gl.objectLabel(gl.BUFFER, buffer.handle, @intCast(label.len), label.ptr);
    }

    return buffer;
}

pub fn deinit(self: MappedBuffer) void {
    gl.unmapBuffer(self.handle);
    gl.deleteBuffers(1, @ptrCast(&self.handle));
}

pub fn cast(self: MappedBuffer, comptime T: type) []T {
    const count = @divExact(self.size, @sizeOf(T));

    const ptr: [*]T = @ptrCast(@alignCast(self.ptr));
    return ptr[0..count];
}

pub fn toBuffer(self: MappedBuffer) Buffer {
    return .{
        .handle = self.handle,
        .size = self.size,
        .stride = self.stride,
    };
}
