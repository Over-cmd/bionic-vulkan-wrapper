#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. El Truco Definitivo: Usando las fuentes físicas integradas profundamente ==="
rm -rf spirv_source
mkdir -p spirv_source

# Sincronizamos las carpetas nativas del repositorio que ahora si vienen llenas gracias al depth: 0
cp -r external/SPIRV-Tools/* spirv_source/ 2>/dev/null || cp -r external/spirv-tools/* spirv_source/ 2>/dev/null || true

# Verificamos si hay un submodulo Git alternativo en Mesa y lo movemos a su sitio
mkdir -p spirv_source/external/spirv-headers
cp -r external/SPIRV-Headers/* spirv_source/external/spirv-headers/ 2>/dev/null || cp -r external/spirv-headers/* spirv_source/external/spirv-headers/ 2>/dev/null || true

cd spirv_source

echo "=== 2. Compilando SPIRV-Tools Real para ARM (32 bits) ==="
mkdir -p build_32 && cd build_32
cmake .. -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$NDK_PATH/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=armeabi-v7a \
  -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release \
  -DSPIRV_SKIP_TESTS=ON \
  -DSPIRV_WERROR=OFF
ninja

SYSROOT_32_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
mkdir -p "$SYSROOT_32_BASE"
cp source/opt/libSPIRV-Tools-opt.a "$SYSROOT_32_BASE/libSPIRV-Tools-opt.a"
cp source/libSPIRV-Tools.a "$SYSROOT_32_BASE/libSPIRV-Tools.a"
cd ..

echo "=== 3. Compilando SPIRV-Tools Real para ARM64 (64 bits) ==="
mkdir -p build_64 && cd build_64
cmake .. -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$NDK_PATH/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release \
  -DSPIRV_SKIP_TESTS=ON \
  -DSPIRV_WERROR=OFF
ninja

SYSROOT_64_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
mkdir -p "$SYSROOT_64_BASE"
cp source/opt/libSPIRV-Tools-opt.a "$SYSROOT_64_BASE/libSPIRV-Tools-opt.a"
cp source/libSPIRV-Tools.a "$SYSROOT_64_BASE/libSPIRV-Tools.a"

cd "$BASE_PWD"
echo "=== Precompilación local completada sin descargas de red ==="
