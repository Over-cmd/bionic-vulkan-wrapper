#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. El Truco de Pipetto: Descarga e inyección física de fuentes SPIRV vía Tarball ==="
# Borramos cualquier rastro de carpetas conflictivas
rm -rf spirv_source temp_repo repo.zip repo.tar.gz

# Descargamos el codigo fuente limpio modificado de leegao apuntando a la rama master real
curl -L -o repo.tar.gz https://github.com
tar -xzf repo.tar.gz
mkdir -p spirv_source

# Extraemos las herramientas modificadas reales del autor directamente en la ruta esperada
cp -r bionic-vulkan-wrapper-master/spirv_source/* spirv_source/ 2>/dev/null || cp -r bionic-vulkan-wrapper-master/* spirv_source/
rm -rf bionic-vulkan-wrapper-master repo.tar.gz

cd spirv_source

# Descargamos e inyectamos las cabeceras oficiales de Khronos Group en formato Tarball para evitar bloqueos
curl -L -o headers.tar.gz https://github.com
tar -xzf headers.tar.gz
mkdir -p external/spirv-headers
cp -r SPIRV-Headers-main/* external/spirv-headers/
rm -rf SPIRV-Headers-main headers.tar.gz

echo "=== 2. Compilando SPIRV-Tools Modificado para ARM (32 bits) ==="
mkdir -p build_32 && cd build_32
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
cd ..

echo "=== 3. Compilando SPIRV-Tools Modificado para ARM64 (64 bits) ==="
mkdir -p build_64 && cd build_64
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
