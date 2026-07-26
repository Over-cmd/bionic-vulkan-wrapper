#!/bin/bash
set -e
echo "=== ETAPA A: COMPILACIÓN DE LIBDRM ORIGINAL REAL ==="

printf "[binaries]\nc = '$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'\nar = '$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\n[host_machine]\nsystem = 'android'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" > drm_cross.txt

meson setup build_drm libdrm_source --cross-file drm_cross.txt --buildtype=release -Dintel=false -Dradeon=false -Damdgpu=false -Dnouveau=false -Dvmwgfx=false -Domap=false -Dexynos=false -Dfreedreno=false -Dtegra=false -Dvc4=false -Detnaviv=false
ninja -C build_drm

cp build_drm/libdrm.so "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26/libdrm.so"
cp build_drm/libdrm.so "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libdrm.so" 2>/dev/null || true

mkdir -p local_include/libdrm
cp libdrm_source/*.h local_include/libdrm/ 2>/dev/null || true
cp libdrm_source/include/drm/*.h local_include/libdrm/ 2>/dev/null || true
cp build_drm/config.h local_include/libdrm/ 2>/dev/null || true
