#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. Forzando descarga limpia de las fuentes SPIRV modificadas de leegao ==="
# Borramos cualquier rastro de carpeta vacia para evitar conflictos
rm -rf spirv_source

# Clonamos directamente las herramientas modificadas del autor en la ruta exacta esperada
git clone --depth=1 https://github.com spirv_source
cd spirv_source

# Descargamos sus cabeceras asociadas de Khronos dentro de la estructura de leegao
git clone --depth=1 https://github.com external/spirv-headers

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
