const std = @import("std");
const Builder = @import("Builder.zig");

const Resource = @This();

pub const ResourceType = enum {
    Texture,
    Buffer,
};

pub const Ref = struct {
    index: usize,
    generation: u32,
};

builder: *Builder,
type: ResourceType,
name: []const u8,
generations: u32,

pub fn ref(self: *Resource) Ref {
    self.generations += 1;
    return .{
        .index = 0,
        .generation = self.generations,
    };
}
