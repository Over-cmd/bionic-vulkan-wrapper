#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. El Truco Maestro: Descargando la revisión física exacta de SPIRV-Tools sin Git ==="
# Limpiamos rastros corruptos o carpetas vacías anteriores
rm -rf spirv_source temp_spirv repo.tar.gz headers.tar.gz
mkdir -p spirv_source

# Descargamos el Tarball de la revisión estable y compatible de SPIRV-Tools que usa Mesa vía curl
curl -L -o repo.tar.gz https://github.com
tar -xzf repo.tar.gz --strip-components=1 -C spirv_source
rm -f repo.tar.gz

# Descargamos las cabeceras oficiales estables de SPIRV-Headers en su sitio exacto
mkdir -p spirv_source/external/spirv-headers
curl -L -o headers.tar.gz https://github.com
tar -xzf headers.tar.gz --strip-components=1 -C spirv_source/external/spirv-headers
rm -f headers.tar.gz

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

# Inyectamos las librerías físicas con símbolos en el Sysroot del NDK de 32 bits
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

# Inyectamos las librerías físicas con símbolos en el Sysroot del NDK de 64 bits
SYSROOT_64_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
mkdir -p "$SYSROOT_64_BASE"
cp source/opt/libSPIRV-Tools-opt.a "$SYSROOT_64_BASE/libSPIRV-Tools-opt.a"
cp source/libSPIRV-Tools.a "$SYSROOT_64_BASE/libSPIRV-Tools.a"

cd "$BASE_PWD"
echo "=== Precompilación de SPIRV-Tools finalizada con éxito ==="
