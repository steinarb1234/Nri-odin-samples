// © 2025 NVIDIA Corporation

// Goal: providing easy-to-use access to modern upscalers: DLSS, FSR, XESS, NIS
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

NRI_UPSCALER_H :: 1

Upscaler     :: struct {}

UpscalerType :: enum u8 {
	NIS     = 0, // Name                                     // Notes
	FSR     = 1, // Name                                     // Notes
	XESS    = 2, // Name                                     // Notes
	DLSR    = 3, // Name                                     // Notes
	DLRR    = 4, // Name                                     // Notes
	MAX_NUM = 5, // Name                                     // Notes
} // Name                                     // Notes

UpscalerMode :: enum u8 {
	NATIVE            = 0, // Scaling factor       // Min jitter phases (or just use unclamped Halton2D)
	ULTRA_QUALITY     = 1, // Scaling factor       // Min jitter phases (or just use unclamped Halton2D)
	QUALITY           = 2, // Scaling factor       // Min jitter phases (or just use unclamped Halton2D)
	BALANCED          = 3, // Scaling factor       // Min jitter phases (or just use unclamped Halton2D)
	PERFORMANCE       = 4, // Scaling factor       // Min jitter phases (or just use unclamped Halton2D)
	ULTRA_PERFORMANCE = 5, // Scaling factor       // Min jitter phases (or just use unclamped Halton2D)
	MAX_NUM           = 6, // Scaling factor       // Min jitter phases (or just use unclamped Halton2D)
} // Scaling factor       // Min jitter phases (or just use unclamped Halton2D)

UpscalerBitsEnum :: enum u16 {
	HDR            = 0,
	SRGB           = 1,
	USE_EXPOSURE   = 2,
	USE_REACTIVE   = 3,
	DEPTH_INVERTED = 4,
	DEPTH_INFINITE = 5,
	DEPTH_LINEAR   = 6,
	MV_UPSCALED    = 7,
	MV_JITTERED    = 8,
}

UpscalerBits :: bit_set[UpscalerBitsEnum; u16]

DispatchUpscaleBitsEnum :: enum u8 {
	RESET_HISTORY       = 0,
	USE_SPECULAR_MOTION = 1,
}

DispatchUpscaleBits :: bit_set[DispatchUpscaleBitsEnum; u8]

UpscalerDesc :: struct {
	upscaleResolution: Dim2_t,         // output resolution
	type:              UpscalerType,
	mode:              UpscalerMode,   // not needed for NIS
	flags:             UpscalerBits,
	preset:            u8,             // preset for DLSR or XESS (0 default, >1 presets A, B, C...)
	commandBuffer:     ^CommandBuffer, // a non-copy-only command buffer in opened state, submission must be done manually ("wait for idle" executed, if not provided)
}

UpscalerProps :: struct {
	scalingFactor:       f32,    // per dimension scaling factor
	mipBias:             f32,    // mip bias for materials textures, computed as "-log2(scalingFactor) - 1" (keep an eye on normal maps)
	upscaleResolution:   Dim2_t, // output resolution
	renderResolution:    Dim2_t, // optimal render resolution
	renderResolutionMin: Dim2_t, // minimal render resolution (for Dynamic Resolution Scaling)
	jitterPhaseNum:      u8,     // minimal number of phases in the jitter sequence, computed as "ceil(8 * scalingFactor ^ 2)" ("Halton(2, 3)" recommended)
}

UpscalerResource :: struct {
	texture:    ^Texture,
	descriptor: ^Descriptor, // "SHADER_RESOURCE" or "SHADER_RESOURCE_STORAGE", see comments below
}

// Guide buffers
UpscalerGuides :: struct {
	mv:       UpscalerResource, // .xy - surface motion
	depth:    UpscalerResource, // .x - HW depth
	exposure: UpscalerResource, // .x - 1x1 exposure
	reactive: UpscalerResource, // .x - bias towards "input"
} // For FSR, XESS, DLSR

DenoiserGuides :: struct {
	mv:               UpscalerResource, // .xy - surface motion
	depth:            UpscalerResource, // .x - HW or linear depth
	normalRoughness:  UpscalerResource, // .xyz - world-space normal (not encoded), .w - linear roughness
	diffuseAlbedo:    UpscalerResource, // .xyz - diffuse albedo (LDR sky color for sky)
	specularAlbedo:   UpscalerResource, // .xyz - specular albedo (environment BRDF)
	specularMvOrHitT: UpscalerResource, // .xy - specular virtual motion of the reflected world, or .x - specular hit distance otherwise
	exposure:         UpscalerResource, // .x - 1x1 exposure
	reactive:         UpscalerResource, // .x - bias towards "input"
	sss:              UpscalerResource, // .x - subsurface scattering, computed as "Luminance(colorAfterSSS - colorBeforeSSS)"
} // For DLRR

// Settings
NISSettings :: struct {
	sharpness: f32, // [0; 1]
}

FSRSettings :: struct {
	zNear:                   f32, // distance to the near plane (units)
	zFar:                    f32, // distance to the far plane, unused if "DEPTH_INFINITE" is set (units)
	verticalFov:             f32, // vertical field of view angle (radians)
	frameTime:               f32, // the time elapsed since the last frame (ms)
	viewSpaceToMetersFactor: f32, // for converting view space units to meters (m/unit)
	sharpness:               f32, // [0; 1]
}

DLRRSettings :: struct {
	worldToViewMatrix: [16]f32, // {Xx, Yx, Zx, 0, Xy, Yy, Zy, 0, Xz, Yz, Zz, 0, Tx, Ty, Tz, 1}, where {X, Y, Z} - axises, T - translation
	viewToClipMatrix:  [16]f32, // {-, -, -, 0, -, -, -, 0, -, -, -, A, -, -, -, B}, where {A; B} = {0; 1} for ortho or {-1/+1; 0} for perspective projections
}

DispatchUpscaleDesc :: struct {
	// Output (required "SHADER_RESOURCE_STORAGE" for resource state & descriptor)
	output: UpscalerResource, // .xyz - upscaled RGB color

	// Input (required "SHADER_RESOURCE" for resource state & descriptor)
	input: UpscalerResource, // .xyz - input RGB color

	guides: struct #raw_union {
		upscaler: UpscalerGuides, //      FSR, XESS, DLSR
		denoiser: DenoiserGuides, //      DLRR (sRGB not supported)
	},

	settings: struct #raw_union {
		nis:  NISSettings,  //      NIS settings
		fsr:  FSRSettings,  //      FSR settings
		dlrr: DLRRSettings, //      DLRR settings
	},

	currentResolution: Dim2_t,   // current render resolution for inputs and guides, renderResolutionMin <= currentResolution <= renderResolution
	cameraJitter:      Float2_t, // pointing towards the pixel center, in [-0.5; 0.5] range
	mvScale:           Float2_t, // used to convert motion vectors to pixel space
	flags:             DispatchUpscaleBits,
}

// Threadsafe: yes
UpscalerInterface :: struct {
	CreateUpscaler:      proc "c" (device: ^Device, upscalerDesc: ^UpscalerDesc, upscaler: ^^Upscaler) -> Result,
	DestroyUpscaler:     proc "c" (upscaler: ^Upscaler),
	IsUpscalerSupported: proc "c" (device: ^Device, type: UpscalerType) -> bool,
	GetUpscalerProps:    proc "c" (upscaler: ^Upscaler, upscalerProps: ^UpscalerProps),

	// Command buffer
	// {
	// Dispatch (changes descriptor pool, pipeline layout and pipeline, barriers are externally controlled)
	CmdDispatchUpscale: proc "c" (commandBuffer: ^CommandBuffer, upscaler: ^Upscaler, dispatchUpscaleDesc: ^DispatchUpscaleDesc),
}

