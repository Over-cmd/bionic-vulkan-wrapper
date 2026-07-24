#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. El Truco Definitivo: Clonando localmente la carpeta interna del repositorio ==="
rm -rf spirv_source temp_spirv spirv.zip

# Creamos la carpeta física esperada por el build de Mesa
mkdir -p spirv_source

# Copiamos de forma física el árbol de SPIRV-Tools que ya viene integrado dentro de tu propio fork limpio
cp -r external/SPIRV-Tools/* spirv_source/ 2>/dev/null || cp -r external/spirv-tools/* spirv_source/ 2>/dev/null || true

# Si la carpeta quedó vacía por la estructura de clonado, extraemos los fuentes desde el núcleo del espacio de trabajo
if [ ! -f "spirv_source/CMakeLists.txt" ]; then
  echo "Inicializando estructura alternativa desde fuentes locales..."
  git clone --local . temp_spirv
  cp -r temp_spirv/external/SPIRV-Tools/* spirv_source/ 2>/dev/null || cp -r temp_spirv/external/spirv-tools/* spirv_source/ 2>/dev/null || true
  rm -rf temp_spirv
fi

# Nos aseguramos de que las cabeceras de Khronos Group estén en su sitio exacto
mkdir -p spirv_source/external/spirv-headers
cp -r external/SPIRV-Headers/* spirv_source/external/spirv-headers/ 2>/dev/null || cp -r external/spirv-headers/* spirv_source/external/spirv-headers/ 2>/dev/null || true

cd spirv_source

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

SYSROOT_32_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
mkdir -p "$SYSROOT_32_BASE"
cp source/opt/libSPIRV-Tools-opt.a "$SYSROOT_32_BASE/libSPIRV-Tools-opt.a"
cp source/libSPIRV-Tools.a "$SYSROOT_32_BASE/libSPIRV-Tools.a"
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

SYSROOT_64_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
mkdir -p "$SYSROOT_64_BASE"
cp source/opt/libSPIRV-Tools-opt.a "$SYSROOT_64_BASE/libSPIRV-Tools-opt.a"
cp source/libSPIRV-Tools.a "$SYSROOT_64_BASE/26/libSPIRV-Tools.a"

cd "$BASE_PWD"
echo "Precompilación local de SPIRV-Tools completada."
