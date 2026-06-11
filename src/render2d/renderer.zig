const std = @import("std");
const c = @import("../backend/webgpu_c.zig").c;

const max_quads = 128;
const vertices_per_quad = 6;
const max_vertices = max_quads * vertices_per_quad;

pub const Error = error{
    CreateShaderModuleFailed,
    CreatePipelineLayoutFailed,
    CreateRenderPipelineFailed,
    CreateVertexBufferFailed,
};

pub const Vector2 = extern struct {
    x: f32,
    y: f32,

    pub fn xy(x: f32, y: f32) Vector2 {
        return .{ .x = x, .y = y };
    }
};

const Vertex = extern struct {
    position: Vector2,
    color: ColorRgba,
    uv: Vector2,
};

pub const ColorRgba = extern struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn rgba(r: f32, g: f32, b: f32, a: f32) ColorRgba {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn rgb(r: f32, g: f32, b: f32) ColorRgba {
        return rgba(r, g, b, 1.0);
    }
};

pub const Quad = struct {
    position: Vector2,
    size: Vector2,
    color: ColorRgba,

    pub fn init(position: Vector2, size: Vector2, color: ColorRgba) Quad {
        return .{
            .position = position,
            .size = size,
            .color = color,
        };
    }
};

pub const Camera2D = struct {
    position: Vector2 = .{ .x = 0.0, .y = 0.0 },
    zoom: f32 = 1.0,

    pub fn init(position: Vector2, zoom: f32) Camera2D {
        std.debug.assert(zoom > 0.0);

        return .{
            .position = position,
            .zoom = zoom,
        };
    }
};

pub const Frame = struct {
    clear_color: ColorRgba,
    quads: []const Quad,
    camera: Camera2D,

    pub fn init(clear_color: ColorRgba, quads: []const Quad) Frame {
        return .{
            .clear_color = clear_color,
            .quads = quads,
            .camera = .{},
        };
    }

    pub fn withCamera(clear_color: ColorRgba, camera: Camera2D, quads: []const Quad) Frame {
        return .{
            .clear_color = clear_color,
            .camera = camera,
            .quads = quads,
        };
    }
};

const quad_shader =
    \\struct VertexInput {
    \\    @location(0) position: vec2f,
    \\    @location(1) color: vec4f,
    \\    @location(2) uv: vec2f,
    \\};
    \\
    \\struct VertexOutput {
    \\    @builtin(position) position: vec4f,
    \\    @location(0) color: vec4f,
    \\    @location(1) uv: vec2f,
    \\};
    \\
    \\@vertex
    \\fn vs_main(input: VertexInput) -> VertexOutput {
    \\    var output: VertexOutput;
    \\    output.position = vec4f(input.position, 0.0, 1.0);
    \\    output.color = input.color;
    \\    output.uv = input.uv;
    \\    return output;
    \\}
    \\
    \\@fragment
    \\fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    \\    return input.color;
    \\}
;

pub const Renderer2D = struct {
    pipeline: c.WGPURenderPipeline,
    vertex_buffer: c.WGPUBuffer,
    quads: [max_quads]Quad,
    vertices: [max_vertices]Vertex,
    quad_count: usize,
    pub fn init(device: c.WGPUDevice, format: c.WGPUTextureFormat) !Renderer2D {
        const vertex_buffer = try createQuadVertexBuffer(device);
        errdefer c.wgpuBufferRelease(vertex_buffer);

        const pipeline = try createQuadPipeline(device, format);
        errdefer c.wgpuRenderPipelineRelease(pipeline);

        return Renderer2D{
            .pipeline = pipeline,
            .vertex_buffer = vertex_buffer,
            .quads = undefined,
            .vertices = undefined,
            .quad_count = 0,
        };
    }

    pub fn deinit(self: *Renderer2D) void {
        c.wgpuRenderPipelineRelease(self.pipeline);
        c.wgpuBufferRelease(self.vertex_buffer);
        self.* = undefined;
    }

    pub fn flush(
        self: *Renderer2D,
        queue: c.WGPUQueue,
        pass: c.WGPURenderPassEncoder,
        surface_width: u32,
        surface_height: u32,
        camera: Camera2D,
    ) void {
        if (self.quad_count == 0) return;

        const vertex_count = self.buildQuadVertices(surface_width, surface_height, camera);
        const vertex_data_size = vertex_count * @sizeOf(Vertex);

        c.wgpuQueueWriteBuffer(queue, self.vertex_buffer, 0, self.vertices[0..vertex_count].ptr, vertex_data_size);
        c.wgpuRenderPassEncoderSetPipeline(pass, self.pipeline);
        c.wgpuRenderPassEncoderSetVertexBuffer(pass, 0, self.vertex_buffer, 0, vertex_data_size);
        c.wgpuRenderPassEncoderDraw(pass, @intCast(vertex_count), 1, 0, 0);
    }

    pub fn beginFrame(self: *Renderer2D) void {
        self.quad_count = 0;
    }

    pub fn drawQuad(self: *Renderer2D, quad: Quad) void {
        std.debug.assert(self.quad_count < max_quads);
        if (self.quad_count == max_quads) return;

        self.quads[self.quad_count] = quad;
        self.quad_count += 1;
    }

    fn buildQuadVertices(self: *Renderer2D, surface_width: u32, surface_height: u32, camera: Camera2D) usize {
        var vertex_count: usize = 0;

        for (self.quads[0..self.quad_count]) |quad| {
            const half_width = quad.size.x * 0.5;
            const half_height = quad.size.y * 0.5;

            const left = worldToClipX(quad.position.x - half_width, surface_width, camera);
            const right = worldToClipX(quad.position.x + half_width, surface_width, camera);
            const top = worldToClipY(quad.position.y - half_height, surface_height, camera);
            const bottom = worldToClipY(quad.position.y + half_height, surface_height, camera);

            self.vertices[vertex_count + 0] = .{ .position = .{ .x = left, .y = top }, .color = quad.color, .uv = Vector2.xy(0.0, 0.0) };
            self.vertices[vertex_count + 1] = .{ .position = .{ .x = left, .y = bottom }, .color = quad.color, .uv = Vector2.xy(0.0, 1.0) };
            self.vertices[vertex_count + 2] = .{ .position = .{ .x = right, .y = bottom }, .color = quad.color, .uv = Vector2.xy(1.0, 1.0) };

            self.vertices[vertex_count + 3] = .{ .position = .{ .x = left, .y = top }, .color = quad.color, .uv = Vector2.xy(0.0, 0.0) };
            self.vertices[vertex_count + 4] = .{ .position = .{ .x = right, .y = bottom }, .color = quad.color, .uv = Vector2.xy(1.0, 1.0) };
            self.vertices[vertex_count + 5] = .{ .position = .{ .x = right, .y = top }, .color = quad.color, .uv = Vector2.xy(1.0, 0.0) };

            vertex_count += vertices_per_quad;
        }

        return vertex_count;
    }
};

fn createQuadPipeline(device: c.WGPUDevice, format: c.WGPUTextureFormat) !c.WGPURenderPipeline {
    var wgsl_source: c.WGPUShaderSourceWGSL = std.mem.zeroes(c.WGPUShaderSourceWGSL);
    wgsl_source.chain.sType = c.WGPUSType_ShaderSourceWGSL;
    wgsl_source.code = stringView(quad_shader);

    var shader_desc: c.WGPUShaderModuleDescriptor = std.mem.zeroes(c.WGPUShaderModuleDescriptor);
    shader_desc.nextInChain = &wgsl_source.chain;
    shader_desc.label = stringView("quad shader");

    const shader = c.wgpuDeviceCreateShaderModule(device, &shader_desc) orelse {
        return Error.CreateShaderModuleFailed;
    };
    defer c.wgpuShaderModuleRelease(shader);

    var layout_desc: c.WGPUPipelineLayoutDescriptor = std.mem.zeroes(c.WGPUPipelineLayoutDescriptor);
    layout_desc.label = stringView("quad pipeline layout");

    const layout = c.wgpuDeviceCreatePipelineLayout(device, &layout_desc) orelse {
        return Error.CreatePipelineLayoutFailed;
    };
    defer c.wgpuPipelineLayoutRelease(layout);

    var color_target: c.WGPUColorTargetState = std.mem.zeroes(c.WGPUColorTargetState);
    color_target.format = format;
    color_target.writeMask = c.WGPUColorWriteMask_All;

    var fragment: c.WGPUFragmentState = std.mem.zeroes(c.WGPUFragmentState);
    fragment.module = shader;
    fragment.entryPoint = stringView("fs_main");
    fragment.targetCount = 1;
    fragment.targets = &color_target;

    var vertex_attributes = [_]c.WGPUVertexAttribute{
        .{
            .format = c.WGPUVertexFormat_Float32x2,
            .offset = @offsetOf(Vertex, "position"),
            .shaderLocation = 0,
        },
        .{
            .format = c.WGPUVertexFormat_Float32x4,
            .offset = @offsetOf(Vertex, "color"),
            .shaderLocation = 1,
        },
        .{
            .format = c.WGPUVertexFormat_Float32x2,
            .offset = @offsetOf(Vertex, "uv"),
            .shaderLocation = 2,
        },
    };

    var vertex_buffer_layout: c.WGPUVertexBufferLayout = std.mem.zeroes(c.WGPUVertexBufferLayout);
    vertex_buffer_layout.stepMode = c.WGPUVertexStepMode_Vertex;
    vertex_buffer_layout.arrayStride = @sizeOf(Vertex);
    vertex_buffer_layout.attributeCount = vertex_attributes.len;
    vertex_buffer_layout.attributes = vertex_attributes[0..].ptr;

    var pipeline_desc: c.WGPURenderPipelineDescriptor = std.mem.zeroes(c.WGPURenderPipelineDescriptor);
    pipeline_desc.label = stringView("quad pipeline");
    pipeline_desc.layout = layout;
    pipeline_desc.vertex.module = shader;
    pipeline_desc.vertex.entryPoint = stringView("vs_main");
    pipeline_desc.vertex.bufferCount = 1;
    pipeline_desc.vertex.buffers = &vertex_buffer_layout;
    pipeline_desc.primitive.topology = c.WGPUPrimitiveTopology_TriangleList;
    pipeline_desc.primitive.frontFace = c.WGPUFrontFace_CCW;
    pipeline_desc.primitive.cullMode = c.WGPUCullMode_None;
    pipeline_desc.fragment = &fragment;
    pipeline_desc.multisample.count = 1;
    pipeline_desc.multisample.mask = 0xffffffff;

    return c.wgpuDeviceCreateRenderPipeline(device, &pipeline_desc) orelse {
        return Error.CreateRenderPipelineFailed;
    };
}

fn createQuadVertexBuffer(device: c.WGPUDevice) !c.WGPUBuffer {
    var desc: c.WGPUBufferDescriptor = std.mem.zeroes(c.WGPUBufferDescriptor);
    desc.label = stringView("quad vertex buffer");
    desc.usage = c.WGPUBufferUsage_Vertex | c.WGPUBufferUsage_CopyDst;
    desc.size = max_vertices * @sizeOf(Vertex);

    return c.wgpuDeviceCreateBuffer(device, &desc) orelse {
        return Error.CreateVertexBufferFailed;
    };
}

fn stringView(value: [:0]const u8) c.WGPUStringView {
    return .{
        .data = value.ptr,
        .length = c.WGPU_STRLEN,
    };
}

fn screenToClipX(x: f32, surface_width: u32) f32 {
    return (x / @as(f32, @floatFromInt(surface_width))) * 2.0 - 1.0;
}

fn screenToClipY(y: f32, surface_height: u32) f32 {
    return 1.0 - (y / @as(f32, @floatFromInt(surface_height))) * 2.0;
}

fn worldToClipX(x: f32, surface_width: u32, camera: Camera2D) f32 {
    const half_width = @as(f32, @floatFromInt(surface_width)) * 0.5;
    const screen_x = (x - camera.position.x) * camera.zoom + half_width;
    return screenToClipX(screen_x, surface_width);
}

fn worldToClipY(y: f32, surface_height: u32, camera: Camera2D) f32 {
    const half_height = @as(f32, @floatFromInt(surface_height)) * 0.5;
    const screen_y = (y - camera.position.y) * camera.zoom + half_height;
    return screenToClipY(screen_y, surface_height);
}
