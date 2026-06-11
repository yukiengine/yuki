const std = @import("std");
const c = @import("../backend/webgpu_c.zig").c;

const max_quads = 128;
const vertices_per_quad = 6;
const max_vertices = max_quads * vertices_per_quad;
const max_textures = 8;

pub const Error = error{
    CreateShaderModuleFailed,
    CreatePipelineLayoutFailed,
    CreateRenderPipelineFailed,
    CreateVertexBufferFailed,
    CreateBindGroupLayoutFailed,
    CreateTextureFailed,
    CreateTextureViewFailed,
    CreateSamplerFailed,
    CreateBindGroupFailed,
    TextureTableFull,
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

pub const UvRect = extern struct {
    min: Vector2,
    max: Vector2,

    pub fn full() UvRect {
        return .{
            .min = Vector2.xy(0.0, 0.0),
            .max = Vector2.xy(1.0, 1.0),
        };
    }

    pub fn init(min: Vector2, max: Vector2) UvRect {
        return .{ .min = min, .max = max };
    }
};

pub const Quad = struct {
    position: Vector2,
    size: Vector2,
    color: ColorRgba,
    texture: TextureId = TextureId.default(),
    uv: UvRect = UvRect.full(),

    pub fn init(position: Vector2, size: Vector2, color: ColorRgba) Quad {
        return .{
            .position = position,
            .size = size,
            .color = color,
        };
    }

    pub fn textured(position: Vector2, size: Vector2, color: ColorRgba, texture: TextureId) Quad {
        return .{
            .position = position,
            .size = size,
            .color = color,
            .texture = texture,
        };
    }

    pub fn texturedRegion(position: Vector2, size: Vector2, color: ColorRgba, texture: TextureId, uv: UvRect) Quad {
        return .{
            .position = position,
            .size = size,
            .color = color,
            .texture = texture,
            .uv = uv,
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
    \\@group(0) @binding(0) var quad_texture: texture_2d<f32>;
    \\@group(0) @binding(1) var quad_sampler: sampler;
    \\@fragment
    \\fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    \\    return textureSample(quad_texture, quad_sampler, input.uv) * input.color;
    \\}
;

const Texture2D = struct {
    texture: c.WGPUTexture,
    view: c.WGPUTextureView,
    bind_group: c.WGPUBindGroup,
    width: u32,
    height: u32,

    fn deinit(self: *Texture2D) void {
        c.wgpuBindGroupRelease(self.bind_group);
        c.wgpuTextureViewRelease(self.view);
        c.wgpuTextureRelease(self.texture);
        self.* = undefined;
    }
};

pub const TextureId = extern struct {
    index: u32,

    pub fn default() TextureId {
        return .{ .index = 0 };
    }
};

pub const Renderer2D = struct {
    pipeline: c.WGPURenderPipeline,
    vertex_buffer: c.WGPUBuffer,
    quads: [max_quads]Quad,
    vertices: [max_vertices]Vertex,
    quad_count: usize,
    texture_bind_group_layout: c.WGPUBindGroupLayout,
    sampler: c.WGPUSampler,
    textures: [max_textures]Texture2D,
    texture_count: usize,

    pub fn init(device: c.WGPUDevice, queue: c.WGPUQueue, format: c.WGPUTextureFormat) !Renderer2D {
        const vertex_buffer = try createQuadVertexBuffer(device);
        errdefer c.wgpuBufferRelease(vertex_buffer);

        const texture_bind_group_layout = try createTextureBindGroupLayout(device);
        errdefer c.wgpuBindGroupLayoutRelease(texture_bind_group_layout);

        const sampler = try createSampler(device);
        errdefer c.wgpuSamplerRelease(sampler);

        const pipeline = try createQuadPipeline(device, format, texture_bind_group_layout);
        errdefer c.wgpuRenderPipelineRelease(pipeline);

        var renderer = Renderer2D{
            .pipeline = pipeline,
            .vertex_buffer = vertex_buffer,
            .quads = undefined,
            .vertices = undefined,
            .quad_count = 0,
            .texture_bind_group_layout = texture_bind_group_layout,
            .sampler = sampler,
            .textures = undefined,
            .texture_count = 0,
        };
        errdefer {
            var index: usize = renderer.texture_count;
            while (index > 0) {
                index -= 1;
                renderer.textures[index].deinit();
            }
        }

        _ = renderer.addTexture(try createCheckerTexture(
            device,
            queue,
            texture_bind_group_layout,
            sampler,
        ));

        return renderer;
    }

    pub fn deinit(self: *Renderer2D) void {
        var index: usize = self.texture_count;
        while (index > 0) {
            index -= 1;
            self.textures[index].deinit();
        }

        c.wgpuSamplerRelease(self.sampler);
        c.wgpuBindGroupLayoutRelease(self.texture_bind_group_layout);
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

        for (self.quads[0..self.quad_count], 0..) |quad, index| {
            c.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.textureBindGroup(quad.texture), 0, null);

            const first_vertex: u32 = @intCast(index * vertices_per_quad);
            c.wgpuRenderPassEncoderDraw(pass, vertices_per_quad, 1, first_vertex, 0);
        }
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

            const uv_left = quad.uv.min.x;
            const uv_top = quad.uv.min.y;
            const uv_right = quad.uv.max.x;
            const uv_bottom = quad.uv.max.y;

            self.vertices[vertex_count + 0] = .{ .position = .{ .x = left, .y = top }, .color = quad.color, .uv = Vector2.xy(uv_left, uv_top) };
            self.vertices[vertex_count + 1] = .{ .position = .{ .x = left, .y = bottom }, .color = quad.color, .uv = Vector2.xy(uv_left, uv_bottom) };
            self.vertices[vertex_count + 2] = .{ .position = .{ .x = right, .y = bottom }, .color = quad.color, .uv = Vector2.xy(uv_right, uv_bottom) };

            self.vertices[vertex_count + 3] = .{ .position = .{ .x = left, .y = top }, .color = quad.color, .uv = Vector2.xy(uv_left, uv_top) };
            self.vertices[vertex_count + 4] = .{ .position = .{ .x = right, .y = bottom }, .color = quad.color, .uv = Vector2.xy(uv_right, uv_bottom) };
            self.vertices[vertex_count + 5] = .{ .position = .{ .x = right, .y = top }, .color = quad.color, .uv = Vector2.xy(uv_right, uv_top) };

            vertex_count += vertices_per_quad;
        }

        return vertex_count;
    }

    fn textureBindGroup(self: *const Renderer2D, texture: TextureId) c.WGPUBindGroup {
        const index: usize = @intCast(texture.index);
        std.debug.assert(index < self.texture_count);

        return self.textures[index].bind_group;
    }

    fn addTexture(self: *Renderer2D, texture: Texture2D) TextureId {
        std.debug.assert(self.texture_count < max_textures);

        const id = TextureId{ .index = @intCast(self.texture_count) };
        self.textures[self.texture_count] = texture;
        self.texture_count += 1;

        return id;
    }

    pub fn createTextureFromRgbaPixels(
        self: *Renderer2D,
        device: c.WGPUDevice,
        queue: c.WGPUQueue,
        label: [:0]const u8,
        width: u32,
        height: u32,
        pixels: []const u8,
    ) !TextureId {
        if (self.texture_count == max_textures) return Error.TextureTableFull;

        var texture = try createTexture2DFromRgbaPixels(
            device,
            queue,
            self.texture_bind_group_layout,
            self.sampler,
            label,
            width,
            height,
            pixels,
        );
        errdefer texture.deinit();

        return self.addTexture(texture);
    }
};

fn createQuadPipeline(device: c.WGPUDevice, format: c.WGPUTextureFormat, texture_bind_group_layout: c.WGPUBindGroupLayout) !c.WGPURenderPipeline {
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

    var bind_group_layouts = [_]c.WGPUBindGroupLayout{texture_bind_group_layout};
    layout_desc.bindGroupLayoutCount = bind_group_layouts.len;
    layout_desc.bindGroupLayouts = bind_group_layouts[0..].ptr;

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

fn createTextureBindGroupLayout(device: c.WGPUDevice) !c.WGPUBindGroupLayout {
    var entries = [_]c.WGPUBindGroupLayoutEntry{
        std.mem.zeroes(c.WGPUBindGroupLayoutEntry),
        std.mem.zeroes(c.WGPUBindGroupLayoutEntry),
    };

    entries[0].binding = 0;
    entries[0].visibility = c.WGPUShaderStage_Fragment;
    entries[0].texture.sampleType = c.WGPUTextureSampleType_Float;
    entries[0].texture.viewDimension = c.WGPUTextureViewDimension_2D;

    entries[1].binding = 1;
    entries[1].visibility = c.WGPUShaderStage_Fragment;
    entries[1].sampler.type = c.WGPUSamplerBindingType_Filtering;

    var desc: c.WGPUBindGroupLayoutDescriptor =
        std.mem.zeroes(c.WGPUBindGroupLayoutDescriptor);
    desc.label = stringView("quad texture bind group layout");
    desc.entryCount = entries.len;
    desc.entries = entries[0..].ptr;

    return c.wgpuDeviceCreateBindGroupLayout(device, &desc) orelse
        Error.CreateBindGroupLayoutFailed;
}

fn createTextureView(texture: c.WGPUTexture) !c.WGPUTextureView {
    var desc: c.WGPUTextureViewDescriptor =
        std.mem.zeroes(c.WGPUTextureViewDescriptor);
    desc.label = stringView("default texture view");
    desc.format = c.WGPUTextureFormat_RGBA8Unorm;
    desc.dimension = c.WGPUTextureViewDimension_2D;
    desc.baseMipLevel = 0;
    desc.mipLevelCount = 1;
    desc.baseArrayLayer = 0;
    desc.arrayLayerCount = 1;
    desc.aspect = c.WGPUTextureAspect_All;
    desc.usage = c.WGPUTextureUsage_TextureBinding;

    return c.wgpuTextureCreateView(texture, &desc) orelse
        Error.CreateTextureViewFailed;
}

fn createSampler(device: c.WGPUDevice) !c.WGPUSampler {
    var desc: c.WGPUSamplerDescriptor = std.mem.zeroes(c.WGPUSamplerDescriptor);
    desc.label = stringView("quad sampler");
    desc.addressModeU = c.WGPUAddressMode_ClampToEdge;
    desc.addressModeV = c.WGPUAddressMode_ClampToEdge;
    desc.addressModeW = c.WGPUAddressMode_ClampToEdge;
    desc.magFilter = c.WGPUFilterMode_Nearest;
    desc.minFilter = c.WGPUFilterMode_Nearest;
    desc.mipmapFilter = c.WGPUMipmapFilterMode_Nearest;
    desc.maxAnisotropy = 1;

    return c.wgpuDeviceCreateSampler(device, &desc) orelse Error.CreateSamplerFailed;
}

fn createTextureBindGroup(
    device: c.WGPUDevice,
    layout: c.WGPUBindGroupLayout,
    texture_view: c.WGPUTextureView,
    sampler: c.WGPUSampler,
) !c.WGPUBindGroup {
    var entries = [_]c.WGPUBindGroupEntry{
        std.mem.zeroes(c.WGPUBindGroupEntry),
        std.mem.zeroes(c.WGPUBindGroupEntry),
    };

    entries[0].binding = 0;
    entries[0].textureView = texture_view;

    entries[1].binding = 1;
    entries[1].sampler = sampler;

    var desc: c.WGPUBindGroupDescriptor =
        std.mem.zeroes(c.WGPUBindGroupDescriptor);
    desc.label = stringView("quad texture bind group");
    desc.layout = layout;
    desc.entryCount = entries.len;
    desc.entries = entries[0..].ptr;

    return c.wgpuDeviceCreateBindGroup(device, &desc) orelse
        Error.CreateBindGroupFailed;
}

fn createCheckerTexture(
    device: c.WGPUDevice,
    queue: c.WGPUQueue,
    bind_group_layout: c.WGPUBindGroupLayout,
    sampler: c.WGPUSampler,
) !Texture2D {
    const pixels = [_]u8{
        255, 255, 255, 255, 32,  32,  32,  255,
        32,  32,  32,  255, 255, 255, 255, 255,
    };

    return createTexture2DFromRgbaPixels(
        device,
        queue,
        bind_group_layout,
        sampler,
        "checker texture",
        2,
        2,
        pixels[0..],
    );
}

fn createTexture2DFromRgbaPixels(
    device: c.WGPUDevice,
    queue: c.WGPUQueue,
    bind_group_layout: c.WGPUBindGroupLayout,
    sampler: c.WGPUSampler,
    label: [:0]const u8,
    width: u32,
    height: u32,
    pixels: []const u8,
) !Texture2D {
    const expected_size = @as(usize, @intCast(width)) * @as(usize, @intCast(height)) * 4;
    std.debug.assert(pixels.len == expected_size); // TODO: make it return an error

    var desc: c.WGPUTextureDescriptor = std.mem.zeroes(c.WGPUTextureDescriptor);
    desc.label = stringView(label);
    desc.usage = c.WGPUTextureUsage_TextureBinding | c.WGPUTextureUsage_CopyDst;
    desc.dimension = c.WGPUTextureDimension_2D;
    desc.size = .{ .width = width, .height = height, .depthOrArrayLayers = 1 };
    desc.format = c.WGPUTextureFormat_RGBA8Unorm;
    desc.mipLevelCount = 1;
    desc.sampleCount = 1;

    const texture = c.wgpuDeviceCreateTexture(device, &desc) orelse return Error.CreateTextureFailed;
    errdefer c.wgpuTextureRelease(texture);

    var dst: c.WGPUTexelCopyTextureInfo = .{
        .texture = texture,
        .mipLevel = 0,
        .origin = .{ .x = 0, .y = 0, .z = 0 },
        .aspect = c.WGPUTextureAspect_All,
    };

    var layout: c.WGPUTexelCopyBufferLayout = .{
        .offset = 0,
        .bytesPerRow = width * 4,
        .rowsPerImage = height,
    };

    var size: c.WGPUExtent3D = .{
        .width = width,
        .height = height,
        .depthOrArrayLayers = 1,
    };

    c.wgpuQueueWriteTexture(queue, &dst, pixels.ptr, pixels.len, &layout, &size);

    const view = try createTextureView(texture);
    errdefer c.wgpuTextureViewRelease(view);

    const bind_group = try createTextureBindGroup(device, bind_group_layout, view, sampler);
    errdefer c.wgpuBindGroupRelease(bind_group);

    return .{
        .texture = texture,
        .view = view,
        .bind_group = bind_group,
        .width = width,
        .height = height,
    };
}
