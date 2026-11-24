# Builder of Aspia Router and Relay for ARM: armv7 (armhf, 32-bit) and arm64 (aarch64), cross
# compilation on x86_64, Debian 12 as Raspberry Pi OS 12 used by the developer of Aspia. The ARM
# libraries let the build run ARM tools through QEMU (binfmt of Docker Desktop or
# docker/setup-qemu-action).
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# The x86_64 part (the "host" triplet x64-linux: Qt tools moc/rcc run during the build) needs the
# system GL/EGL/xkbcommon packages, as on the native machines of the developer.
RUN dpkg --add-architecture armhf && dpkg --add-architecture arm64 && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git zip unzip tar xz-utils pkg-config file \
        build-essential crossbuild-essential-armhf libc6:armhf libstdc++6:armhf \
        crossbuild-essential-arm64 libc6:arm64 libstdc++6:arm64 linux-libc-dev-arm64-cross \
        autoconf autoconf-archive automake libtool libltdl-dev bison flex gperf gettext \
        python3 python3-pip python3-venv python3-jinja2 perl nasm \
        linux-libc-dev-armhf-cross ninja-build \
        libgl-dev libegl-dev libopengl-dev libxkbcommon-dev libxkbcommon-x11-dev \
        libgl-dev:armhf libegl-dev:armhf libopengl-dev:armhf libsystemd-dev:armhf \
        libgl-dev:arm64 libegl-dev:arm64 libopengl-dev:arm64 libsystemd-dev:arm64 \
    && rm -rf /var/lib/apt/lists/*

# Newer CMake than Debian 12 has (vcpkg and Qt 6 need it), but not 4.x.
RUN python3 -m venv /opt/py && /opt/py/bin/pip install --no-cache-dir "cmake>=3.30,<4" ninja meson \
    && ln -sf /opt/py/bin/cmake /usr/local/bin/cmake && ln -sf /opt/py/bin/ctest /usr/local/bin/ctest \
    && ln -sf /opt/py/bin/ninja /usr/local/bin/ninja && ln -sf /opt/py/bin/meson /usr/local/bin/meson

# UPX compresses the binaries for the MikroTik image (fits into the built-in flash).
# Debian 12 has it only in the official bookworm-backports.
RUN echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/backports.list \
    && apt-get update && apt-get install -y --no-install-recommends -t bookworm-backports upx-ucl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
