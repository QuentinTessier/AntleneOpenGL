const std = @import("std");
const Builder = @import("Builder.zig");

pub const Pass = @This();

builder: *Builder,
name: []const u8,

input: std.ArrayListUnmanaged(Builder.Resource.Ref) = .{},
output: std.ArrayListUnmanaged(Builder.Resource.Ref) = .{},
dependencies: std.ArrayListUnmanaged(usize) = .{},

pub fn deinit(self: *Pass) void {
    self.input.deinit(self.builder.allocator);
    self.output.deinit(self.builder.allocator);
    self.dependencies.deinit(self.builder.allocator);
}

pub fn read(self: *Pass, resource: *Builder.Resource) !void {
    const ref = resource.ref();

    try self.input.append(self.builder.allocator, ref);
}

pub fn write(self: *Pass, resource: *Builder.Resource) !void {
    const ref = resource.ref();

    try self.input.append(self.builder.allocator, ref);
    try self.output.append(self.builder.allocator, ref);
}

pub fn hasDependency(self: *const Pass, index: usize) bool {
    for (self.dependencies.items) |d| {
        if (d == index) return true;
    }
    return false;
}
