// © 2021 NVIDIA Corporation

// Goal: wrapping native D3D11 objects into NRI objects
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

NRI_WRAPPER_D3D11_H :: 1

// DXGIFormat          :: i32	// Commented out to avoid duplicates with D3D12 wrapper
// AGSContext          :: struct {}	// Commented out to avoid duplicates with D3D12 wrapper
ID3D11Device        :: struct {}
ID3D11Resource      :: struct {}
ID3D11DeviceContext :: struct {}

DeviceCreationD3D11Desc :: struct {
	d3d11Device:          ^ID3D11Device,
	agsContext:           ^AGSContext,
	callbackInterface:    CallbackInterface,
	allocationCallbacks:  AllocationCallbacks,
	d3dShaderExtRegister: u32, // vendor specific shader extensions (default is "NRI_SHADER_EXT_REGISTER", space is always "0")
	d3dZeroBufferSize:    u32, // no "memset" functionality in D3D, "CmdZeroBuffer" implemented via a bunch of copies (4 Mb by default)

	// Switches (disabled by default)
	enableNRIValidation:               bool, // embedded validation layer, checks for NRI specifics
	enableD3D11CommandBufferEmulation: bool, // enable? but why? (auto-enabled if deferred contexts are not supported)

	// Switches (enabled by default)
	disableNVAPIInitialization: bool, // at least NVAPI requires calling "NvAPI_Initialize" in DLL/EXE where the device is created
}

CommandBufferD3D11Desc :: struct {
	d3d11DeviceContext: ^ID3D11DeviceContext,
}

BufferD3D11Desc :: struct {
	d3d11Resource: ^ID3D11Resource,
	desc:          ^BufferDesc, // not all information can be retrieved from the resource if not provided
}

TextureD3D11Desc :: struct {
	d3d11Resource: ^ID3D11Resource,
	format:        DXGIFormat, // must be provided "as a compatible typed format" if the resource is typeless
}

// Threadsafe: yes
WrapperD3D11Interface :: struct {
	CreateCommandBufferD3D11: proc "c" (device: ^Device, commandBufferD3D11Desc: ^CommandBufferD3D11Desc, commandBuffer: ^^CommandBuffer) -> Result,
	CreateBufferD3D11:        proc "c" (device: ^Device, bufferD3D11Desc: ^BufferD3D11Desc, buffer: ^^Buffer) -> Result,
	CreateTextureD3D11:       proc "c" (device: ^Device, textureD3D11Desc: ^TextureD3D11Desc, texture: ^^Texture) -> Result,
}

@(default_calling_convention="c", link_prefix="nri")
foreign lib {
	CreateDeviceFromD3D11Device :: proc(deviceDesc: ^DeviceCreationD3D11Desc, device: ^^Device) -> Result ---
}

