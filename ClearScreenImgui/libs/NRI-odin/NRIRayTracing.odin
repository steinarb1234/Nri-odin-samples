// © 2021 NVIDIA Corporation

// Goal: ray tracing
// https://microsoft.github.io/DirectX-Specs/d3d/Raytracing.html
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

NRI_RAY_TRACING_H :: 1

AccelerationStructure :: struct {} // bottom- or top- level acceleration structure (aka BLAS or TLAS respectively)
Micromap              :: struct {} // a micromap that encodes sub-triangle opacity (aka OMM, can be attached to a triangle BLAS)

RayTracingPipelineBitsEnum :: enum u8 {
	//============================================================================================================================================================================================
	SKIP_TRIANGLES  = 0,

	//============================================================================================================================================================================================
	SKIP_AABBS      = 1,

	//============================================================================================================================================================================================
	ALLOW_MICROMAPS = 2,
}

//============================================================================================================================================================================================
RayTracingPipelineBits :: bit_set[RayTracingPipelineBitsEnum; u8]

ShaderLibraryDesc :: struct {
	shaders:   ^ShaderDesc,
	shaderNum: u32,
}

ShaderGroupDesc :: struct {
	// Use cases:
	//  - general: RAYGEN_SHADER, MISS_SHADER or CALLABLE_SHADER
	//  - HitGroup: CLOSEST_HIT_SHADER and/or ANY_HIT_SHADER in any order
	//  - HitGroup with an intersection shader: INTERSECTION_SHADER + CLOSEST_HIT_SHADER and/or ANY_HIT_SHADER in any order
	shaderIndices: [3]u32, // in ShaderLibrary, starting from 1 (0 - unused)
}

RayTracingPipelineDesc :: struct {
	pipelineLayout:         ^PipelineLayout,
	shaderLibrary:          ^ShaderLibraryDesc,
	shaderGroups:           [^]ShaderGroupDesc,
	shaderGroupNum:         u32,
	recursionMaxDepth:      u32,
	rayPayloadMaxSize:      u32,
	rayHitAttributeMaxSize: u32,
	flags:                  RayTracingPipelineBits,
	robustness:             Robustness,
}

//============================================================================================================================================================================================
MicromapFormat :: enum u16 {
	//============================================================================================================================================================================================
	OPACITY_2_STATE = 1,

	//============================================================================================================================================================================================
	OPACITY_4_STATE = 2,

	//============================================================================================================================================================================================
	MAX_NUM         = 3,
}

MicromapSpecialIndex :: enum i8 {
	FULLY_TRANSPARENT         = -1,
	FULLY_OPAQUE              = -2,
	FULLY_UNKNOWN_TRANSPARENT = -3,
	FULLY_UNKNOWN_OPAQUE      = -4,
	MAX_NUM                   = -3,
}

MicromapBitsEnum :: enum u8 {
	ALLOW_COMPACTION  = 1,
	PREFER_FAST_TRACE = 2,
	PREFER_FAST_BUILD = 3,
}

MicromapBits :: bit_set[MicromapBitsEnum; u8]

MicromapUsageDesc :: struct {
	triangleNum:      u32, // represents "MicromapTriangle" number for "{format, subdivisionLevel}" pair contained in the micromap
	subdivisionLevel: u16, // micro triangles count = 4 ^ subdivisionLevel
	format:           MicromapFormat,
}

MicromapDesc :: struct {
	optimizedSize: u64, // can be retrieved by "CmdWriteMicromapsSizes" and used for compaction via "CmdCopyMicromap"
	usages:        ^MicromapUsageDesc,
	usageNum:      u32,
	flags:         MicromapBits,
}

BindMicromapMemoryDesc :: struct {
	micromap: ^Micromap,
	memory:   ^Memory,
	offset:   u64,
}

BuildMicromapDesc :: struct {
	dst:            ^Micromap,
	dataBuffer:     ^Buffer,
	dataOffset:     u64,
	triangleBuffer: ^Buffer, // contains "MicromapTriangle" entries
	triangleOffset: u64,
	scratchBuffer:  ^Buffer,
	scratchOffset:  u64,
}

BottomLevelMicromapDesc :: struct {
	// For each triangle in the geometry, the acceleration structure build fetches an index from "indexBuffer".
	// If an index is the unsigned cast of one of the values from "MicromapSpecialIndex" then that triangle behaves as described for that special value.
	// Otherwise that triangle uses the micromap information from "micromap" at that index plus "baseTriangle".
	// If an index buffer is not provided, "1:1" mapping between geometry triangles and micromap triangles is assumed.
	micromap:     ^Micromap,
	indexBuffer:  ^Buffer,
	indexOffset:  u64,
	baseTriangle: u32,
	indexType:    IndexType,
}

// Data layout
MicromapTriangle :: struct {
	dataOffset:       u32,
	subdivisionLevel: u16,
	format:           MicromapFormat,
}

//============================================================================================================================================================================================
BottomLevelGeometryType :: enum u8 {
	//============================================================================================================================================================================================
	TRIANGLES = 0,

	//============================================================================================================================================================================================
	AABBS     = 1,

	//============================================================================================================================================================================================
	MAX_NUM   = 2,
}

BottomLevelGeometryBitsEnum :: enum u8 {
	OPAQUE_GEOMETRY                 = 0,
	NO_DUPLICATE_ANY_HIT_INVOCATION = 1,
}

BottomLevelGeometryBits :: bit_set[BottomLevelGeometryBitsEnum; u8]

BottomLevelTrianglesDesc :: struct {
	// Vertices
	vertexBuffer: ^Buffer,
	vertexOffset: u64,
	vertexNum:    u32,
	vertexStride: u16,
	vertexFormat: Format,

	// Indices
	indexBuffer: ^Buffer,
	indexOffset: u64,
	indexNum:    u32,
	indexType:   IndexType,

	// Transform
	transformBuffer: ^Buffer, // contains "TransformMatrix" entries
	transformOffset: u64,

	// Micromap
	micromap: ^BottomLevelMicromapDesc,
}

BottomLevelAabbsDesc :: struct {
	buffer: ^Buffer, // contains "BottomLevelAabb" entries
	offset: u64,
	num:    u32,
	stride: u32,
}

BottomLevelGeometryDesc :: struct {
	flags: BottomLevelGeometryBits,
	type:  BottomLevelGeometryType,

	using _: struct #raw_union {
		triangles: BottomLevelTrianglesDesc,
		aabbs:     BottomLevelAabbsDesc,
	},
}

// Data layout
TransformMatrix :: struct {
	transform: [3][4]f32, // 3x4 row-major affine transformation matrix, the first three columns of matrix must define an invertible 3x3 matrix
}

BottomLevelAabb :: struct {
	minX: f32,
	minY: f32,
	minZ: f32,
	maxX: f32,
	maxY: f32,
	maxZ: f32,
}

TopLevelInstanceBitsEnum :: enum u32 {
	//============================================================================================================================================================================================
	TRIANGLE_CULL_DISABLE = 0,

	//============================================================================================================================================================================================
	TRIANGLE_FLIP_FACING  = 1,

	//============================================================================================================================================================================================
	FORCE_OPAQUE          = 2,

	//============================================================================================================================================================================================
	FORCE_NON_OPAQUE      = 3,

	//============================================================================================================================================================================================
	FORCE_OPACITY_2_STATE = 4,

	//============================================================================================================================================================================================
	DISABLE_MICROMAPS     = 5,
}

//============================================================================================================================================================================================
TopLevelInstanceBits :: bit_set[TopLevelInstanceBitsEnum; u32]

TopLevelInstance :: struct {
	transform:                     [3][4]f32,
	instanceId:                    u32,
	mask:                          u32,
	shaderBindingTableLocalOffset: u32,
	flags:                         TopLevelInstanceBits,
	accelerationStructureHandle:   u64,
}

//============================================================================================================================================================================================
AccelerationStructureType :: enum u8 {
	//============================================================================================================================================================================================
	TOP_LEVEL    = 0,

	//============================================================================================================================================================================================
	BOTTOM_LEVEL = 1,

	//============================================================================================================================================================================================
	MAX_NUM      = 2,
}

AccelerationStructureBitsEnum :: enum u8 {
	ALLOW_UPDATE            = 0,
	ALLOW_COMPACTION        = 1,
	ALLOW_DATA_ACCESS       = 2,
	ALLOW_MICROMAP_UPDATE   = 3,
	ALLOW_DISABLE_MICROMAPS = 4,
	PREFER_FAST_TRACE       = 5,
	PREFER_FAST_BUILD       = 6,
	MINIMIZE_MEMORY         = 7,
}
AccelerationStructureBits :: bit_set[AccelerationStructureBitsEnum; u8]

AccelerationStructureDesc :: struct {
	optimizedSize:         u64,                        // can be retrieved by "CmdWriteAccelerationStructuresSizes" and used for compaction via "CmdCopyAccelerationStructure"
	geometries:            [^]BottomLevelGeometryDesc, // needed only for "BOTTOM_LEVEL", "HAS_BUFFER" can be used to indicate a buffer presence (no real entities needed at initialization time)
	geometryOrInstanceNum: u32,
	flags:                 AccelerationStructureBits,
	type:                  AccelerationStructureType,
}

BindAccelerationStructureMemoryDesc :: struct {
	accelerationStructure: ^AccelerationStructure,
	memory:                ^Memory,
	offset:                u64,
}

BuildTopLevelAccelerationStructureDesc :: struct {
	dst:            ^AccelerationStructure,
	src:            ^AccelerationStructure, // implies "update" instead of "build" if provided (requires "ALLOW_UPDATE")
	instanceNum:    u32,
	instanceBuffer: ^Buffer,                // contains "TopLevelInstance" entries
	instanceOffset: u64,
	scratchBuffer:  ^Buffer,                // use "GetAccelerationStructureBuildScratchBufferSize" or "GetAccelerationStructureUpdateScratchBufferSize" to determine the required size
	scratchOffset:  u64,
}

BuildBottomLevelAccelerationStructureDesc :: struct {
	dst:           ^AccelerationStructure,
	src:           ^AccelerationStructure, // implies "update" instead of "build" if provided (requires "ALLOW_UPDATE")
	geometries:    [^]BottomLevelGeometryDesc,
	geometryNum:   u32,
	scratchBuffer: ^Buffer,
	scratchOffset: u64,
}

//============================================================================================================================================================================================
CopyMode :: enum u8 {
	//============================================================================================================================================================================================
	CLONE   = 0,

	//============================================================================================================================================================================================
	COMPACT = 1,

	//============================================================================================================================================================================================
	MAX_NUM = 2,
}

StridedBufferRegion :: struct {
	buffer: ^Buffer,
	offset: u64,
	size:   u64,
	stride: u64,
}

DispatchRaysDesc :: struct {
	raygenShader:    StridedBufferRegion,
	missShaders:     StridedBufferRegion,
	hitShaderGroups: StridedBufferRegion,
	callableShaders: StridedBufferRegion,
	x, y, z:         u32,
}

DispatchRaysIndirectDesc :: struct {
	raygenShaderRecordAddress:         u64,
	raygenShaderRecordSize:            u64,
	missShaderBindingTableAddress:     u64,
	missShaderBindingTableSize:        u64,
	missShaderBindingTableStride:      u64,
	hitShaderBindingTableAddress:      u64,
	hitShaderBindingTableSize:         u64,
	hitShaderBindingTableStride:       u64,
	callableShaderBindingTableAddress: u64,
	callableShaderBindingTableSize:    u64,
	callableShaderBindingTableStride:  u64,
	x, y, z:                           u32,
}

// Threadsafe: yes
RayTracingInterface :: struct {
	// Create
	CreateRayTracingPipeline:              proc "c" (device: ^Device, rayTracingPipelineDesc: ^RayTracingPipelineDesc, pipeline: ^^Pipeline) -> Result,
	CreateAccelerationStructureDescriptor: proc "c" (accelerationStructure: ^AccelerationStructure, descriptor: ^^Descriptor) -> Result,

	// Get
	GetAccelerationStructureHandle:                  proc "c" (accelerationStructure: ^AccelerationStructure) -> u64,
	GetAccelerationStructureUpdateScratchBufferSize: proc "c" (accelerationStructure: ^AccelerationStructure) -> u64,
	GetAccelerationStructureBuildScratchBufferSize:  proc "c" (accelerationStructure: ^AccelerationStructure) -> u64,
	GetMicromapBuildScratchBufferSize:               proc "c" (micromap: ^Micromap) -> u64,

	// For barriers
	GetAccelerationStructureBuffer: proc "c" (accelerationStructure: ^AccelerationStructure) -> ^Buffer,
	GetMicromapBuffer:              proc "c" (micromap: ^Micromap) -> ^Buffer,

	// Destroy
	DestroyAccelerationStructure: proc "c" (accelerationStructure: ^AccelerationStructure),
	DestroyMicromap:              proc "c" (micromap: ^Micromap),

	// Resources and memory (VK style)
	CreateAccelerationStructure:        proc "c" (device: ^Device, accelerationStructureDesc: ^AccelerationStructureDesc, accelerationStructure: ^^AccelerationStructure) -> Result,
	CreateMicromap:                     proc "c" (device: ^Device, micromapDesc: ^MicromapDesc, micromap: ^^Micromap) -> Result,
	GetAccelerationStructureMemoryDesc: proc "c" (accelerationStructure: ^AccelerationStructure, memoryLocation: MemoryLocation, memoryDesc: ^MemoryDesc),
	GetMicromapMemoryDesc:              proc "c" (micromap: ^Micromap, memoryLocation: MemoryLocation, memoryDesc: ^MemoryDesc),
	BindAccelerationStructureMemory:    proc "c" (bindAccelerationStructureMemoryDescs: [^]BindAccelerationStructureMemoryDesc, bindAccelerationStructureMemoryDescNum: u32) -> Result,
	BindMicromapMemory:                 proc "c" (bindMicromapMemoryDescs: [^]BindMicromapMemoryDesc, bindMicromapMemoryDescNum: u32) -> Result,

	// Resources and memory (D3D12 style)
	GetAccelerationStructureMemoryDesc2:  proc "c" (device: ^Device, accelerationStructureDesc: ^AccelerationStructureDesc, memoryLocation: MemoryLocation, memoryDesc: ^MemoryDesc), // requires "features.getMemoryDesc2"
	GetMicromapMemoryDesc2:               proc "c" (device: ^Device, micromapDesc: ^MicromapDesc, memoryLocation: MemoryLocation, memoryDesc: ^MemoryDesc), // requires "features.getMemoryDesc2"
	CreateCommittedAccelerationStructure: proc "c" (device: ^Device, memoryLocation: MemoryLocation, priority: f32, accelerationStructureDesc: ^AccelerationStructureDesc, accelerationStructure: ^^AccelerationStructure) -> Result,
	CreateCommittedMicromap:              proc "c" (device: ^Device, memoryLocation: MemoryLocation, priority: f32, micromapDesc: ^MicromapDesc, micromap: ^^Micromap) -> Result,
	CreatePlacedAccelerationStructure:    proc "c" (device: ^Device, memory: ^Memory, offset: u64, accelerationStructureDesc: ^AccelerationStructureDesc, accelerationStructure: ^^AccelerationStructure) -> Result,
	CreatePlacedMicromap:                 proc "c" (device: ^Device, memory: ^Memory, offset: u64, micromapDesc: ^MicromapDesc, micromap: ^^Micromap) -> Result,

	// Shader table
	// "dst" size must be >= "shaderGroupNum * rayTracingShaderGroupIdentifierSize" bytes
	// VK doesn't have a "local root signature" analog, thus stride = "rayTracingShaderGroupIdentifierSize", i.e. tight packing
	WriteShaderGroupIdentifiers: proc "c" (pipeline: ^Pipeline, baseShaderGroupIndex: u32, shaderGroupNum: u32, dst: rawptr) -> Result,

	// Command buffer
	// {
	// Micromap
	CmdBuildMicromaps:      proc "c" (commandBuffer: ^CommandBuffer, buildMicromapDescs: [^]BuildMicromapDesc, buildMicromapDescNum: u32),
	CmdWriteMicromapsSizes: proc "c" (commandBuffer: ^CommandBuffer, micromaps: [^]^Micromap, micromapNum: u32, queryPool: ^QueryPool, queryPoolOffset: u32),
	CmdCopyMicromap:        proc "c" (commandBuffer: ^CommandBuffer, dst: ^Micromap, src: ^Micromap, copyMode: CopyMode),

	// Acceleration structure
	CmdBuildTopLevelAccelerationStructures:    proc "c" (commandBuffer: ^CommandBuffer, buildTopLevelAccelerationStructureDescs: [^]BuildTopLevelAccelerationStructureDesc, buildTopLevelAccelerationStructureDescNum: u32),
	CmdBuildBottomLevelAccelerationStructures: proc "c" (commandBuffer: ^CommandBuffer, buildBotomLevelAccelerationStructureDescs: [^]BuildBottomLevelAccelerationStructureDesc, buildBotomLevelAccelerationStructureDescNum: u32),
	CmdWriteAccelerationStructuresSizes:       proc "c" (commandBuffer: ^CommandBuffer, accelerationStructures: [^]^AccelerationStructure, accelerationStructureNum: u32, queryPool: ^QueryPool, queryPoolOffset: u32),
	CmdCopyAccelerationStructure:              proc "c" (commandBuffer: ^CommandBuffer, dst: ^AccelerationStructure, src: ^AccelerationStructure, copyMode: CopyMode),

	// Ray tracing
	CmdDispatchRays:         proc "c" (commandBuffer: ^CommandBuffer, dispatchRaysDesc: ^DispatchRaysDesc),
	CmdDispatchRaysIndirect: proc "c" (commandBuffer: ^CommandBuffer, buffer: ^Buffer, offset: u64), // buffer contains "DispatchRaysIndirectDesc" commands

	// }
	
	// Native object
	GetAccelerationStructureNativeObject: proc "c" (accelerationStructure: ^AccelerationStructure) -> u64, // ID3D12Resource* or VkAccelerationStructureKHR
	GetMicromapNativeObject:              proc "c" (micromap: ^Micromap) -> u64,                           // ID3D12Resource* or VkMicromapEXT
}

