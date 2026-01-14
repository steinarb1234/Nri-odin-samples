// © 2021 NVIDIA Corporation

// Goal: wrapping native D3D12 objects into NRI objects
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

NRI_WRAPPER_D3D12_H :: 1

DXGIFormat                :: i32
AGSContext                :: struct {}
ID3D12Heap                :: struct {}
ID3D12Fence               :: struct {}
ID3D12Device              :: struct {}
ID3D12Resource            :: struct {}
ID3D12CommandQueue        :: struct {}
ID3D12DescriptorHeap      :: struct {}
ID3D12CommandAllocator    :: struct {}
ID3D12GraphicsCommandList :: struct {}

// A collection of queues of the same type
QueueFamilyD3D12Desc :: struct {
	d3d12Queues: [^]^ID3D12CommandQueue, // if not provided, will be created
	queueNum:    u32,
	queueType:   QueueType,
}

DeviceCreationD3D12Desc :: struct {
	d3d12Device:          ^ID3D12Device,
	queueFamilies:        [^]QueueFamilyD3D12Desc,
	queueFamilyNum:       u32,
	agsContext:           ^AGSContext,
	callbackInterface:    CallbackInterface,
	allocationCallbacks:  AllocationCallbacks,
	d3dShaderExtRegister: u32, // vendor specific shader extensions (default is "NRI_SHADER_EXT_REGISTER", space is always "0")
	d3dZeroBufferSize:    u32, // no "memset" functionality in D3D, "CmdZeroBuffer" implemented via a bunch of copies (4 Mb by default)

	// Switches (disabled by default)
	enableNRIValidation:            bool,
	enableMemoryZeroInitialization: bool, // page-clears are fast, not enabled by default to match VK (the extension needed)

	// Switches (enabled by default)
	disableD3D12EnhancedBarriers: bool, // even if AgilitySDK is in use, some apps still use legacy barriers. It can be important for integrations
	disableNVAPIInitialization:   bool, // at least NVAPI requires calling "NvAPI_Initialize" in DLL/EXE where the device is created
}

CommandBufferD3D12Desc :: struct {
	d3d12CommandList:      ^ID3D12GraphicsCommandList,
	d3d12CommandAllocator: ^ID3D12CommandAllocator, // needed only for "BeginCommandBuffer"
}

DescriptorPoolD3D12Desc :: struct {
	d3d12ResourceDescriptorHeap: ^ID3D12DescriptorHeap,
	d3d12SamplerDescriptorHeap:  ^ID3D12DescriptorHeap,

	// Allocation limits (D3D12 unrelated, but must match expected usage)
	descriptorSetMaxNum: u32,
}

BufferD3D12Desc :: struct {
	d3d12Resource:   ^ID3D12Resource,
	desc:            ^BufferDesc, // not all information can be retrieved from the resource if not provided
	structureStride: u32,         // must be provided if used as a structured or raw buffer
}

TextureD3D12Desc :: struct {
	d3d12Resource: ^ID3D12Resource,
	format:        DXGIFormat, // must be provided "as a compatible typed format" if the resource is typeless
}

MemoryD3D12Desc :: struct {
	d3d12Heap: ^ID3D12Heap,
	offset:    u64,
}

FenceD3D12Desc :: struct {
	d3d12Fence: ^ID3D12Fence,
}

AccelerationStructureD3D12Desc :: struct {
	d3d12Resource: ^ID3D12Resource,
	flags:         AccelerationStructureBits,

	// D3D12_RAYTRACING_ACCELERATION_STRUCTURE_PREBUILD_INFO
	size:              u64,
	buildScratchSize:  u64,
	updateScratchSize: u64,
}

// Threadsafe: yes
WrapperD3D12Interface :: struct {
	CreateCommandBufferD3D12:         proc "c" (device: ^Device, commandBufferD3D12Desc: ^CommandBufferD3D12Desc, commandBuffer: ^^CommandBuffer) -> Result,
	CreateDescriptorPoolD3D12:        proc "c" (device: ^Device, descriptorPoolD3D12Desc: ^DescriptorPoolD3D12Desc, descriptorPool: ^^DescriptorPool) -> Result,
	CreateBufferD3D12:                proc "c" (device: ^Device, bufferD3D12Desc: ^BufferD3D12Desc, buffer: ^^Buffer) -> Result,
	CreateTextureD3D12:               proc "c" (device: ^Device, textureD3D12Desc: ^TextureD3D12Desc, texture: ^^Texture) -> Result,
	CreateMemoryD3D12:                proc "c" (device: ^Device, memoryD3D12Desc: ^MemoryD3D12Desc, memory: ^^Memory) -> Result,
	CreateFenceD3D12:                 proc "c" (device: ^Device, fenceD3D12Desc: ^FenceD3D12Desc, fence: ^^Fence) -> Result,
	CreateAccelerationStructureD3D12: proc "c" (device: ^Device, accelerationStructureD3D12Desc: ^AccelerationStructureD3D12Desc, accelerationStructure: ^^AccelerationStructure) -> Result,
}

@(default_calling_convention="c", link_prefix="nri")
foreign lib {
	CreateDeviceFromD3D12Device :: proc(deviceDesc: ^DeviceCreationD3D12Desc, device: ^^Device) -> Result ---
}

