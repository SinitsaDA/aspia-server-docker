#!/bin/bash
#
# Builds aspia_router and aspia_relay for 32-bit ARM (armv7, vcpkg triplet arm-linux) inside the
# builder image and packs them into the release archives:
#   out/aspia-server-<version>-linux-armv7.tar.gz       plain binaries
#   out/aspia-server-<version>-linux-armv7-upx.tar.gz   UPX-compressed binaries (MikroTik image)
# with a .sha256 file next to each.
#
#   docker build -t aspia-armv7-builder arm/builder
#   docker run --rm -v "$PWD/work:/work" -v "$PWD/arm/builder:/scripts:ro" aspia-armv7-builder \
#       bash /scripts/build.sh 3.1.2
#
# /work keeps the sources, the vcpkg binary cache and the downloads: a second run continues where
# the previous one stopped. The developer of Aspia does not build for armv7, so a few things are
# adjusted in the local copy of the sources (see below).

set -euo pipefail

VERSION="${1:?usage: build.sh <aspia version>}"
JOBS="${JOBS:-$(nproc)}"
SRC=/work/aspia-${VERSION}
OUT=/work/out
TRIPLETS="$(cd "$(dirname "$0")" && pwd)/triplets"

export VCPKG_DEFAULT_BINARY_CACHE=/work/vcpkg-cache
export VCPKG_DOWNLOADS=/work/vcpkg-downloads
export VCPKG_MAX_CONCURRENCY="${JOBS}"
export CMAKE_BUILD_PARALLEL_LEVEL="${JOBS}"
# CMakeLists.txt of Aspia takes the vcpkg paths from the environment (used by qtprotoc_host)
export VCPKG_ROOT="${SRC}/vcpkg4aspia"
export VCPKG_INSTALLED_DIR="${SRC}/builds/armv7/vcpkg_installed"
mkdir -p "${VCPKG_DEFAULT_BINARY_CACHE}" "${VCPKG_DOWNLOADS}" "${OUT}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---------- Sources ----------
if [[ ! -d "${SRC}/.git" ]]; then
    log "Cloning Aspia v${VERSION}"
    git clone --depth 1 --branch "v${VERSION}" https://github.com/dchapyshev/aspia.git "${SRC}"
    # the submodule is registered with an SSH URL
    git -C "${SRC}" config submodule.vcpkg4aspia.url https://github.com/dchapyshev/vcpkg4aspia.git
    git -C "${SRC}" submodule update --init --depth 1 vcpkg4aspia
fi
cd "${SRC}"

# Router and Relay need only base/common/proto: the client, the host and the drivers are not built
# (the host needs PipeWire and other desktop libraries).
sed -i -E 's/^(\s*)add_subdirectory\((client|drivers|host)\)/\1# add_subdirectory(\2) # not needed for Router\/Relay/' source/CMakeLists.txt
# "break 2" is a MIPS instruction, there is none on ARM (used only for debugging)
sed -i 's/asm("break 2");/__builtin_trap();/' source/base/debug.cc

if [[ ! -x vcpkg4aspia/vcpkg ]]; then
    log "Bootstrapping vcpkg"
    ./vcpkg4aspia/bootstrap-vcpkg.sh -disableMetrics
fi

# ---------- Dependencies (vcpkg, arm-linux, static) ----------
log "Installing the vcpkg dependencies for arm-linux (the longest part)"
if ! ./vcpkg4aspia/vcpkg install \
        --triplet arm-linux --host-triplet x64-linux \
        --x-install-root="${VCPKG_INSTALLED_DIR}" \
        --overlay-triplets="${TRIPLETS}" \
        --clean-after-build \
        > >(tee "/work/vcpkg-install-${VERSION}.log" | grep --line-buffered -E "^(Installing|Elapsed)|error|failed") 2>&1; then
    log "ERROR: vcpkg install failed, see /work/vcpkg-install-${VERSION}.log"
    exit 1
fi

# ---------- Router and Relay ----------
log "Configuring Aspia"
if ! cmake -S . -B builds/armv7/Release -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=armv7l \
        -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc -DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++ \
        -DQT_HOST_PATH="${VCPKG_INSTALLED_DIR}/x64-linux" \
        -DQT_HOST_PATH_CMAKE_DIR="${VCPKG_INSTALLED_DIR}/x64-linux/share" \
        -DCMAKE_TOOLCHAIN_FILE="${SRC}/vcpkg4aspia/scripts/buildsystems/vcpkg.cmake" \
        -DVCPKG_TARGET_TRIPLET=arm-linux -DVCPKG_HOST_TRIPLET=x64-linux \
        -DVCPKG_INSTALLED_DIR="${VCPKG_INSTALLED_DIR}" \
        -DVCPKG_MANIFEST_INSTALL=OFF \
        -DVCPKG_OVERLAY_TRIPLETS="${TRIPLETS}" \
        > "/work/cmake-configure-${VERSION}.log" 2>&1; then
    tail -40 "/work/cmake-configure-${VERSION}.log"
    log "ERROR: configuration failed, see /work/cmake-configure-${VERSION}.log"
    exit 1
fi

log "Building aspia_router and aspia_relay"
if ! cmake --build builds/armv7/Release --target aspia_router aspia_relay \
        > >(tee "/work/cmake-build-${VERSION}.log" | grep --line-buffered -E "error|FAILED|Linking") 2>&1; then
    log "ERROR: build failed, see /work/cmake-build-${VERSION}.log"
    exit 1
fi

# ---------- Archives ----------
pack() {
    local dir="$1" name="$2"
    tar -czf "${OUT}/${name}" -C "${dir}" aspia_router aspia_relay
    (cd "${OUT}" && sha256sum "${name}" > "${name}.sha256")
}

plain="$(mktemp -d)"
find builds/armv7/Release -type f \( -name aspia_router -o -name aspia_relay \) -exec cp {} "${plain}/" \;
arm-linux-gnueabihf-strip "${plain}/aspia_router" "${plain}/aspia_relay"
file "${plain}"/*
pack "${plain}" "aspia-server-${VERSION}-linux-armv7.tar.gz"

log "Compressing the binaries with UPX"
upx_dir="$(mktemp -d)"
cp "${plain}"/aspia_* "${upx_dir}/"
upx --best --lzma -q "${upx_dir}/aspia_router" "${upx_dir}/aspia_relay"
pack "${upx_dir}" "aspia-server-${VERSION}-linux-armv7-upx.tar.gz"

rm -rf "${plain}" "${upx_dir}"
ls -la "${OUT}"
log "Done: ${OUT}"
