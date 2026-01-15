package main

import "core:fmt"
import "core:sys/windows"
import "core:os"
import sdl "vendor:sdl3"

// Nvidia NRI
import nri "libs/NRI-odin"

NRI_ABORT_ON_FAILURE :: proc(result: nri.Result, location := #caller_location) {
    if result != .SUCCESS {
        fmt.eprintfln("NRI failure: %v at %s:%d", result, location.file_path, location.line)
        nri.DestroyDevice(device)
        os.exit(-1)
    }
}

NRI_Interface :: struct {
    using core     : nri.CoreInterface,
    using swapchain: nri.SwapChainInterface,
    using helper   : nri.HelperInterface,
}

SwapChainTexture :: struct {
    acquire_semaphore: ^nri.Fence,
    release_semaphore: ^nri.Fence,
    texture          : ^nri.Texture,
    color_attachment : ^nri.Descriptor,
    attachment_format: nri.Format,
};

Frame :: struct {
    command_allocator             : ^nri.CommandAllocator,
    command_buffer                : ^nri.CommandBuffer,
    constant_buffer_view          : ^nri.Descriptor,
    constant_buffer_descriptor_set: ^nri.DescriptorSet,
    constant_buffer_view_offset   : u64,
}

vsync_interval :: false
when vsync_interval {queued_frame_num :: 2}
else                {queued_frame_num :: 3}

swapchain_textures : [queued_frame_num + 1]SwapChainTexture

window : ^sdl.Window
window_height : i32 = 768
window_width  : i32 = 1024

device : ^nri.Device

main :: proc() {
    // Init SDL and create window
    ok := sdl.Init({.AUDIO, .VIDEO}); sdl_assert(ok) 
    defer sdl.Quit()

    window = sdl.CreateWindow("Hello World!", window_width, window_height, {.RESIZABLE}); sdl_assert(window != nil)
	defer sdl.DestroyWindow(window)

    // -------- Init NRI ---------
    graphics_api := nri.GraphicsAPI.D3D12

	adapters_num : u32 = 1 // This should choose the best adapter (graphics card)
	adapter_desc : nri.AdapterDesc // Getting multiple adapters with [^]nri.AdapterDesc is buggy
	NRI_ABORT_ON_FAILURE(nri.EnumerateAdapters(&adapter_desc, &adapters_num))
    // fmt.printfln("Adapter: %v", adapter_desc)

    callback_interface := nri.CallbackInterface {
        MessageCallback = nri_message_callback,
        AbortExecution  = nri_abort_callback,
        userArg         = nil,
    }
    device_creation_desc := nri.DeviceCreationDesc{
        graphicsAPI                      = graphics_api,
        // robustness                       = Robustness,
        adapterDesc                      = &adapter_desc,
        callbackInterface                = callback_interface,
        // allocationCallbacks              = AllocationCallbacks,
        // queueFamilies                    = ^QueueFamilyDesc,
        // queueFamilyNum                   = u32,
        // d3dShaderExtRegister             = u32,
        // d3dZeroBufferSize                = u32,
        // vkBindingOffsets                 = VKBindingOffsets,
        // vkExtensions                     = VKExtensions,
        enableNRIValidation              = true,
        enableGraphicsAPIValidation      = true, // Note: Enabled causes lag for window interactions
        // enableD3D11CommandBufferEmulation= bool,
        // enableD3D12RayTracingValidation  = bool,
        // enableMemoryZeroInitialization   = bool,
        // disableVKRayTracing              = bool,
        // disableD3D12EnhancedBarriers     = bool,
    }
    if nri.CreateDevice(&device_creation_desc, &device) != .SUCCESS {
        fmt.printfln("Failed to init nri device")
        os.exit(-1)
    }
    
    NRI: NRI_Interface
    NRI_ABORT_ON_FAILURE(nri.GetInterface(device, "NriCoreInterface", size_of(NRI.core), &NRI.core))
    NRI_ABORT_ON_FAILURE(nri.GetInterface(device, "NriSwapChainInterface", size_of(NRI.swapchain), &NRI.swapchain))
    NRI_ABORT_ON_FAILURE(nri.GetInterface(device, "NriHelperInterface", size_of(NRI.helper), &NRI.helper))

    command_queue : ^nri.Queue
    NRI_ABORT_ON_FAILURE(NRI.GetQueue(device, .GRAPHICS, 0, &command_queue))
    
    frame_fence : ^nri.Fence
    NRI_ABORT_ON_FAILURE(NRI.CreateFence(device, 0, &frame_fence))
    
    window_handle := sdl.GetPointerProperty(sdl.GetWindowProperties(window), sdl.PROP_WINDOW_WIN32_HWND_POINTER, nil)
    
    // Create swapchain
    nri_swapchain_desc := nri.SwapChainDesc{
        window        = {
            windows = nri.WindowsWindow{window_handle},
            // x11     = nri.X11Window,
            // wayland = nri.WaylandWindow,
            // metal   = nri.MetalWindow,
        },
        queue         = command_queue,
        width         = nri.Dim_t(window_width),
        height        = nri.Dim_t(window_height),
        textureNum    = queued_frame_num + 1, // frambuffers
        format        = .BT709_G22_8BIT,
        // flags         = SwapChainBits,
        queuedFrameNum= queued_frame_num,
        scaling       = .STRETCH,
        // gravityX      = Gravity,
        // gravityY      = Gravity,
    }
    swapchain : ^nri.SwapChain
    NRI_ABORT_ON_FAILURE(NRI.CreateSwapChain(device, &nri_swapchain_desc, &swapchain))

    swapchain_format : nri.Format
    { // Create swapchain textures
        swapchain_texture_num: u32
        nri_swapchain_textures := NRI.GetSwapChainTextures(swapchain, &swapchain_texture_num)
        swapchain_format = NRI.GetTextureDesc(nri_swapchain_textures[0]).format
        for i:u32=0; i<swapchain_texture_num; i+=1 {
            texture_view_desc := nri.Texture2DViewDesc{nri_swapchain_textures[i], .COLOR_ATTACHMENT, swapchain_format, 0, 0, 0, 0, {}}

            color_attachment : ^nri.Descriptor
            NRI_ABORT_ON_FAILURE(NRI.CreateTexture2DView(&texture_view_desc, &color_attachment))

            SWAPCHAIN_SEMAPHORE :: ~u64(0)

            acquire_semaphore : ^nri.Fence
            NRI_ABORT_ON_FAILURE(NRI.CreateFence(device, SWAPCHAIN_SEMAPHORE, &acquire_semaphore))

            release_semaphore : ^nri.Fence
            NRI_ABORT_ON_FAILURE(NRI.CreateFence(device, SWAPCHAIN_SEMAPHORE, &release_semaphore))

            swapchain_texture := SwapChainTexture{
                acquire_semaphore = acquire_semaphore,
                release_semaphore = release_semaphore,
                texture           = nri_swapchain_textures[i],
                color_attachment  = color_attachment,
                attachment_format = swapchain_format,
            }

            swapchain_textures[i] = swapchain_texture
        }
    }
    
    frames : [queued_frame_num]Frame 
    for &frame in frames[:] {
        NRI_ABORT_ON_FAILURE(NRI.CreateCommandAllocator(command_queue, &frame.command_allocator))
        NRI_ABORT_ON_FAILURE(NRI.CreateCommandBuffer(frame.command_allocator, &frame.command_buffer))
    }

    frame_index : u64 = 0
    game_loop: for {

        queued_frame_index := frame_index % queued_frame_num
        queued_frame := frames[queued_frame_index]
		{ // Latency sleep
			wait_value := frame_index >= queued_frame_num ? 1 + frame_index - queued_frame_num : 0
			NRI.Wait(frame_fence, u64(wait_value))

			NRI.ResetCommandAllocator(queued_frame.command_allocator)
		}

        { // Handle keyboard and mouse input
			e: sdl.Event
			for sdl.PollEvent(&e) {
				#partial switch e.type {
                    case .QUIT:
                        break game_loop
                        
					case .KEY_DOWN: // holding .KEY_DOWN has a delay then repeats downs, designed for writing text
						#partial switch e.key.scancode {
						case .ESCAPE:
							break game_loop
					}
                }
            }
		}

        // Acquire swapchain texture
        recycled_semaphore_index := frame_index % len(swapchain_textures)
        swapchain_acquire_semaphore := swapchain_textures[recycled_semaphore_index].acquire_semaphore

        current_swapchain_texture_index : u32 = 0
        NRI.AcquireNextTexture(swapchain, swapchain_acquire_semaphore, &current_swapchain_texture_index)

        swapchain_texture := swapchain_textures[current_swapchain_texture_index]

        command_buffer := queued_frame.command_buffer
        
        NRI.BeginCommandBuffer(command_buffer, nil)
        {
            texture_barriers := nri.TextureBarrierDesc{
                texture    = swapchain_texture.texture,
                // before     = AccessLayoutStage,
                after      = {
                    access = nri.ACCESSBITS_COLOR_ATTACHMENT,
                    layout = .COLOR_ATTACHMENT,
                    // stages = {.COLOR_ATTACHMENT},
                },
                // mipOffset  = Dim_t,
                mipNum     = 1,               // can be "REMAINING"
                // layerOffset= Dim_t,
                layerNum   = 1,               // can be "REMAINING"
                // planes     = PlaneBits,
                // srcQueue   = ^Queue,
                // dstQueue   = ^Queue,
            }

            barrier_desc := nri.BarrierDesc{
                // globals   = [^]GlobalBarrierDesc,
                // globalNum = u32,
                // buffers   = [^]BufferBarrierDesc,
                // bufferNum = u32,
                textures  = &texture_barriers,
                textureNum= 1,
            }
            NRI.CmdBarrier(command_buffer, &barrier_desc)

            color_attachment_desc := nri.AttachmentDesc{
                descriptor= swapchain_texture.color_attachment,
                clearValue= {
                    // depthStencil= DepthStencil,
                    color = {
                        f = {1.0, 0.0, 0.0, 1.0}
                    },
                },
                loadOp    = .CLEAR,
                // storeOp   = StoreOp,
                // resolveOp = ResolveOp,
                // resolveDst= ^Descriptor,   // must be valid during "CmdEndRendering"
            }

            rendering_desc := nri.RenderingDesc{
                colors     = &color_attachment_desc,
                colorNum   = 1,
                // depth      = AttachmentDesc,      // may be treated as "depth-stencil"
                // stencil    = AttachmentDesc,      // (optional) separation is needed for multisample resolve
                // shadingRate= ^Descriptor,         // requires "tiers.shadingRate >= 2"
                // viewMask   = 0,                 // if non-0, requires "viewMaxNum > 1"

            }

            NRI.CmdBeginRendering(command_buffer, &rendering_desc)
            {
                { // Clear screen
					NRI.CmdBeginAnnotation(command_buffer, "Clear screen", 0); defer(NRI.CmdEndAnnotation(command_buffer))

	                clear_desc := nri.ClearAttachmentDesc{
	                    value = {
	                        color = {
	                            f = {1.0, 0.0, 0.0, 1.0}
	                        }
	                    },
	                    planes = {.COLOR},
	                    colorAttachmentIndex= 0,
	                }
	                rect1 := nri.Rect{0, 0, nri.Dim_t(window_width), nri.Dim_t(window_height)}
	                NRI.CmdClearAttachments(command_buffer, &clear_desc, 1, &rect1, 1)
				}
            }
            NRI.CmdEndRendering(command_buffer)

            texture_barriers.before = texture_barriers.after
            texture_barriers.after = {
                access = {},
                layout = .PRESENT,
                stages = nri.STAGEBITS_NONE,
            }
            NRI.CmdBarrier(command_buffer, &barrier_desc)
        }
        NRI.EndCommandBuffer(command_buffer)

        { // Submit
            texture_acquired_fence := nri.FenceSubmitDesc{
                fence = swapchain_acquire_semaphore,
                stages= {.COLOR_ATTACHMENT},
            }

            rendering_finished_fence := nri.FenceSubmitDesc{
                fence = swapchain_texture.release_semaphore
            }

            queue_submit_desc := nri.QueueSubmitDesc{
                waitFences      = &texture_acquired_fence,
                waitFenceNum    = 1,
                commandBuffers  = &queued_frame.command_buffer,
                commandBufferNum= 1,
                signalFences    = &rendering_finished_fence,
                signalFenceNum  = 1,
                swapChain       = swapchain, // required if "NRILowLatency" is enabled in the swap chain
            }
            NRI.QueueSubmit(command_queue, &queue_submit_desc)
        }

        // Present
        NRI.QueuePresent(swapchain, swapchain_texture.release_semaphore)

        { // Signaling after "Present" improves D3D11 performance a bit
            signal_fence := nri.FenceSubmitDesc{
                fence = frame_fence,
                value = 1 + frame_index
            }

            queue_submit_desc := nri.QueueSubmitDesc{
                signalFences = &signal_fence,
                signalFenceNum = 1
            }

            NRI.QueueSubmit(command_queue, &queue_submit_desc)
        }

        frame_index += 1

    }

    // Destroy 
    nri.DestroyDevice(device)

}
