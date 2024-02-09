const std = @import("std");

pub fn build(b: *std.Build, _: std.Build.ResolvedTarget, _: std.builtin.OptimizeMode) void {
    const opengl_module = b.addModule("opengl_4_6", .{
        .root_source_file = .{ .path = "dependencies/gl/gl4_6.zig" },
    });

    const antlene_opengl_module = b.addModule("AntleneOpenGL", .{
        .root_source_file = .{ .path = "src/main.zig" },
    });

    antlene_opengl_module.addImport("gl", opengl_module);
}
