const std = @import("std");
const c = @import("../backend/webgpu_c.zig").c;

pub const Error = error{
    CreateShaderModuleFailed,
    CreatePipelineLayoutFailed,
    CreateRenderPipelineFailed,
    CreateUniformBufferFailed,
    CreateBindGroupLayoutFailed,
    CreateBindGroupFailed,
    CreateVertexBufferFailed,
};

const Uniforms = extern struct {
    offset: [2]f32,
    _pad: [2]f32 = .{ 0, 0 },
};

const Vertex = extern struct {
    position: [2]f32,
};

const quad_vertices = [_]Vertex{
    .{ .position = .{ -0.5, 0.5 } },
    .{ .position = .{ -0.5, -0.5 } },
    .{ .position = .{ 0.5, -0.5 } },

    .{ .position = .{ -0.5, 0.5 } },
    .{ .position = .{ 0.5, -0.5 } },
    .{ .position = .{ 0.5, 0.5 } },
};

const quad_shader =
    \\struct Uniforms {
    \\    offset: vec2f,
    \\};
    \\
    \\struct VertexInput {
    \\    @location(0) position: vec2f,
    \\};
    \\
    \\@group(0) @binding(0)
    \\var<uniform> uniforms: Uniforms;
    \\
    \\@vertex
    \\fn vs_main(input: VertexInput) -> @builtin(position) vec4f {
    \\    let pos = input.position + uniforms.offset;
    \\    return vec4f(pos, 0.0, 1.0);
    \\}
    \\
    \\@fragment
    \\fn fs_main() -> @location(0) vec4f {
    \\    return vec4f(1.0, 1.0, 1.0, 1.0);
    \\}
;

pub const Renderer2D = struct {
    pipeline: c.WGPURenderPipeline,
    uniform_buffer: c.WGPUBuffer,
    bind_group_layout: c.WGPUBindGroupLayout,
    bind_group: c.WGPUBindGroup,
    vertex_buffer: c.WGPUBuffer,

    pub fn init(device: c.WGPUDevice, queue: c.WGPUQueue, format: c.WGPUTextureFormat) !Renderer2D {
        const uniform_buffer = try createUniformBuffer(device);
        errdefer c.wgpuBufferRelease(uniform_buffer);

        const bind_group_layout = try createQuadBindGroupLayout(device);
        errdefer c.wgpuBindGroupLayoutRelease(bind_group_layout);

        const bind_group = try createQuadBindGroup(device, bind_group_layout, uniform_buffer);
        errdefer c.wgpuBindGroupRelease(bind_group);

        const vertex_buffer = try createQuadVertexBuffer(device, queue);
        errdefer c.wgpuBufferRelease(vertex_buffer);

        const pipeline = try createQuadPipeline(device, format, bind_group_layout);
        errdefer c.wgpuRenderPipelineRelease(pipeline);

        return Renderer2D{
            .pipeline = pipeline,
            .uniform_buffer = uniform_buffer,
            .bind_group_layout = bind_group_layout,
            .bind_group = bind_group,
            .vertex_buffer = vertex_buffer,
        };
    }

    pub fn deinit(self: *Renderer2D) void {
        c.wgpuRenderPipelineRelease(self.pipeline);
        c.wgpuBindGroupRelease(self.bind_group);
        c.wgpuBindGroupLayoutRelease(self.bind_group_layout);
        c.wgpuBufferRelease(self.uniform_buffer);
        c.wgpuBufferRelease(self.vertex_buffer);
        self.* = undefined;
    }

    pub fn draw(
        self: *Renderer2D,
        queue: c.WGPUQueue,
        pass: c.WGPURenderPassEncoder,
        x: f32,
        y: f32,
        surface_width: u32,
        surface_height: u32,
    ) void {
        const uniforms = Uniforms{
            .offset = .{
                (x / @as(f32, @floatFromInt(surface_width))) * 2.0,
                (y / @as(f32, @floatFromInt(surface_height))) * -2.0,
            },
        };

        c.wgpuQueueWriteBuffer(
            queue,
            self.uniform_buffer,
            0,
            &uniforms,
            @sizeOf(Uniforms),
        );

        c.wgpuRenderPassEncoderSetPipeline(pass, self.pipeline);
        c.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.bind_group, 0, null);
        c.wgpuRenderPassEncoderSetVertexBuffer(
            pass,
            0,
            self.vertex_buffer,
            0,
            quad_vertices.len * @sizeOf(Vertex),
        );
        c.wgpuRenderPassEncoderDraw(pass, 6, 1, 0, 0);
    }
};

fn createQuadPipeline(
    device: c.WGPUDevice,
    format: c.WGPUTextureFormat,
    bind_group_layout: c.WGPUBindGroupLayout,
) !c.WGPURenderPipeline {
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

    var bind_group_layouts = [_]c.WGPUBindGroupLayout{bind_group_layout};

    var layout_desc: c.WGPUPipelineLayoutDescriptor = std.mem.zeroes(c.WGPUPipelineLayoutDescriptor);
    layout_desc.label = stringView("quad pipeline layout");
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

    var vertex_attributes = [_]c.WGPUVertexAttribute{.{
        .format = c.WGPUVertexFormat_Float32x2,
        .offset = 0,
        .shaderLocation = 0,
    }};

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

fn createUniformBuffer(device: c.WGPUDevice) !c.WGPUBuffer {
    var desc: c.WGPUBufferDescriptor = std.mem.zeroes(c.WGPUBufferDescriptor);
    desc.label = stringView("quad uniforms");
    desc.usage = c.WGPUBufferUsage_Uniform | c.WGPUBufferUsage_CopyDst;
    desc.size = @sizeOf(Uniforms);

    return c.wgpuDeviceCreateBuffer(device, &desc) orelse {
        return Error.CreateUniformBufferFailed;
    };
}

fn createQuadBindGroupLayout(device: c.WGPUDevice) !c.WGPUBindGroupLayout {
    var entry: c.WGPUBindGroupLayoutEntry = std.mem.zeroes(c.WGPUBindGroupLayoutEntry);
    entry.binding = 0;
    entry.visibility = c.WGPUShaderStage_Vertex;
    entry.buffer.type = c.WGPUBufferBindingType_Uniform;
    entry.buffer.minBindingSize = @sizeOf(Uniforms);

    var desc: c.WGPUBindGroupLayoutDescriptor = std.mem.zeroes(c.WGPUBindGroupLayoutDescriptor);
    desc.label = stringView("quad bind group layout");
    desc.entryCount = 1;
    desc.entries = &entry;

    return c.wgpuDeviceCreateBindGroupLayout(device, &desc) orelse {
        return Error.CreateBindGroupLayoutFailed;
    };
}

fn createQuadBindGroup(
    device: c.WGPUDevice,
    layout: c.WGPUBindGroupLayout,
    uniform_buffer: c.WGPUBuffer,
) !c.WGPUBindGroup {
    var entry: c.WGPUBindGroupEntry = std.mem.zeroes(c.WGPUBindGroupEntry);
    entry.binding = 0;
    entry.buffer = uniform_buffer;
    entry.offset = 0;
    entry.size = @sizeOf(Uniforms);

    var desc: c.WGPUBindGroupDescriptor = std.mem.zeroes(c.WGPUBindGroupDescriptor);
    desc.label = stringView("quad bind group");
    desc.layout = layout;
    desc.entryCount = 1;
    desc.entries = &entry;

    return c.wgpuDeviceCreateBindGroup(device, &desc) orelse {
        return Error.CreateBindGroupFailed;
    };
}

fn createQuadVertexBuffer(device: c.WGPUDevice, queue: c.WGPUQueue) !c.WGPUBuffer {
    const vertex_data_size = quad_vertices.len * @sizeOf(Vertex);

    var desc: c.WGPUBufferDescriptor = std.mem.zeroes(c.WGPUBufferDescriptor);
    desc.label = stringView("quad vertex buffer");
    desc.usage = c.WGPUBufferUsage_Vertex | c.WGPUBufferUsage_CopyDst;
    desc.size = vertex_data_size;

    const buffer = c.wgpuDeviceCreateBuffer(device, &desc) orelse {
        return Error.CreateVertexBufferFailed;
    };

    c.wgpuQueueWriteBuffer(
        queue,
        buffer,
        0,
        quad_vertices[0..].ptr,
        vertex_data_size,
    );

    return buffer;
}

fn stringView(value: [:0]const u8) c.WGPUStringView {
    return .{
        .data = value.ptr,
        .length = c.WGPU_STRLEN,
    };
}
