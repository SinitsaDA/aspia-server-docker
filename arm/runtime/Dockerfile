# Aspia Router + Relay for ARM (armv7, arm64) with self-update inside the container (works without
# a Docker socket, e.g. on MikroTik RouterOS). The binaries are put into bin/<arch>/ before the build
# (bin/armv7, bin/arm64), each platform takes its own.
ARG DEBIAN_TAG=bookworm-slim
FROM debian:${DEBIAN_TAG}

ARG ASPIA_VERSION
# 0 for the 3.0.x images: 3.1 dropped the 2.x hosts, so they are updated only on request
# (aspia_update --check). The variable can be changed when the container is created.
ARG AUTO_UPDATE=1
ARG TARGETARCH
ARG TARGETVARIANT

LABEL org.opencontainers.image.title="Aspia Server" \
      org.opencontainers.image.description="Aspia Router + Relay in a single container, self-updating" \
      org.opencontainers.image.version="${ASPIA_VERSION}" \
      org.opencontainers.image.source="https://github.com/dchapyshev/aspia" \
      org.opencontainers.image.licenses="GPL-3.0"

ENV ASPIA_VERSION=${ASPIA_VERSION} \
    AUTO_UPDATE=${AUTO_UPDATE} \
    LANG=C.UTF-8

RUN set -e; \
    test -n "${ASPIA_VERSION}" || { echo "ASPIA_VERSION is not set" >&2; exit 1; }; \
    apt-get update; \
    apt-get install -y --no-install-recommends bash ca-certificates curl jq tzdata procps libdbus-1-3; \
    rm -rf /var/lib/apt/lists/*

COPY bin/${TARGETARCH}${TARGETVARIANT}/aspia_router bin/${TARGETARCH}${TARGETVARIANT}/aspia_relay /opt/aspia/${ASPIA_VERSION}/
COPY aspia_start aspia_health aspia_update /usr/bin/
COPY aspia_router.wrapper /usr/local/bin/aspia_router
COPY aspia_relay.wrapper /usr/local/bin/aspia_relay
RUN chmod 755 /opt/aspia/${ASPIA_VERSION}/* /usr/bin/aspia_start /usr/bin/aspia_health /usr/bin/aspia_update \
        /usr/local/bin/aspia_router /usr/local/bin/aspia_relay

# Configuration and keys, database (+ installed versions and backups of the self-update), logs.
VOLUME ["/etc/aspia", "/var/lib/aspia", "/var/log/aspia"]

# 8060 hosts 2.x | 8061 hosts 3.x | 8062 clients | 8063 relay <-> router | 8065/udp STUN | 8070 relay peers
EXPOSE 8060 8061 8062 8063 8065/udp 8070

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 CMD ["/usr/bin/aspia_health"]

CMD ["/usr/bin/aspia_start"]
