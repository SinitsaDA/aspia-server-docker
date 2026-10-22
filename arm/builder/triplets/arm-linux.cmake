# 32-bit ARM (armv7, armhf) Linux, by the example of vcpkg4aspia/triplets/arm64-linux.cmake.
set(VCPKG_TARGET_ARCHITECTURE arm)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# As in the developer's triplets: build X11/xcb and Wayland from vcpkg as static libraries,
# otherwise the ports install empty packages and defer to the system libraries.
set(X_VCPKG_FORCE_VCPKG_X_LIBRARIES ON)
set(X_VCPKG_FORCE_VCPKG_WAYLAND_LIBRARIES ON)

# Release only: Router/Relay are built in Release, and the Debug (-O0) build of libyuv's NEON
# inline assembly fails on 32-bit ARM ("'asm' operand has impossible constraints").
set(VCPKG_BUILD_TYPE release)

# Debian armhf compiles without NEON by default (-mfpu=vfpv3-d16, safe for any ARMv7 CPU).
# Opus tries to build its NEON intrinsics anyway and fails ("target specific option mismatch"):
# use its plain C code instead (audio is not used by Router/Relay).
if(PORT STREQUAL "opus")
    set(VCPKG_CMAKE_CONFIGURE_OPTIONS -DOPUS_DISABLE_INTRINSICS=ON)
endif()
