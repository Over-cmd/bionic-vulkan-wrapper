#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. El Truco Maestro: Forzando el rellenado físico del submódulo interno de leegao ==="
# Limpiamos rastros corruptos o carpetas virtuales anteriores
rm -f repo.tar.gz headers.tar.gz

# Forzamos a Git a descargar el contenido real del submodulo que leegao dejó amarrado de fábrica
git submodule deinit -f . || true
git submodule update --init --recursive --force

# Nos movemos a la carpeta legítima del repositorio que ahora sí tendrá los archivos completos
cd spirv_source

# Descargamos e inyectamos las cabeceras obligatorias de Khronos dentro de su estructura nativa sin usar Git
mkdir -p external/spirv-headers
curl -L -o headers.tar.gz https://github.com
tar -xzf headers.tar.gz --strip-components=1 -C external/spirv-headers
rm -f headers.tar.gz

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
