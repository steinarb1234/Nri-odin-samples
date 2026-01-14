// © 2021 NVIDIA Corporation

// Goal: presentation functionality
package NRI

when ODIN_DEBUG {
	@(private = "file")
	lib_path :: "./Lib/Debug/"
} else {
	@(private = "file")
	lib_path :: "./Lib/Release/"
}

when ODIN_OS == .Windows {
	when ODIN_ARCH == .amd64 {
		foreign import lib {lib_path + "NRI.lib", "system:dxgi.lib", "system:dxguid.lib", "system:d3d12.lib", "system:d3d11.lib", "system:User32.lib"}
	// } else when ODIN_ARCH == .arm64 {
		// foreign import lib {lib_path + "aarch64-windows.lib"}
	} else do #panic("Unsupported architecture")
// } else when ODIN_OS == .Linux { // Todo: add linux binaries
	// when ODIN_ARCH == .amd64 {
	// 	foreign import lib {lib_path + "libx86_64-linux.a"}
	// } else when ODIN_ARCH == .arm64 {
	// 	foreign import lib {lib_path + "libaarch64-linux.a"}
	// } else do #panic("Unsupported architecture")
} else do #panic("Unsupported OS")

NRI_SWAP_CHAIN_H :: 1

// Color space:
//  - BT.709 - LDR https://en.wikipedia.org/wiki/Rec._709
//  - BT.2020 - HDR https://en.wikipedia.org/wiki/Rec._2020
// Transfer function:
//  - G10 - linear (gamma 1.0)
//  - G22 - sRGB (gamma ~2.2)
//  - G2084 - SMPTE ST.2084 (Perceptual Quantization)
// Bits per channel:
//  - 8, 10, 16 (float)
SwapChainFormat :: enum u8 {
	// Transfer function:
	//  - G10 - linear (gamma 1.0)
	//  - G22 - sRGB (gamma ~2.2)
	//  - G2084 - SMPTE ST.2084 (Perceptual Quantization)
	// Bits per channel:
	//  - 8, 10, 16 (float)
	BT709_G10_16BIT    = 0,

	// Transfer function:
	//  - G10 - linear (gamma 1.0)
	//  - G22 - sRGB (gamma ~2.2)
	//  - G2084 - SMPTE ST.2084 (Perceptual Quantization)
	// Bits per channel:
	//  - 8, 10, 16 (float)
	BT709_G22_8BIT     = 1,

	// Transfer function:
	//  - G10 - linear (gamma 1.0)
	//  - G22 - sRGB (gamma ~2.2)
	//  - G2084 - SMPTE ST.2084 (Perceptual Quantization)
	// Bits per channel:
	//  - 8, 10, 16 (float)
	BT709_G22_10BIT    = 2,

	// Transfer function:
	//  - G10 - linear (gamma 1.0)
	//  - G22 - sRGB (gamma ~2.2)
	//  - G2084 - SMPTE ST.2084 (Perceptual Quantization)
	// Bits per channel:
	//  - 8, 10, 16 (float)
	BT2020_G2084_10BIT = 3,

	// Transfer function:
	//  - G10 - linear (gamma 1.0)
	//  - G22 - sRGB (gamma ~2.2)
	//  - G2084 - SMPTE ST.2084 (Perceptual Quantization)
	// Bits per channel:
	//  - 8, 10, 16 (float)
	MAX_NUM            = 4,
}

// https://registry.khronos.org/vulkan/specs/latest/man/html/VkPresentScalingFlagBitsKHR.html
Scaling :: enum u8 {
	ONE_TO_ONE = 0,
	STRETCH    = 1,
	MAX_NUM    = 2,
}

// https://registry.khronos.org/vulkan/specs/latest/man/html/VkPresentGravityFlagBitsKHR.html
Gravity :: enum u8 {
	MIN      = 0,
	MAX      = 1,
	CENTERED = 2,
	MAX_NUM  = 3,
}

SwapChainBitsEnum :: enum u8 {
	VSYNC             = 0,
	WAITABLE          = 1,
	ALLOW_TEARING     = 2,
	ALLOW_LOW_LATENCY = 3,
}

SwapChainBits :: bit_set[SwapChainBitsEnum; u8]

WindowsWindow :: struct {
	hwnd: rawptr, //    HWND
} // Expects "WIN32" platform macro

X11Window :: struct {
	dpy:    rawptr, //    Display
	window: u64,    //    Window
} // Expects "NRI_ENABLE_XLIB_SUPPORT"

WaylandWindow :: struct {
	display: rawptr, //    wl_display
	surface: rawptr, //    wl_surface
} // Expects "NRI_ENABLE_WAYLAND_SUPPORT"

MetalWindow :: struct {
	caMetalLayer: rawptr, //    CAMetalLayer
} // Expects "APPLE" platform macro

Window :: struct {
	// Only one entity must be initialized
	windows: WindowsWindow,
	x11:     X11Window,
	wayland: WaylandWindow,
	metal:   MetalWindow,
}

// SwapChain textures will be created as "color attachment" resources
// queuedFrameNum = 0 - auto-selection between 1 (for waitable) or 2 (otherwise)
// queuedFrameNum = 2 - recommended if the GPU frame time is less than the desired frame time, but the sum of 2 frames is greater
SwapChainDesc :: struct {
	window:         Window,
	queue:          ^Queue,          // GRAPHICS or COMPUTE (requires "features.presentFromCompute")
	width:          Dim_t,
	height:         Dim_t,
	textureNum:     u8,              // desired value, real value must be queried using "GetSwapChainTextures"
	format:         SwapChainFormat, // desired format, real value must be queried using "GetTextureDesc" for one of the swap chain textures
	flags:          SwapChainBits,
	queuedFrameNum: u8,              // aka "max frame latency", aka "number of frames in flight" (mostly for D3D11)

	// Present scaling and positioning, silently ignored if "features.resizableSwapChain" is not supported
	scaling:  Scaling, // VK: if scaling is not supported, "OUT_OF_DATE" error is triggered on resizing
	gravityX: Gravity,
	gravityY: Gravity,
}

ChromaticityCoords :: struct {
	x, y: f32, // [0; 1]
}

// Describes color settings and capabilities of the closest display:
//  - Luminance provided in nits (cd/m2)
//  - SDR = standard dynamic range
//  - LDR = low dynamic range (in many cases LDR == SDR)
//  - HDR = high dynamic range, assumes G2084:
//      - BT709_G10_16BIT: HDR gets enabled and applied implicitly if Windows HDR is enabled
//      - BT2020_G2084_10BIT: HDR requires explicit color conversions and enabled HDR in Windows
//  - "SDR scale in HDR mode" = sdrLuminance / 80
DisplayDesc :: struct {
	redPrimary:            ChromaticityCoords,
	greenPrimary:          ChromaticityCoords,
	bluePrimary:           ChromaticityCoords,
	whitePoint:            ChromaticityCoords,
	minLuminance:          f32,
	maxLuminance:          f32,
	maxFullFrameLuminance: f32,
	sdrLuminance:          f32,
	isHDR:                 bool,
}

// Threadsafe: yes
SwapChainInterface :: struct {
	CreateSwapChain:      proc "c" (device: ^Device, swapChainDesc: ^SwapChainDesc, swapChain: ^^SwapChain) -> Result,
	DestroySwapChain:     proc "c" (swapChain: ^SwapChain),
	GetSwapChainTextures: proc "c" (swapChain: ^SwapChain, textureNum: ^u32) -> [^]^Texture,

	// Returns "FAILURE" if swap chain's window is outside of all monitors
	GetDisplayDesc: proc "c" (swapChain: ^SwapChain, displayDesc: ^DisplayDesc) -> Result,

	// VK only: may return "OUT_OF_DATE", fences must be created with "SWAPCHAIN_SEMAPHORE" initial value
	AcquireNextTexture: proc "c" (swapChain: ^SwapChain, acquireSemaphore: ^Fence, textureIndex: ^u32) -> Result,
	WaitForPresent:     proc "c" (swapChain: ^SwapChain) -> Result, // call once right before input sampling (must be called starting from the 1st frame)
	QueuePresent:       proc "c" (swapChain: ^SwapChain, releaseSemaphore: ^Fence) -> Result,
}

