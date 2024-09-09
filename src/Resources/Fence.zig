const std = @import("std");
const gl = @import("../gl4_6.zig");

pub const Fence = @This();

handle: gl.GLsync,

pub fn init() Fence {
    return gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0);
}

pub fn deinit(self: Fence) void {
    gl.deleteSync(self.handle);
}

pub fn wait(self: Fence, timeout: ?u64) void {
    const t = if (timeout) |x| x else gl.TIMEOUT_IGNORED;

    gl.waitSync(self.handle, 0, t);
}

pub const ClientWait = enum {
    AlreadySignaled,
    TimeoutExpired,
    ConditionSatisfied,
    Failed,
};

pub fn clientWait(self: Fence, timeout: u64) ClientWait {
    return switch (gl.clientWaitSync(self.handle, gl.SYNC_FLUSH_COMMANDS_BIT, timeout)) {
        gl.ALREADY_SIGNALED => .AlreadySignaled,
        gl.TIMEOUT_EXPIRED => .TimeoutExpired,
        gl.CONDITION_SATISFIED => .ConditionSatisfied,
        gl.WAIT_FAILED => .Failed,
    };
}
