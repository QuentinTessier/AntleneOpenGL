const std = @import("std");
const gl = @import("../gl4_6.zig");

pub const MaxPushGroupMessageSize = 512;
var isGroupPushed: bool = false;

pub fn fmtPush(id: u32, comptime fmt: []const u8, args: anytype) !void {
    if (isGroupPushed) {
        gl.popDebugGroup();
        isGroupPushed = false;
    }

    const buffer: [MaxPushGroupMessageSize]u8 = [1]u8{0} ** MaxPushGroupMessageSize;
    const slice = try std.fmt.bufPrint(buffer, fmt, args);

    gl.pushDebugGroup(gl.DEBUG_SOURCE_APPLICATION, id, @intCast(slice.len), slice.ptr);
    isGroupPushed = true;
}

pub fn push(id: u32, message: []const u8) void {
    gl.pushDebugGroup(gl.DEBUG_SOURCE_APPLICATION, id, @intCast(message.len), message.ptr);
    isGroupPushed = true;
}

pub fn pop() void {
    gl.popDebugGroup();
}
