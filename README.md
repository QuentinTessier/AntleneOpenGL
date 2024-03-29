# AntleneOpenGL
OpenGL abstraction inspired by https://github.com/JuanDiegoMontoya/Fwog but in Zig.

Example repository in currently being worked on.

One of the goals of the library would be to provided what I would called TypedPipeline:
This would take the form of:

In your build.zig file:
```zig

// In build.zig:

pub fn build(b: *std.Build) void {
    ...
    const shaderReflectionTool = AntleneOpenGL.buildShaderReflectionTool(b, opengl_loader);

    const reflect_shader_cmd = b.addRunArtifact(shaderReflectionTool);

    reflect_shader_cmd.step.dependOn(b.getInstallStep());

    const args: [_][_]u8 = .{
        "output.zig",
        "shader.vert",
        "shader.frag",
        ...
    };

    reflect_shader_cmd.addArgs(args);

    const run_shader_reflection_step = b.step("run shader reflection", "Run the app");
    run_step.dependOn(&reflect_shader_cmd.step);
    ...
}

// Generated output.zig file:
pub const Shader = struct {
    pub const SourceFiles: []ShaderSourceFile = &.{
        .{ .stage = .Vertex, .path = "shader.vert" },
        .{ .stage = .Fragment, .path = "shader.frag" },
    };

    pub const Input = struct {
        pub const Position : ShaderInput = .{
            .stage = .Vertex,
            .location = 0,
            .type = @Vector(3, f32),
        };
    };

    pub const Output = struct {
        pub const vPosition = struct {
            .stage = .Vertex,
            .location = 0,
            .type = @Vector(3, f32),
        }

        pub const fColor = struct {
            .stage = .Fragment,
            .location = 0,
            .type = @Vector(4, f32),
        }
    };

    pub const ShaderStorageBufferObject = struct {
        pub const MeshData = struct {
            .binding = 0,
        };
    };

    pub const UniformBuffer = struct {
        
    };

    pub const Sampler = struct {
        pub const Diffuse = struct {
            .binding = 0,
        };
    };
};

// In your application

const Context = @import("AntleneOpenGL");

const pipeline = Context.Resources.CreatePipelineFromReflected(.{
    .reflectedType = Output.Shader,
    ... // Standard Pipeline parameters (depth testing, culling, ...)
}); // We can automaticaly generated the appropriate VertexArray from the reflected type and do some fancy debug stuff using this information at runtime. 

pub const Pass = struct {
    pipeline: Context.GraphicPipeline,
    diffuse: Context.Texture,
    specular: Context.Texture,
    meshData: Context.Buffer,

    pub fn execute(pass: Pass) !void {
        Context.Commands.BindGraphicPipeline(pass.pipeline);
        Context.Commands.BindTextureFromReflected(Output.Shader, .Diffuse, pass.diffuse); // Will bind diffuse to binding point 0
        Context.Commands.BindTextureFromReflected(Output.Shader, .Specular, pass.specular); // Won't compile since Specular wasn't found in shader
        Context.Commands.BindShaderStorageBufferFromReflected(Output.Shader, .MeshData, pass.meshData)
    }
};

```

For current use see [here](https://github.com/QuentinTessier/AntleneOpenGL/blob/main/src/Pipeline/TypedGraphicPipeline.zig)