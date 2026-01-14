# Nvidia NRI Samples - Odin

This repo contains samples for how to use Nvidia NRI in Odin. 

Copy NRI.dll to the root directory (precompiled in Lib/NRI-odin directory or compile NRI yourself) and SDL3.dll (copy from Odin SDL3 vendor folder).

Dependencies: 
- [NRI-odin](https://github.com/steinarb1234/NRI-odin)
- SDL3 vendor library
- [Odin Imgui bindings version 1.92+](https://github.com/steinarb1234/odin-imgui)

Note: If you want to enable device validation you need to have [Windows Graphics tools](https://learn.microsoft.com/en-us/windows/uwp/gaming/use-the-directx-runtime-and-visual-studio-graphics-diagnostic-features) enabled. Device validation should be disabled for release builds.

