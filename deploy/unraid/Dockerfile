# syntax=docker/dockerfile:1.7

###############################################################################
# SoulspireXI — Multi-Stage Production Linux x86_64 Dockerfile
#
# Builds the actual customized OverlordsXI server from the pinned upstream
# LandSandBoat commit + all 50 OverlordsXI native patches + custom C++/Lua/SQL
# modules + OverlordsXI gameplay settings.
#
# Build from repository root:
#   docker build -f deploy/unraid/Dockerfile \
#     --build-arg OVERLORDS_VERSION=v2026.11.19 \
#     --build-arg OVERLORDS_COMMIT=$(git rev-parse HEAD) \
#     -t overlordsxi/server:v2026.11.19 .
###############################################################################

ARG BASE_TAG=26.04
ARG LSB_REPO=https://github.com/landsandboat/server.git
ARG LSB_COMMIT=091e7409d1c9d702f366dc374115f939393c46ab

########
# Base #
########
FROM ubuntu:${BASE_TAG} AS base

ARG DEBIAN_FRONTEND=noninteractive
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
 && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN apt-get update && apt-get install --assume-yes --no-install-recommends --quiet \
    bash \
    binutils \
    ca-certificates \
    curl \
    git \
    iproute2 \
    libdwarf1 \
    libzmq5 \
    lua5.1 \
    luajit \
    mariadb-client \
    netcat-openbsd \
    openssl \
    python3 \
    tini \
    tzdata \
    zlib1g \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Unraid default user/group is nobody:users (99:100), configurable at build time
ARG UNAME=xiadmin
ARG UGROUP=xiadmin
ARG UID=99
ARG GID=100

WORKDIR /server

RUN userdel --remove ubuntu 2>/dev/null || true \
 && if ! getent group "${GID}" >/dev/null; then groupadd --gid "${GID}" "${UGROUP}"; fi \
 && GROUP_NAME="$(getent group "${GID}" | cut -d: -f1)" \
 && if ! id -u "${UID}" >/dev/null 2>&1; then \
        useradd --uid "${UID}" --gid "${GID}" --home-dir /xiadmin --create-home --shell /bin/bash "${UNAME}"; \
    else \
        mkdir -p /xiadmin && chown "${UID}:${GID}" /xiadmin; \
    fi \
 && chown "${UID}:${GID}" /server \
 && install -d -o "${UID}" -g "${GID}" /server/certs /server/log /server/navmeshes /server/ximeshes \
 && git config --system --add safe.directory /server

ENV VIRTUAL_ENV=/xiadmin/.venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
ENV TRACY_NO_INVARIANT_CHECK=1
ENV TZ=America/Chicago

SHELL ["/bin/bash", "-c"]

###########
# Staging #
###########
FROM base AS staging

ARG GCC_VERSION=15

RUN --mount=type=cache,target=/var/cache/apt,id=ox-cache-apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=ox-lib-apt,sharing=locked \
    apt-get update && apt-get install --assume-yes --no-install-recommends --quiet \
    binutils-dev \
    ccache \
    cmake \
    g++-${GCC_VERSION} \
    libdwarf-dev \
    libluajit-5.1-dev \
    libmariadb-dev-compat \
    libssl-dev \
    libzmq3-dev \
    make \
    ninja-build \
    pkg-config \
    python3-dev \
    python3-venv \
    zlib1g-dev \
    libzstd-dev \
 && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 100 \
 && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 100

ENV CC=/usr/bin/gcc-${GCC_VERSION}
ENV CXX=/usr/bin/g++-${GCC_VERSION}

#########
# Build #
#########
FROM staging AS build

ARG LSB_REPO
ARG LSB_COMMIT
ARG CMAKE_BUILD_TYPE=Release
ARG PCH_ENABLE=ON
ARG WARNINGS_AS_ERRORS=FALSE
ARG BUILD_JOBS=0

# 1. Fetch exact pinned LandSandBoat commit (without navmeshes/ximeshes)
RUN git init /server \
 && cd /server \
 && git remote add origin "${LSB_REPO}" \
 && git fetch --depth 1 origin "${LSB_COMMIT}" \
 && git checkout --detach "${LSB_COMMIT}" \
 && git submodule update --init --recursive --depth 1

# 2. Install LandSandBoat Python tooling into venv (used by dbtool.py)
RUN --mount=type=cache,target=/root/.cache/pip,id=ox-cache-pip \
    python3 -m venv "${VIRTUAL_ENV}" \
 && "${VIRTUAL_ENV}/bin/python" -m pip install --upgrade pip setuptools wheel \
 && "${VIRTUAL_ENV}/bin/python" -m pip install --upgrade -r /server/tools/requirements.txt

# 3. Copy OverlordsXI overlay (patches, custom modules, settings, overlay script)
COPY patches /overlordsxi/patches
COPY modules /overlordsxi/modules
COPY deploy/unraid/config/settings /overlordsxi/deploy/unraid/config/settings
COPY deploy/unraid/scripts/apply-overlords-overlay.sh /overlordsxi/apply-overlords-overlay.sh
RUN chmod +x /overlordsxi/apply-overlords-overlay.sh \
 && /overlordsxi/apply-overlords-overlay.sh /overlordsxi /server

# 4. Copy default settings so /server/settings is complete
RUN cp -n /server/settings/default/*.lua /server/settings/ 2>/dev/null || true

# 5. Compile all OverlordsXI server binaries (including custom C++ modules & xi_test)
ENV CCACHE_DIR=/xiadmin/.ccache
ENV CCACHE_MAXSIZE=4G
ENV CCACHE_COMPILERCHECK=content
ENV CCACHE_SLOPPINESS=pch_defines,time_macros

RUN --mount=type=cache,target=/xiadmin/.ccache,id=ox-ccache-ubuntu \
    set -eo pipefail \
 && JOBS="${BUILD_JOBS}" \
 && if [ "${JOBS}" -le 0 ]; then JOBS="$(nproc)"; fi \
 && cmake -G Ninja -S /server -B /xiadmin/build \
      -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
      -DTRACY_ENABLE=OFF \
      -DPCH_ENABLE="${PCH_ENABLE}" \
      -DWARNINGS_AS_ERRORS="${WARNINGS_AS_ERRORS}" \
 && cmake --build /xiadmin/build --target xi_connect xi_world xi_search xi_profile xi_map xi_test -j"${JOBS}" | tee /server/build.log \
 && ccache -s

###########
# Service #
###########
FROM base AS service

ARG UID=99
ARG GID=100
ARG OVERLORDS_VERSION=dev
ARG OVERLORDS_COMMIT=unknown
ARG LSB_COMMIT=091e7409d1c9d702f366dc374115f939393c46ab

LABEL org.opencontainers.image.title="SoulspireXI Server" \
      org.opencontainers.image.description="Custom Final Fantasy XI private server built on LandSandBoat with 66 Souls and native patches" \
      org.opencontainers.image.source="https://github.com/Infomatictek/overlordsxi" \
      org.opencontainers.image.version="${OVERLORDS_VERSION}" \
      org.opencontainers.image.revision="${OVERLORDS_COMMIT}" \
      org.overlordsxi.lsb_commit="${LSB_COMMIT}"

COPY --chown=${UID}:${GID} --from=build ${VIRTUAL_ENV} ${VIRTUAL_ENV}
COPY --chown=${UID}:${GID} --from=build /server/LICENSE /server/LICENSE
COPY --chown=${UID}:${GID} --from=build /server/res/compress.dat /server/res/decompress.dat /server/res/
COPY --chown=${UID}:${GID} --from=build /server/sql /server/sql
COPY --chown=${UID}:${GID} --from=build /server/tools /server/tools
COPY --chown=${UID}:${GID} --from=build /server/modules /server/modules
COPY --chown=${UID}:${GID} --from=build /server/data /server/data
COPY --chown=${UID}:${GID} --from=build /server/scripts /server/scripts
COPY --chown=${UID}:${GID} --from=build /server/settings /server/settings
COPY --chown=${UID}:${GID} --from=build /server/settings /server/settings.image-defaults
COPY --chown=${UID}:${GID} --from=build /server/xi_connect /server/xi_world /server/xi_search /server/xi_profile /server/xi_map /server/xi_test /server/
COPY --chown=${UID}:${GID} --from=build /server/build.log /server/build.log

COPY --chmod=0755 deploy/unraid/scripts/entrypoint.sh /entrypoint.sh

USER ${UID}:${GID}
WORKDIR /server

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
