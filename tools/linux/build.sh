#!/usr/bin/env bash
# Runs INSIDE the build container (tools/make_linux.sh starts it).
# Builds the game into build-linux/. The engine's CMake downloads and builds
# SDL3 from source and links it in statically.
set -euo pipefail
cd /src
# FreeType off: it would add a system library the player may not have.
# libwebp SIMD off: its AVX2 code needs a newer compiler than Ubuntu 20.04's
# GCC 9 (_mm256_cvtsi256_si32), and only optional HD texture packs use it.
# OpenGL LEGACY: link libGL.so.1 (every desktop with graphics has it), not
# libOpenGL.so.0, which minimal desktops can lack.
cmake -S . -B build-linux -G Ninja -DCMAKE_BUILD_TYPE=Release -DPSXRECOMP_REQUIRE_GAME_C=ON \
    -DCMAKE_DISABLE_FIND_PACKAGE_Freetype=ON -DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON -DOpenGL_GL_PREFERENCE=LEGACY -DWEBP_ENABLE_SIMD=OFF
cmake --build build-linux --parallel "$(nproc)"
