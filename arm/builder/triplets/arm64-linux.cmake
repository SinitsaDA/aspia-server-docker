# 64-bit ARM (arm64, aarch64) Linux: vcpkg4aspia/triplets/arm64-linux.cmake of the developer, built
# in Release only (Router/Relay are built in Release, Debug would only double the build time).
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# As in the developer's triplets: build X11/xcb and Wayland from vcpkg as static libraries,
# otherwise the ports install empty packages and defer to the system libraries.
set(X_VCPKG_FORCE_VCPKG_X_LIBRARIES ON)
set(X_VCPKG_FORCE_VCPKG_WAYLAND_LIBRARIES ON)

set(VCPKG_BUILD_TYPE release)
