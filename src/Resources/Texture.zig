const std = @import("std");
const gl = @import("gl");

pub const Texture = @This();

fn Extent(comptime T: type) type {
    return struct {
        width: T,
        height: T,
        depth: T,
    };
}

handle: u32,
bindlessHandle: u64 = 0,
createInfo: TextureCreateInfo,

pub const Format = enum(u32) {
    r8 = gl.R8,
    r8_snorm = gl.R8_SNORM,
    r16 = gl.R16,
    r16_snorm = gl.R16_SNORM,
    rg8 = gl.RG8,
    rg8_snorm = gl.RG8_SNORM,
    rg16 = gl.RG16,
    rg16_snorm = gl.RG16_SNORM,
    r3_g3_b2 = gl.R3_G3_B2,
    rgb4 = gl.RGB4,
    rgb5 = gl.RGB5,
    rgb8 = gl.RGB8,
    rgb8_snorm = gl.RGB8_SNORM,
    rgb10 = gl.RGB10,
    rgb12 = gl.RGB12,
    rgb16_snorm = gl.RGB16_SNORM,
    rgba2 = gl.RGBA2,
    rgba4 = gl.RGBA4,
    rgb5_a1 = gl.RGB5_A1,
    rgba8 = gl.RGBA8,
    rgba8_snorm = gl.RGBA8_SNORM,
    rgb10_a2 = gl.RGB10_A2,
    rgb10_a2ui = gl.RGB10_A2UI,
    rgba12 = gl.RGBA12,
    rgba16 = gl.RGBA16,
    srgb8 = gl.SRGB8,
    srgb8_alpha8 = gl.SRGB8_ALPHA8,
    r16f = gl.R16F,
    rg16f = gl.RG16F,
    rgb16f = gl.RGB16F,
    rgba16f = gl.RGBA16F,
    r32f = gl.R32F,
    rg32f = gl.RG32F,
    rgb32f = gl.RGB32F,
    rgba32f = gl.RGBA32F,
    r11f_g11f_b10f = gl.R11F_G11F_B10F,
    rgb9_e5 = gl.RGB9_E5,
    r8i = gl.R8I,
    r8ui = gl.R8UI,
    r16i = gl.R16I,
    r16ui = gl.R16UI,
    r32i = gl.R32I,
    r32ui = gl.R32UI,
    rg8i = gl.RG8I,
    rg8ui = gl.RG8UI,
    rg16i = gl.RG16I,
    rg16ui = gl.RG16UI,
    rg32i = gl.RG32I,
    rg32ui = gl.RG32UI,
    rgb8i = gl.RGB8I,
    rgb8ui = gl.RGB8UI,
    rgb16i = gl.RGB16I,
    rgb16ui = gl.RGB16UI,
    rgb32i = gl.RGB32I,
    rgb32ui = gl.RGB32UI,
    rgba8i = gl.RGBA8I,
    rgba8ui = gl.RGBA8UI,
    rgba16i = gl.RGBA16I,
    rgba16ui = gl.RGBA16UI,
    rgba32i = gl.RGBA32I,
    rgba32ui = gl.RGBA32UI,
};

pub const ImageType = enum(u32) {
    _2D,
    _3D,
    _1DArray,
    _2DArray,
    cubeMap,
    cubeMapArray,
    _2DMultiSample,
    _3DMultiSample,

    pub fn toGL(t: ImageType) u32 {
        return switch (t) {
            ._2D => gl.TEXTURE_2D,
            ._3D => gl.TEXTURE_3D,
            ._1DArray => gl.TEXTURE_1D_ARRAY,
            ._2DArray => gl.TEXTURE_2D_ARRAY,
            .cubeMap => gl.TEXTURE_CUBE_MAP,
            .cubeMapArray => gl.TEXTURE_CUBE_MAP_ARRAY,
            ._2DMultiSample => gl.TEXTURE_2D_MULTISAMPLE,
            ._3DMultiSample => gl.TEXTURE_2D_MULTISAMPLE_ARRAY,
        };
    }
};

pub const TextureCreateInfo = struct {
    name: ?[]const u8 = null,
    type: ImageType,
    extent: Extent(u32),
    format: Format,
    mipLevels: u32 = 1,
};

pub fn init(info: TextureCreateInfo) Texture {
    var handle: u32 = 0;
    gl.createTextures(info.type.toGL(), 1, @ptrCast(&handle));
    switch (info.type) {
        ._2D => gl.textureStorage2D(handle, @intCast(info.mipLevels), @intFromEnum(info.format), @intCast(info.extent.width), @intCast(info.extent.height)),
        ._1DArray => gl.textureStorage2D(handle, @intCast(info.mipLevels), @intFromEnum(info.format), @intCast(info.extent.width), @intCast(info.extent.height)),
        .cubeMap => gl.textureStorage2D(handle, @intCast(info.mipLevels), @intFromEnum(info.format), @intCast(info.extent.width), @intCast(info.extent.height)),
        ._2DMultiSample => gl.textureStorage2DMultisample(handle, @intCast(info.mipLevels), @intFromEnum(info.format), @intCast(info.extent.width), @intCast(info.extent.height), gl.TRUE),

        ._3D => gl.textureStorage3D(handle, @intCast(info.mipLevels), @intFromEnum(info.format), @intCast(info.extent.width), @intCast(info.extent.height), @intCast(info.extent.depth)),
        ._2DArray => gl.textureStorage3D(handle, @intCast(info.mipLevels), @intFromEnum(info.format), @intCast(info.extent.width), @intCast(info.extent.height), @intCast(info.extent.depth)),
        .cubeMapArray => gl.textureStorage3D(handle, @intCast(info.mipLevels), @intFromEnum(info.format), @intCast(info.extent.width), @intCast(info.extent.height), @intCast(info.extent.depth)),
        ._3DMultiSample => gl.textureStorage3DMultisample(handle, @intCast(info.mipLevels), @intFromEnum(info.format), @intCast(info.extent.width), @intCast(info.extent.height), @intCast(info.extent.depth), gl.TRUE),
    }

    if (info.name) |name| {
        gl.objectLabel(gl.TEXTURE, handle, @intCast(name.len), name.ptr);
    }

    return .{
        .handle = handle,
        .createInfo = info,
    };
}

pub const TextureUpdateInformation = struct {
    level: u32 = 0,
    extent: Extent(u32),
    offset: Extent(u32) = .{ .width = 0, .height = 0, .depth = 0 },
    format: u32, // TODO: Use enums
    type: u32,
    data: []const u8,
};

pub fn update(self: Texture, info: TextureUpdateInformation) void {
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    gl.pixelStorei(gl.PACK_ALIGNMENT, 1);
    gl.textureSubImage2D(
        self.handle,
        @intCast(info.level),
        0,
        0,
        @intCast(info.extent.width),
        @intCast(info.extent.height),
        gl.RGB,
        gl.UNSIGNED_BYTE,
        info.data.ptr,
    );

    //switch (self.createInfo.type) {
    //    ._2D => gl.textureSubImage2D(
    //        self.handle,
    //        @intCast(info.level),
    //        0,
    //        0,
    //        @intCast(info.extent.width),
    //        @intCast(info.extent.height),
    //        gl.RGB,
    //        gl.UNSIGNED_BYTE,
    //        info.data.ptr,
    //    ),
    //    else => @panic("Unsupported"),
    //}
}

pub fn deinit(self: Texture) void {
    if (self.handle == 0) return;
    //if (self.bindlessHandle != 0) {
    //    gl.makeTextureHandleNonResidentARB(self.bindlessHandle);
    //}
    gl.deleteTextures(1, @ptrCast(&self.handle));
}
