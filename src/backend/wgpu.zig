const std = @import("std");

const c = @cImport({
    @cInclude("webgpu/wgpu.h");
});

const sdl = @cImport({
    @cDefine("SDL_MAIN_HANDLED", "1");
    @cInclude("SDL3/SDL.h");
});

pub const Error = error{
    CreateInstanceFailed,
    CreateSurfaceFailed,
    UnsupportedWindowBackend,
    RequestAdapterFailed,
    RequestDeviceFailed,
    SurfaceCapabilitiesFailed,
    SurfaceFormatUnavailable,
    SurfaceAcquireFailed,
    CreateTextureViewFailed,
    CreateCommandEncoderFailed,
    CreateRenderPassFailed,
    CreateCommandBufferFailed,
    PresentFailed,
};

/// Owns the wgpu object needed to present frames into an SDL-created window
pub const Gpu = struct {
    width: u32,
    height: u32,

    instance: c.WGPUInstance,
    surface: c.WGPUSurface,
    adapter: c.WGPUAdapter,
    device: c.WGPUDevice,
    queue: c.WGPUQueue,
    format: c.WGPUTextureFormat,

    /// Creates a wgpu surface form the SDL window and configures it for presentation
    pub fn init(window_ptr: *anyopaque, width: u32, height: u32) !Gpu {
        var desc: c.WGPUInstanceDescriptor = std.mem.zeroes(c.WGPUInstanceDescriptor);

        const instance = c.wgpuCreateInstance(&desc) orelse return Error.CreateInstanceFailed;
        errdefer c.wgpuInstanceRelease(instance);

        const surface = try createSurface(instance, window_ptr);
        errdefer c.wgpuSurfaceRelease(surface);

        const adapter = try requestAdapter(instance, surface);
        errdefer c.wgpuAdapterRelease(adapter);

        const device = try requestDevice(instance, adapter);
        errdefer c.wgpuDeviceRelease(device);

        const queue = c.wgpuDeviceGetQueue(device);
        errdefer c.wgpuQueueRelease(queue);

        var capabilities: c.WGPUSurfaceCapabilities = std.mem.zeroes(c.WGPUSurfaceCapabilities);
        if (c.wgpuSurfaceGetCapabilities(surface, adapter, &capabilities) != c.WGPUStatus_Success) {
            return Error.SurfaceCapabilitiesFailed;
        }
        defer c.wgpuSurfaceCapabilitiesFreeMembers(capabilities);
        std.log.info("wgpu surface configured: {d}x{d}", .{ width, height });

        if (capabilities.formatCount == 0) return Error.SurfaceFormatUnavailable;

        const format = capabilities.formats[0];
        const alpha_mode = if (capabilities.alphaModeCount > 0) capabilities.alphaModes[0] else c.WGPUCompositeAlphaMode_Auto;

        var config: c.WGPUSurfaceConfiguration = std.mem.zeroes(c.WGPUSurfaceConfiguration);
        config.device = device;
        config.format = format;
        config.usage = c.WGPUTextureUsage_RenderAttachment;
        config.width = width;
        config.height = height;
        config.alphaMode = alpha_mode;
        config.presentMode = c.WGPUPresentMode_Fifo;

        c.wgpuSurfaceConfigure(surface, &config);

        return Gpu{
            .width = width,
            .height = height,
            .instance = instance,
            .surface = surface,
            .adapter = adapter,
            .device = device,
            .queue = queue,
            .format = format,
        };
    }

    /// Clears and presents one frame
    pub fn render(self: *Gpu) !void {
        var surface_texture: c.WGPUSurfaceTexture = std.mem.zeroes(c.WGPUSurfaceTexture);
        c.wgpuSurfaceGetCurrentTexture(self.surface, &surface_texture);

        switch (surface_texture.status) {
            c.WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal,
            c.WGPUSurfaceGetCurrentTextureStatus_SuccessSuboptimal,
            => {},
            else => return Error.SurfaceAcquireFailed,
        }

        defer c.wgpuTextureRelease(surface_texture.texture);

        var view_desc: c.WGPUTextureViewDescriptor =
            std.mem.zeroes(c.WGPUTextureViewDescriptor);
        view_desc.format = self.format;
        view_desc.dimension = c.WGPUTextureViewDimension_2D;
        view_desc.baseMipLevel = 0;
        view_desc.mipLevelCount = 1;
        view_desc.baseArrayLayer = 0;
        view_desc.arrayLayerCount = 1;
        view_desc.aspect = c.WGPUTextureAspect_All;
        view_desc.usage = c.WGPUTextureUsage_RenderAttachment;

        const view = c.wgpuTextureCreateView(surface_texture.texture, &view_desc) orelse {
            return Error.CreateTextureViewFailed;
        };
        defer c.wgpuTextureViewRelease(view);

        var encoder_desc: c.WGPUCommandEncoderDescriptor =
            std.mem.zeroes(c.WGPUCommandEncoderDescriptor);

        const encoder = c.wgpuDeviceCreateCommandEncoder(self.device, &encoder_desc) orelse {
            return Error.CreateCommandEncoderFailed;
        };
        defer c.wgpuCommandEncoderRelease(encoder);

        var color_attachment: c.WGPURenderPassColorAttachment = std.mem.zeroes(c.WGPURenderPassColorAttachment);
        color_attachment.view = view;
        color_attachment.depthSlice = c.WGPU_DEPTH_SLICE_UNDEFINED;
        color_attachment.loadOp = c.WGPULoadOp_Clear;
        color_attachment.storeOp = c.WGPUStoreOp_Store;
        color_attachment.clearValue = .{
            .r = 0.97,
            .g = 0.10,
            .b = 0.16,
            .a = 1.0,
        };

        var pass_desc: c.WGPURenderPassDescriptor =
            std.mem.zeroes(c.WGPURenderPassDescriptor);
        pass_desc.colorAttachmentCount = 1;
        pass_desc.colorAttachments = &color_attachment;

        const pass = c.wgpuCommandEncoderBeginRenderPass(encoder, &pass_desc) orelse {
            return Error.CreateRenderPassFailed;
        };

        c.wgpuRenderPassEncoderEnd(pass);
        c.wgpuRenderPassEncoderRelease(pass);

        var command_desc: c.WGPUCommandBufferDescriptor =
            std.mem.zeroes(c.WGPUCommandBufferDescriptor);

        const command = c.wgpuCommandEncoderFinish(encoder, &command_desc) orelse {
            return Error.CreateCommandBufferFailed;
        };
        defer c.wgpuCommandBufferRelease(command);

        c.wgpuQueueSubmit(self.queue, 1, &command);

        if (c.wgpuSurfacePresent(self.surface) != c.WGPUStatus_Success) {
            return Error.PresentFailed;
        }
    }

    /// Releases wgpu handles owned by this GPU context
    pub fn deinit(self: *Gpu) void {
        c.wgpuQueueRelease(self.queue);
        c.wgpuDeviceRelease(self.device);
        c.wgpuAdapterRelease(self.adapter);
        c.wgpuSurfaceRelease(self.surface);
        c.wgpuInstanceRelease(self.instance);
        self.* = undefined;
    }
};

const AdapterRequest = struct {
    done: bool = false,
    adapter: ?c.WGPUAdapter = null,
    status: c.WGPURequestAdapterStatus = c.WGPURequestAdapterStatus_Unknown,
};

const DeviceRequest = struct {
    done: bool = false,
    device: ?c.WGPUDevice = null,
    status: c.WGPURequestDeviceStatus = c.WGPURequestDeviceStatus_Unknown,
};

fn requestDevice(instance: c.WGPUInstance, adapter: c.WGPUAdapter) !c.WGPUDevice {
    var request: DeviceRequest = .{};

    var descriptor: c.WGPUDeviceDescriptor = std.mem.zeroes(c.WGPUDeviceDescriptor);

    var callback_info: c.WGPURequestDeviceCallbackInfo = std.mem.zeroes(c.WGPURequestDeviceCallbackInfo);
    callback_info.mode = c.WGPUCallbackMode_AllowProcessEvents;
    callback_info.callback = requestDeviceCallback;
    callback_info.userdata1 = &request;

    _ = c.wgpuAdapterRequestDevice(adapter, &descriptor, callback_info);

    while (!request.done) {
        c.wgpuInstanceProcessEvents(instance);
    }

    if (request.status != c.WGPURequestDeviceStatus_Success) {
        return Error.RequestDeviceFailed;
    }

    return request.device orelse Error.RequestDeviceFailed;
}

fn requestDeviceCallback(
    status: c.WGPURequestDeviceStatus,
    device: c.WGPUDevice,
    message: c.WGPUStringView,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
) callconv(.c) void {
    _ = message;
    _ = userdata2;

    const request: *DeviceRequest = @ptrCast(@alignCast(userdata1.?));
    request.status = status;
    request.device = device;
    request.done = true;
}

fn requestAdapter(instance: c.WGPUInstance, surface: c.WGPUSurface) !c.WGPUAdapter {
    var request: AdapterRequest = .{};

    var options: c.WGPURequestAdapterOptions = std.mem.zeroes(c.WGPURequestAdapterOptions);
    options.featureLevel = c.WGPUFeatureLevel_Core;
    options.powerPreference = c.WGPUPowerPreference_HighPerformance;
    options.compatibleSurface = surface;

    var callback_info: c.WGPURequestAdapterCallbackInfo = std.mem.zeroes(c.WGPURequestAdapterCallbackInfo);
    callback_info.mode = c.WGPUCallbackMode_AllowProcessEvents;
    callback_info.callback = requestAdapterCallback;
    callback_info.userdata1 = &request;

    _ = c.wgpuInstanceRequestAdapter(instance, &options, callback_info);

    while (!request.done) {
        c.wgpuInstanceProcessEvents(instance);
    }

    if (request.status != c.WGPURequestAdapterStatus_Success) {
        return Error.RequestAdapterFailed;
    }

    return request.adapter orelse Error.RequestAdapterFailed;
}

fn requestAdapterCallback(
    status: c.WGPURequestAdapterStatus,
    adapter: c.WGPUAdapter,
    message: c.WGPUStringView,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
) callconv(.c) void {
    _ = message;
    _ = userdata2;

    const request: *AdapterRequest = @ptrCast(@alignCast(userdata1.?));
    request.status = status;
    request.adapter = adapter;
    request.done = true;
}

// SDL exposes Wayland handles as pointers and X11 windows as numeric IDs
fn createSurface(instance: c.WGPUInstance, window_ptr: *anyopaque) !c.WGPUSurface {
    const window: *sdl.SDL_Window = @ptrCast(@alignCast(window_ptr));
    const props = sdl.SDL_GetWindowProperties(window);

    const wayland_display = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null);
    const wayland_surface = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null);

    const x11_display = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null);
    // const x11_surface = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, null);
    const x11_window = sdl.SDL_GetNumberProperty(props, sdl.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);

    if (wayland_display != null and wayland_surface != null) {
        var source: c.WGPUSurfaceSourceWaylandSurface = std.mem.zeroes(c.WGPUSurfaceSourceWaylandSurface);
        source.chain.sType = c.WGPUSType_SurfaceSourceWaylandSurface;
        source.display = wayland_display;
        source.surface = wayland_surface;

        var surface_desc: c.WGPUSurfaceDescriptor =
            std.mem.zeroes(c.WGPUSurfaceDescriptor);
        surface_desc.nextInChain = &source.chain;

        return c.wgpuInstanceCreateSurface(instance, &surface_desc) orelse
            Error.CreateSurfaceFailed;
    } else if (x11_display != null and x11_window != 0) {
        var source: c.WGPUSurfaceSourceXlibWindow = std.mem.zeroes(c.WGPUSurfaceSourceXlibWindow);
        source.chain.sType = c.WGPUSType_SurfaceSourceXlibWindow;
        source.display = x11_display;
        source.window = @intCast(x11_window);

        var surface_desc: c.WGPUSurfaceDescriptor =
            std.mem.zeroes(c.WGPUSurfaceDescriptor);
        surface_desc.nextInChain = &source.chain;

        return c.wgpuInstanceCreateSurface(instance, &surface_desc) orelse
            Error.CreateSurfaceFailed;
    }

    return Error.UnsupportedWindowBackend;
}

// pub fn probeWindowBackend(window_ptr: *anyopaque) void {
//     const window: *sdl.SDL_Window = @ptrCast(@alignCast(window_ptr));
//     const props = sdl.SDL_GetWindowProperties(window);
//
//     const wayland_display = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null);
//     const wayland_surface = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null);
//
//     const x11_display = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null);
//     const x11_surface = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, null);
//
//     if (wayland_display != null and wayland_surface != null) {
//         std.debug.print("wgpu surface backend: wayland\n", .{});
//     } else if (x11_display != null and x11_surface != null) {
//         std.debug.print("wgpu surface backend: x11\n", .{});
//     } else {
//         std.debug.print("wgpu surface backend: unsupported/unknown\n", .{});
//     }
// }
