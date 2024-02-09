const std = @import("std");
const gl = @import("../gl4_6.zig");

const BufferStorageFlags = packed struct(u8) {
    dynamic: bool = false,
    client: bool = false,
    map: bool = false,
    __unused0: u5 = 0,

    pub fn toGL(self: BufferStorageFlags) gl.GLenum {
        var flags: gl.GLenum = 0;
        flags |= if (self.dynamic) gl.DYNAMIC_STORAGE_BIT else 0;
        flags |= if (self.client) gl.CLIENT_STORAGE_BIT else 0;
        if (self.map) {
            flags |= gl.MAP_READ_BIT | gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
        }
        return flags;
    }
};

pub const Buffer = @This();

handle: u32,
size: usize,
stride: usize = 0,
storageFlags: BufferStorageFlags,
mappedMemory: ?[*]u8 = null,

pub fn init(name: ?[]const u8, data: ?[]const u8, flags: BufferStorageFlags) Buffer {
    var buffer: Buffer = std.mem.zeroInit(Buffer, .{
        .storageFlags = flags,
        .size = if (data) |_| data.?.len else @as(usize, 0),
    });
    const glFlags = flags.toGL();
    const ptr = if (data) |_| data.?.ptr else null;

    gl.createBuffers(1, @ptrCast(&buffer.handle));
    gl.namedBufferStorage(buffer.handle, @intCast(buffer.size), ptr, glFlags);
    if (flags.map) {
        const access = gl.MAP_READ_BIT | gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
        buffer.mappedMemory = @ptrCast(gl.mapNamedBufferRange(buffer.handle, 0, @intCast(buffer.size), access));
    }

    if (name) |label| {
        gl.objectLabel(gl.BUFFER, buffer.handle, @intCast(label.len), label.ptr);
    }
    return buffer;
}

pub fn typedInit(name: ?[]const u8, comptime T: type, data: ?[]const T, flags: BufferStorageFlags) Buffer {
    var buffer: Buffer = std.mem.zeroInit(Buffer, .{
        .storageFlags = flags,
        .size = if (data) |_| data.?.len * @sizeOf(T) else @as(usize, 0),
        .stride = @sizeOf(T),
    });
    const glFlags = flags.toGL();
    const ptr = if (data) |_| data.?.ptr else null;

    gl.createBuffers(1, @ptrCast(&buffer.handle));
    gl.namedBufferStorage(buffer.handle, @intCast(buffer.size), ptr, glFlags);
    if (flags.map) {
        const access = gl.MAP_READ_BIT | gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
        buffer.mappedMemory = @ptrCast(gl.mapNamedBufferRange(buffer.handle, 0, @intCast(buffer.size), access));
    }

    if (name) |label| {
        gl.objectLabel(gl.BUFFER, buffer.handle, @intCast(label.len), label.ptr);
    }
    return buffer;
}

pub fn deinit(self: *Buffer) void {
    if (self.mappedMemory) |_| {
        _ = gl.unmapNamedBuffer(self.handle);
    }
    gl.deleteBuffers(1, @ptrCast(&self.handle));
}

pub fn updateData(self: *Buffer, data: []const u8, offset: usize) void {
    std.debug.assert(self.storageFlags.dynamic);
    std.debug.assert(data.len + offset <= self.size);
    gl.namedBufferSubData(self.handle, @intCast(offset), @intCast(data.len), data.ptr);
}
