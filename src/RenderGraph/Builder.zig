const std = @import("std");
const Pass = @import("Pass.zig");
pub const Resource = @import("Resource.zig");

pub const RenderGraphBuilder = @This();

allocator: std.mem.Allocator,

passes: std.ArrayListUnmanaged(Pass) = .{},
passNameToIndex: std.StringHashMapUnmanaged(usize) = .{},

resources: std.ArrayListUnmanaged(Resource) = .{},
resourcesNameToIndex: std.StringArrayHashMapUnmanaged(usize) = .{},

finalNode: ?usize,
executionList: std.ArrayListUnmanaged(*Pass) = .{},

pub fn init(allocator: std.mem.Allocator) RenderGraphBuilder {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *RenderGraphBuilder) void {
    for (self.passes.items) |*p| {
        p.deinit();
    }
    self.passes.deinit(self.allocator);
    self.passNameToIndex.deinit(self.allocator);

    self.resources.deinit(self.allocator);
    self.resourcesNameToIndex.deinit(self.allocator);

    self.executionList.deinit(self.allocator);
}

pub fn getResource(self: *RenderGraphBuilder, name: []const u8) ?*Resource {
    return if (self.resourcesNameToIndex.get(name)) |index| &self.resources.items[index] else null;
}

pub fn texture(self: *RenderGraphBuilder, name: []const u8) !*Resource {
    const index = self.resources.items.len;
    const ptr = try self.resources.addOne(self.allocator);

    try self.resourcesNameToIndex.put(self.allocator, name, index);
    ptr.* = .{
        .builder = self,
        .name = name,
        .generations = 0,
        .type = .Texture,
    };
    return ptr;
}

pub fn buffer(self: *RenderGraphBuilder, name: []const u8) !*Resource {
    const index = self.resources.items.len;
    const ptr = try self.resources.addOne(self.allocator);

    try self.resourcesNameToIndex.put(self.allocator, name, index);
    ptr.* = .{
        .builder = self,
        .name = name,
        .generations = 0,
        .type = .Buffer,
    };
    return ptr;
}

pub fn getPass(self: *RenderGraphBuilder, name: []const u8) ?*Pass {
    return if (self.passNameToIndex.get(name)) |index| &self.passes.items[index] else null;
}

pub fn getPassIndex(self: *RenderGraphBuilder, name: []const u8) ?usize {
    return self.passNameToIndex.get(name);
}

pub fn pass(self: *RenderGraphBuilder, name: []const u8) !*Pass {
    const index = self.passes.items.len;
    const ptr = try self.passes.addOne(self.allocator);

    try self.passNameToIndex.put(self.allocator, name, index);
    ptr.* = Pass{
        .builder = self,
        .name = name,
    };
    return ptr;
}

pub fn setFinalNode(self: *RenderGraphBuilder, p: *const Pass) void {
    const index = self.passNameToIndex.get(p.name) orelse unreachable;
    self.finalNode = index;
}

fn findChildPassFromResourceGeneration(self: *RenderGraphBuilder, index: usize, in: Resource.Ref) ?usize {
    for (self.passes.items, 0..) |p, i| {
        if (i == index) continue;

        for (p.output.items) |out| {
            if (out.index == in.index and out.generation == in.generation - 1) return i;
        }
    }
    return null;
}

fn resolvePassDependencies(self: *RenderGraphBuilder, index: usize, p: *Pass) !void {
    for (p.input.items) |in| {
        const found_index = self.findChildPassFromResourceGeneration(index, in);
        if (found_index != null and !p.hasDependency(found_index.?)) {
            try p.dependencies.append(self.allocator, found_index.?);
        }
    }
}

fn buildDependencyGraph(self: *RenderGraphBuilder) !void {
    for (self.passes.items, 0..) |p, i| {
        try self.resolvePassDependencies(i, p);
    }
}

fn topologicalSortRecurse(self: *RenderGraphBuilder, visited: []bool, index: usize, p: *Pass, stack: *std.ArrayList(usize)) !void {
    visited[index] = true;

    for (p.dependencies) |dep| {
        if (!visited[dep]) {
            try self.topologicalSortRecurse(visited, dep, self.passes.items[dep], stack);
        } else {
            std.log.err("Found a circular dependency for pass {s}", .{self.passes.items[dep].name});
            return error.CircularDependency;
        }
    }
    try stack.insert(0, index);
}

fn topologicalSort(self: *RenderGraphBuilder) !void {
    if (self.finalNode == null) return error.NoFinalNode;

    const visited: []bool = try self.allocator.alloc(bool, self.passes.items.len);
    var stack = std.ArrayList(usize).init(self.allocator);
    errdefer {
        self.allocator.destroy(visited);
        stack.deinit();
    }

    @memset(visited, false);

    try self.topologicalSortRecurse(visited, self.finalNode.?, &self.passes.items[self.finalNode.?], &stack);

    while (stack.popOrNull()) |index| {
        self.executionList.append(self.allocator, &self.passes.items[index]);
    }

    self.allocator.destroy(visited);
    stack.deinit();
}

pub fn build(self: *RenderGraphBuilder) !void {
    try self.buildDependencyGraph();
    try self.topologicalSort();
}
