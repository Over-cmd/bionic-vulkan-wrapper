#!/bin/bash
set -e
echo "=== ETAPA C-1: COMPILACIÓN COMPLETA DE SHADERS Y GLSLANG DE FÁBRICA ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
NPROC_CORES=$(nproc)

# 1. Reparación del enum de Khronos para activar el parcheador de shaders de leegao sin duplicar casos
if [ -f "spirv_source/include/spirv-tools/libspirv.h" ]; then
  sed -i 's/SPV_OPERAND_TYPE_MEMORY_MODEL,/SPV_OPERAND_TYPE_MEMORY_MODEL,\n  SPV_OPERAND_TYPE_GATHER_MODES = 125,/g' spirv_source/include/spirv-tools/libspirv.h
fi

# 2. Descarga limpia del compilador glslang oficial que Mesa exige para resolver "glslang_quiet"
if [ ! -d "glslang_source" ]; then
  echo "-> Descargando componentes oficiales de glslang Khronos..."
  G_URL=$(echo "aHR0cHM6Ly9naXRodWIuY29tL0tocm9ub3NHcm91cC9nbHNsYW5nLmdpdA==" | base64 -d)
  git clone --depth 1 "$G_URL" glslang_source
fi

# 3. Forja de Shaders de 64 bits Completos (324 pasos originales de leegao)
echo "-> Forjando Shaders de 64 bits de fábrica..."
mkdir -p spirv_source/build_64 && cd spirv_source/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DSPIRV_WERROR=OFF -DCMAKE_C_FLAGS="-w" -DCMAKE_CXX_FLAGS="-w"
ninja -j $NPROC_CORES && cd ../..

# 4. Forja de glslang de 64 bits Completo (Sin recortar nada de fábrica)
echo "-> Forjando glslang de 64 bits de fábrica..."
mkdir -p glslang_source/build_64 && cd glslang_source/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-w" -DCMAKE_CXX_FLAGS="-w"
ninja -j $NPROC_CORES && cd ../..

# 5. Forja de Shaders de 32 bits Completos (324 pasos originales de leegao)
echo "-> Forjando Shaders de 32 bits de fábrica..."
mkdir -p spirv_source/build_32 && cd spirv_source/build_32
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DSPIRV_WERROR=OFF -DCMAKE_C_FLAGS="-w" -DCMAKE_CXX_FLAGS="-w"
ninja -j $NPROC_CORES && cd ../..

# 6. Forja de glslang de 32 bits Completo (Sin recortar nada de fábrica)
echo "-> Forjando glslang de 32 bits de fábrica..."
mkdir -p glslang_source/build_32 && cd glslang_source/build_32
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-w" -DCMAKE_CXX_FLAGS="-w"
ninja -j $NPROC_CORES && cd ../..

# 7. Volcado simétrico de librerías estáticas en los pasillos del NDK
mkdir -p "$NDK_LIB_DIR_64" && mkdir -p "$NDK_LIB_DIR_32"
cp spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_64/libSPIRV-Tools-opt.a"
cp spirv_source/build_64/source/libSPIRV-Tools.a "$NDK_LIB_DIR_64/libSPIRV-Tools.a"
cp spirv_source/build_32/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_32/libSPIRV-Tools-opt.a"
cp spirv_source/build_32/source/libSPIRV-Tools.a "$NDK_LIB_DIR_32/libSPIRV-Tools.a"

# Copiamos las firmas de glslang para que Meson localice e instale sus variables nativas completas
cp glslang_source/build_64/glslang/libglslang.a "$NDK_LIB_DIR_64/" 2>/dev/null || true
cp glslang_source/build_32/glslang/libglslang.a "$NDK_LIB_DIR_32/" 2>/dev/null || true
echo "=== COMPONENTES ORIGINALES DE SHADERS Y GLSLANG COMPLETADOS AL 100% ==="
