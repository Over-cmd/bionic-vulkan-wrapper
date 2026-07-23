#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_DESTINO="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"

# 1. DESCARGA REAL DE FUENTES COMPLETOS OFICIALES DE KHRONOS
rm -rf /tmp/spirv-tools
git clone --depth=1 --branch=v2024.1 https://github.com /tmp/spirv-tools
git clone --depth=1 --branch=v2024.1 https://github.com /tmp/spirv-tools/external/spirv-headers

# 2. COMPILACIÓN NATIVA REAL CON CMAKE PARA ANDROID ARM64 (Fat Binary Legítimo)
cd /tmp/spirv-tools
mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-26 \
      -DSPIRV_SKIP_TESTS=ON \
      -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)

# 3. INSTALACIÓN DE LOS COMPONENTES .A VERDADEROS EN EL CORAZÓN DEL NDK
# Copiamos los archivos estáticos reales cargados con todas las funciones biónicas que la línea 203 exige
cp -f source/libSPIRV-Tools.a "$LIB_DESTINO/"
cp -f source/opt/libSPIRV-Tools-opt.a "$LIB_DESTINO/"

# Copia masiva de seguridad en la raíz universal del enlazador del NDK
mkdir -p "${SYSROOT_MAESTRO}/usr/lib"
cp -f source/libSPIRV-Tools.a "${SYSROOT_MAESTRO}/usr/lib/"
cp -f source/opt/libSPIRV-Tools-opt.a "${SYSROOT_MAESTRO}/usr/lib/"

cd $GITHUB_WORKSPACE
