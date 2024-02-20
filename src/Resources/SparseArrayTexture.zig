const std = @import("std");
const gl = @import("../gl4_6.zig");
const glSparseTexture = gl.GL_ARB_sparse_texture;

pub const SparseArrayTexture = @This();

handle: u32,
size: usize,
level: usize,

pub const DefaultMaxLevel: usize = 4;

fn isValidTile(i: f32, j: f32, x: f32, y: f32) bool {
    const a = @Vector(2, f32){ i, j };
    const b = @Vector(2, f32){ x, y };
    const c = a / b * @Vector(2, f32){ 2.0, 2.0 } + @Vector(2, f32){ 1.0, 1.0 };
    const l = @sqrt(c[0] * c[0] + c[1] * c[1]);
    return @abs(l) > 1.0;
}

pub fn init(allocator: std.mem.Allocator, size: usize) !SparseArrayTexture {
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    defer gl.pixelStorei(gl.UNPACK_ALIGNMENT, 4);

    var handle: u32 = 0;
    gl.createTextures(gl.TEXTURE_2D_ARRAY, 1, @ptrCast(&handle));
    gl.textureParameteri(handle, gl.TEXTURE_SWIZZLE_R, gl.RED);
    gl.textureParameteri(handle, gl.TEXTURE_SWIZZLE_G, gl.GREEN);
    gl.textureParameteri(handle, gl.TEXTURE_SWIZZLE_B, gl.BLUE);
    gl.textureParameteri(handle, gl.TEXTURE_SWIZZLE_A, gl.ALPHA);

    gl.textureParameteri(handle, gl.TEXTURE_BASE_LEVEL, 0);
    gl.textureParameteri(handle, gl.TEXTURE_MAX_LEVEL, @intCast(DefaultMaxLevel - 1));
    gl.textureParameteri(handle, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_NEAREST);
    gl.textureParameteri(handle, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.textureParameteri(handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.textureParameteri(handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.textureParameteri(handle, glSparseTexture.TEXTURE_SPARSE_ARB, gl.TRUE);

    const mip_complete_level: usize = @as(usize, @intFromFloat(@log2(@as(f32, @floatFromInt(size))))) + 1;
    gl.textureStorage3D(handle, @intCast(mip_complete_level), gl.RGBA8, @intCast(size), @intCast(size), 1);

    var pageSize: @Vector(3, i32) = .{ 0, 0, 0 };
    gl.getInternalformativ(gl.TEXTURE_2D_ARRAY, gl.RGBA8, glSparseTexture.VIRTUAL_PAGE_SIZE_X_ARB, 1, @ptrCast(&pageSize[0]));
    gl.getInternalformativ(gl.TEXTURE_2D_ARRAY, gl.RGBA8, glSparseTexture.VIRTUAL_PAGE_SIZE_Y_ARB, 1, @ptrCast(&pageSize[1]));
    gl.getInternalformativ(gl.TEXTURE_2D_ARRAY, gl.RGBA8, glSparseTexture.VIRTUAL_PAGE_SIZE_Z_ARB, 1, @ptrCast(&pageSize[2]));

    const pages = try allocator.alloc(@Vector(4, u8), @intCast(@reduce(.Add, pageSize)));
    defer allocator.free(pages);

    var page3DSizeX: i32 = 0;
    var page3DSizeY: i32 = 0;
    var page3DSizeZ: i32 = 0;
    gl.getInternalformativ(gl.TEXTURE_3D, gl.RGBA32F, glSparseTexture.VIRTUAL_PAGE_SIZE_X_ARB, 1, @ptrCast(&page3DSizeX));
    gl.getInternalformativ(gl.TEXTURE_3D, gl.RGBA32F, glSparseTexture.VIRTUAL_PAGE_SIZE_Y_ARB, 1, @ptrCast(&page3DSizeY));
    gl.getInternalformativ(gl.TEXTURE_3D, gl.RGBA32F, glSparseTexture.VIRTUAL_PAGE_SIZE_Z_ARB, 1, @ptrCast(&page3DSizeZ));

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D_ARRAY, handle);

    var l: usize = 0;
    while (l < DefaultMaxLevel) : (l += 1) {
        const levelSize = size >> @as(u6, @intCast(l));
        const tileCountY = @divFloor(levelSize, @as(usize, @intCast(pageSize[1])));
        const tileCountX = @divFloor(levelSize, @as(usize, @intCast(pageSize[0])));

        for (0..tileCountY) |j| {
            for (0..tileCountX) |i| {
                if (isValidTile(@floatFromInt(i), @floatFromInt(j), @floatFromInt(tileCountX), @floatFromInt(tileCountY))) continue;

                for (pages) |*page| {
                    const x: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(levelSize / @as(usize, @intCast(pageSize[0]))));
                    const y: f32 = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(levelSize / @as(usize, @intCast(pageSize[1]))));
                    const z: f32 = @as(f32, @floatFromInt(l)) / @as(f32, @floatFromInt(DefaultMaxLevel));
                    page.* = .{
                        @as(u8, @intFromFloat(x)) * 255,
                        @as(u8, @intFromFloat(y)) * 255,
                        @as(u8, @intFromFloat(z)) * 255,
                        255,
                    };
                    glSparseTexture.texPageCommitmentARB(
                        gl.TEXTURE_2D_ARRAY,
                        @intCast(l),
                        @intCast(@as(usize, @intCast(pageSize[0])) * i),
                        @intCast(@as(usize, @intCast(pageSize[1])) * j),
                        0,
                        @intCast(pageSize[0]),
                        @intCast(pageSize[1]),
                        1,
                        gl.TRUE,
                    );
                    gl.textureSubImage3D(
                        handle,
                        @intCast(l),
                        @intCast(@as(usize, @intCast(pageSize[0])) * i),
                        @intCast(@as(usize, @intCast(pageSize[1])) * j),
                        0,
                        @intCast(pageSize[0]),
                        @intCast(pageSize[1]),
                        1,
                        gl.RGBA,
                        gl.UNSIGNED_BYTE,
                        @ptrCast(&pages[0][0]),
                    );
                }
            }
        }
    }
    return .{
        .handle = handle,
        .size = size,
        .level = DefaultMaxLevel,
    };
}

pub fn deinit(self: SparseArrayTexture) void {
    gl.deleteTextures(1, @ptrCast(&self.handle));
}
