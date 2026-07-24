#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. Compilando SPIRV-Tools Modificado de leegao para ARM (32 bits) ==="
mkdir -p spirv_source/build_32 && cd spirv_source/build_32
cmake .. -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$NDK_PATH/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=armeabi-v7a \
  -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release \
  -DSPIRV_SKIP_TESTS=ON \
  -DSPIRV_WERROR=OFF
ninja

SYSROOT_32_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi"
mkdir -p "$SYSROOT_32_BASE/26"
cp source/opt/libSPIRV-Tools-opt.a "$SYSROOT_32_BASE/26/libSPIRV-Tools-opt.a"
cp source/libSPIRV-Tools.a "$SYSROOT_32_BASE/26/libSPIRV-Tools.a"
cd "$BASE_PWD"

echo "=== 2. Compilando SPIRV-Tools Modificado de leegao para ARM64 (64 bits) ==="
mkdir -p spirv_source/build_64 && cd spirv_source/build_64
cmake .. -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$NDK_PATH/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release \
  -DSPIRV_SKIP_TESTS=ON \
  -DSPIRV_WERROR=OFF
ninja

SYSROOT_64_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android"
mkdir -p "$SYSROOT_64_BASE/26"
cp source/opt/libSPIRV-Tools-opt.a "$SYSROOT_64_BASE/26/libSPIRV-Tools-opt.a"
cp source/libSPIRV-Tools.a "$SYSROOT_64_BASE/26/libSPIRV-Tools.a"
cd "$BASE_PWD"
