// © 2021 NVIDIA Corporation

// Goal: mesh shaders
// https://www.khronos.org/blog/mesh-shading-for-vulkan
// https://microsoft.github.io/DirectX-Specs/d3d/MeshShader.html
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

NRI_MESH_SHADER_H :: 1

DrawMeshTasksDesc :: struct {
	x, y, z: u32,
}

// Threadsafe: no
MeshShaderInterface :: struct {
	// Command buffer
	// {
	// Draw
	CmdDrawMeshTasks:         proc "c" (commandBuffer: ^CommandBuffer, drawMeshTasksDesc: ^DrawMeshTasksDesc),
	CmdDrawMeshTasksIndirect: proc "c" (commandBuffer: ^CommandBuffer, buffer: ^Buffer, offset: u64, drawNum: u32, stride: u32, countBuffer: ^Buffer, countBufferOffset: u64), // buffer contains "DrawMeshTasksDesc" commands
}

