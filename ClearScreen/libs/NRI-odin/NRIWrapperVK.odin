// © 2021 NVIDIA Corporation

// Goal: wrapping native VK objects into NRI objects
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

NRI_WRAPPER_VK_H :: 1

VKHandle                :: rawptr
VKEnum                  :: i32
VKFlags                 :: u32
VKNonDispatchableHandle :: u64

// A collection of queues of the same type
QueueFamilyVKDesc :: struct {
	queueNum:    u32,
	queueType:   QueueType,
	familyIndex: u32,
}

DeviceCreationVKDesc :: struct {
	callbackInterface:   CallbackInterface,
	allocationCallbacks: AllocationCallbacks,
	libraryPath:         cstring,
	vkBindingOffsets:    VKBindingOffsets,
	vkExtensions:        VKExtensions, // enabled
	vkInstance:          VKHandle,
	vkDevice:            VKHandle,
	vkPhysicalDevice:    VKHandle,
	queueFamilies:       [^]QueueFamilyVKDesc,
	queueFamilyNum:      u32,
	minorVersion:        u8,           // >= 2

	// Switches (disabled by default)
	enableNRIValidation:            bool,
	enableMemoryZeroInitialization: bool, // page-clears are fast, but memory is not cleared by default in VK
}

CommandAllocatorVKDesc :: struct {
	vkCommandPool: VKNonDispatchableHandle,
	queueType:     QueueType,
}

CommandBufferVKDesc :: struct {
	vkCommandBuffer: VKHandle,
	queueType:       QueueType,
}

DescriptorPoolVKDesc :: struct {
	vkDescriptorPool:    VKNonDispatchableHandle,
	descriptorSetMaxNum: u32,
}

BufferVKDesc :: struct {
	vkBuffer:        VKNonDispatchableHandle,
	size:            u64,
	structureStride: u32,                     // must be provided if used as a structured or raw buffer
	mappedMemory:    ^u8,                     // must be provided if the underlying memory is mapped
	vkDeviceMemory:  VKNonDispatchableHandle, // must be provided *only* if the mapped memory exists and *not* HOST_COHERENT
	deviceAddress:   u64,                     // must be provided for ray tracing
}

TextureVKDesc :: struct {
	vkImage:           VKNonDispatchableHandle,
	vkFormat:          VKEnum,
	vkImageType:       VKEnum,
	vkImageUsageFlags: VKFlags,
	width:             Dim_t,
	height:            Dim_t,
	depth:             Dim_t,
	mipNum:            Dim_t,
	layerNum:          Dim_t,
	sampleNum:         Sample_t,
}

MemoryVKDesc :: struct {
	vkDeviceMemory:  VKNonDispatchableHandle,
	offset:          u64,
	mappedMemory:    rawptr, // at "offset"
	size:            u64,
	memoryTypeIndex: u32,
}

PipelineVKDesc :: struct {
	vkPipeline:          VKNonDispatchableHandle,
	vkPipelineBindPoint: VKEnum,
}

QueryPoolVKDesc :: struct {
	vkQueryPool: VKNonDispatchableHandle,
	vkQueryType: VKEnum,
}

FenceVKDesc :: struct {
	vkTimelineSemaphore: VKNonDispatchableHandle,
}

AccelerationStructureVKDesc :: struct {
	vkAccelerationStructure: VKNonDispatchableHandle,
	vkBuffer:                VKNonDispatchableHandle,
	bufferSize:              u64,
	buildScratchSize:        u64,
	updateScratchSize:       u64,
	flags:                   AccelerationStructureBits,
}

// Threadsafe: yes
WrapperVKInterface :: struct {
	CreateCommandAllocatorVK:      proc "c" (device: ^Device, commandAllocatorVKDesc: ^CommandAllocatorVKDesc, commandAllocator: ^^CommandAllocator) -> Result,
	CreateCommandBufferVK:         proc "c" (device: ^Device, commandBufferVKDesc: ^CommandBufferVKDesc, commandBuffer: ^^CommandBuffer) -> Result,
	CreateDescriptorPoolVK:        proc "c" (device: ^Device, descriptorPoolVKDesc: ^DescriptorPoolVKDesc, descriptorPool: ^^DescriptorPool) -> Result,
	CreateBufferVK:                proc "c" (device: ^Device, bufferVKDesc: ^BufferVKDesc, buffer: ^^Buffer) -> Result,
	CreateTextureVK:               proc "c" (device: ^Device, textureVKDesc: ^TextureVKDesc, texture: ^^Texture) -> Result,
	CreateMemoryVK:                proc "c" (device: ^Device, memoryVKDesc: ^MemoryVKDesc, memory: ^^Memory) -> Result,
	CreatePipelineVK:              proc "c" (device: ^Device, pipelineVKDesc: ^PipelineVKDesc, pipeline: ^^Pipeline) -> Result,
	CreateQueryPoolVK:             proc "c" (device: ^Device, queryPoolVKDesc: ^QueryPoolVKDesc, queryPool: ^^QueryPool) -> Result,
	CreateFenceVK:                 proc "c" (device: ^Device, fenceVKDesc: ^FenceVKDesc, fence: ^^Fence) -> Result,
	CreateAccelerationStructureVK: proc "c" (device: ^Device, accelerationStructureVKDesc: ^AccelerationStructureVKDesc, accelerationStructure: ^^AccelerationStructure) -> Result,
	GetQueueFamilyIndexVK:         proc "c" (queue: ^Queue) -> u32,
	GetPhysicalDeviceVK:           proc "c" (device: ^Device) -> VKHandle,
	GetInstanceVK:                 proc "c" (device: ^Device) -> VKHandle,
	GetInstanceProcAddrVK:         proc "c" (device: ^Device) -> rawptr,
	GetDeviceProcAddrVK:           proc "c" (device: ^Device) -> rawptr,
}

@(default_calling_convention="c", link_prefix="nri")
foreign lib {
	CreateDeviceFromVKDevice :: proc(deviceDesc: ^DeviceCreationVKDesc, device: ^^Device) -> Result ---
}

