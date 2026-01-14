// © 2024 NVIDIA Corporation

// Goal: minimizing latency between input sampling and frame presentation
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

NRI_LOW_LATENCY_H :: 1

// us = microseconds
LatencyMarker :: enum u8 {
	// us = microseconds
	SIMULATION_START    = 0, // Should be called:

	// us = microseconds
	SIMULATION_END      = 1, // Should be called:

	// us = microseconds
	RENDER_SUBMIT_START = 2, // Should be called:

	// us = microseconds
	RENDER_SUBMIT_END   = 3, // Should be called:

	// us = microseconds
	INPUT_SAMPLE        = 6, // Should be called:

	// us = microseconds
	MAX_NUM             = 7, // Should be called:
} // Should be called:

LatencySleepMode :: struct {
	minIntervalUs:   u32,  // minimum allowed frame interval (0 - no frame rate limit)
	lowLatencyMode:  bool, // low latency mode enablement
	lowLatencyBoost: bool, // hint to increase performance to provide additional latency savings at a cost of increased power consumption
}

LatencyReport :: struct {
	inputSampleTimeUs:        u64, // when "INPUT_SAMPLE" marker is set
	simulationStartTimeUs:    u64, // when "SIMULATION_START" marker is set
	simulationEndTimeUs:      u64, // when "SIMULATION_END" marker is set
	renderSubmitStartTimeUs:  u64, // when "RENDER_SUBMIT_START" marker is set
	renderSubmitEndTimeUs:    u64, // when "RENDER_SUBMIT_END" marker is set
	presentStartTimeUs:       u64, // right before "Present"
	presentEndTimeUs:         u64, // right after "Present"
	driverStartTimeUs:        u64, // when the first "QueueSubmitTrackable" is called
	driverEndTimeUs:          u64, // when the final "QueueSubmitTrackable" hands off from the driver
	osRenderQueueStartTimeUs: u64,
	osRenderQueueEndTimeUs:   u64,
	gpuRenderStartTimeUs:     u64, // when the first submission reaches the GPU
	gpuRenderEndTimeUs:       u64, // when the final submission finishes on the GPU
} // The time stamp written:

// Multi-swapchain is supported only by VK
// "QueueSubmitDesc::swapChain" must be used to associate work submission with a low latency swap chain
// Threadsafe: no
LowLatencyInterface :: struct {
	SetLatencySleepMode: proc "c" (swapChain: ^SwapChain, latencySleepMode: ^LatencySleepMode) -> Result,
	SetLatencyMarker:    proc "c" (swapChain: ^SwapChain, latencyMarker: LatencyMarker) -> Result,
	LatencySleep:        proc "c" (swapChain: ^SwapChain) -> Result, // call once before "INPUT_SAMPLE"
	GetLatencyReport:    proc "c" (swapChain: ^SwapChain, latencyReport: ^LatencyReport) -> Result,
}

