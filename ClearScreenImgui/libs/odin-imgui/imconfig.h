#pragma once

// @CONFIGURE:
// This file can be filled with config lines in the same way as imconfig.h!
// These will be used in compilation, and will be written into the bindings
// However this support is _VERY VERY_ early and will probably go kablooey!

#define IMGUI_IMPL_WEBGPU_BACKEND_DAWN
// #define IMGUI_IMPL_WEBGPU_BACKEND_WGPU
#define IMGUI_DISABLE_OBSOLETE_FUNCTIONS // Required for dx12 to compile
