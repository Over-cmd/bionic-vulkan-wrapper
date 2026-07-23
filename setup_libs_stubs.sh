#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_DESTINO="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"

# 1. PURGA INDESTRUCTIBLE DE ARCHIVOS CONTAMINADOS
# Eliminamos de raíz los archivos .a corruptos de PC que el enlazador rechaza en el paso 501
sudo rm -f "$LIB_DESTINO/libSPIRV-Tools-opt.a" "$LIB_DESTINO/libSPIRV-Tools.a" || true
sudo rm -f "${SYSROOT_MAESTRO}/usr/lib/libSPIRV-Tools-opt.a" "${SYSROOT_MAESTRO}/usr/lib/libSPIRV-Tools.a" || true

# 2. COMPILACIÓN REAL DE LOS FUENTES QUE LEEGÃO TRAE EN SUBPROJECTS
# Copiamos la suite de Shaders original del código de Leegao para compilarla con el CMake de Google para ARM64
rm -rf /tmp/spirv-tools-arm64
mkdir -p /tmp/spirv-tools-arm64

cp -r "$GITHUB_WORKSPACE/wrapper_src/subprojects/spirv-tools"/* /tmp/spirv-tools-arm64/ || true
mkdir -p /tmp/spirv-tools-arm64/external/spirv-headers
cp -r "$GITHUB_WORKSPACE/wrapper_src/subprojects/spirv-headers"/* /tmp/spirv-tools-arm64/external/spirv-headers/ || true

cd /tmp/spirv-tools-arm64
mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-26 \
      -DSPIRV_SKIP_TESTS=ON \
      -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)

# 3. INYECCIÓN DE LOS BINARIOS AUTÉNTICOS EN EL COMPILADOR DEL NDK
cp -f source/libSPIRV-Tools.a "$LIB_DESTINO/"
cp -f source/opt/libSPIRV-Tools-opt.a "$LIB_DESTINO/"

mkdir -p "${SYSROOT_MAESTRO}/usr/lib"
cp -f source/libSPIRV-Tools.a "${SYSROOT_MAESTRO}/usr/lib/"
cp -f source/opt/libSPIRV-Tools-opt.a "${SYSROOT_MAESTRO}/usr/lib/"

cd $GITHUB_WORKSPACE
