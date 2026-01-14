// © 2021 NVIDIA Corporation

// Goal: device creation
package NRI

import "core:c"

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

NRI_DEVICE_CREATION_H :: 1

Message :: enum u8 {
	INFO    = 0,
	WARNING = 1,
	ERROR   = 2,
	MAX_NUM = 3,
}

// Callbacks must be thread safe
AllocationCallbacks :: struct {
	Allocate:                           proc "c" (userArg: rawptr, size: c.size_t, alignment: c.size_t) -> rawptr,
	Reallocate:                         proc "c" (userArg: rawptr, memory: rawptr, size: c.size_t, alignment: c.size_t) -> rawptr,
	Free:                               proc "c" (userArg: rawptr, memory: rawptr),
	userArg:                            rawptr,
	disable3rdPartyAllocationCallbacks: bool, // to use "AllocationCallbacks" only for NRI needs
}

CallbackInterface :: struct {
	MessageCallback: proc "c" (messageType: Message, file: cstring, line: u32, message: cstring, userArg: rawptr),
	AbortExecution:  proc "c" (userArg: rawptr), // break on "Message::ERROR" if provided
	userArg:         rawptr,
}

// Use largest offset for the resource type planned to be used as an unbounded array
VKBindingOffsets :: struct {
	sRegister: u32, // samplers
	tRegister: u32, // shader resources, including acceleration structures (SRVs)
	bRegister: u32, // constant buffers
	uRegister: u32, // storage shader resources (UAVs)
}

VKExtensions :: struct {
	instanceExtensions:   [^]cstring,
	instanceExtensionNum: u32,
	deviceExtensions:     [^]cstring,
	deviceExtensionNum:   u32,
}

// A collection of queues of the same type
QueueFamilyDesc :: struct {
	queuePriorities: [^]f32, // [-1; 1]: low < 0, normal = 0, high > 0 ("queueNum" entries expected)
	queueNum:        u32,
	queueType:       QueueType,
}

DeviceCreationDesc :: struct {
	graphicsAPI:         GraphicsAPI,
	robustness:          Robustness,
	adapterDesc:         ^AdapterDesc,
	callbackInterface:   CallbackInterface,
	allocationCallbacks: AllocationCallbacks,

	// One "GRAPHICS" queue is created by default
	queueFamilies:  [^]QueueFamilyDesc,
	queueFamilyNum: u32, // put "GRAPHICS" queue at the beginning of the list

	// D3D specific
	d3dShaderExtRegister: u32, // vendor specific shader extensions (default is "NRI_SHADER_EXT_REGISTER", space is always "0")
	d3dZeroBufferSize:    u32, // no "memset" functionality in D3D, "CmdZeroBuffer" implemented via a bunch of copies (4 Mb by default)

	// Vulkan specific
	vkBindingOffsets: VKBindingOffsets,
	vkExtensions:     VKExtensions, // to enable

	// Switches (disabled by default)
	enableNRIValidation:               bool, // embedded validation layer, checks for NRI specifics
	enableGraphicsAPIValidation:       bool, // GAPI-provided validation layer
	enableD3D11CommandBufferEmulation: bool, // enable? but why? (auto-enabled if deferred contexts are not supported)
	enableD3D12RayTracingValidation:   bool, // slow but useful, can only be enabled if envvar "NV_ALLOW_RAYTRACING_VALIDATION" is set to "1"
	enableMemoryZeroInitialization:    bool, // page-clears are fast, but memory is not cleared by default in VK

	// Switches (enabled by default)
	disableVKRayTracing:          bool, // to save CPU memory in some implementations
	disableD3D12EnhancedBarriers: bool, // even if AgilitySDK is in use, some apps still use legacy barriers. It can be important for integrations
}

@(default_calling_convention="c", link_prefix="nri")
foreign lib {
	// if "adapterDescs == NULL", then "adapterDescNum" is set to the number of adapters
	// else "adapterDescNum" must be set to number of elements in "adapterDescs"
	EnumerateAdapters :: proc(adapterDescs: [^]AdapterDesc, adapterDescNum: ^u32) -> Result ---
	CreateDevice      :: proc(deviceCreationDesc: ^DeviceCreationDesc, device: ^^Device) -> Result ---
	DestroyDevice     :: proc(device: ^Device) ---

	// It's global state for D3D, not needed for VK because validation is tied to the logical device
	ReportLiveObjects :: proc() ---
}

