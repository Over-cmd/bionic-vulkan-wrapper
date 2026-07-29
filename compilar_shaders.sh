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

# 2. Descarga del compilador glslang oficial de Khronos exigido por Mesa
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

# 4. PUENTE SIMÉTRICO CRUCIAL DE FÁBRICA: Vinculamos las fuentes de leegao y sus binarios dentro del pasillo interno que glslang exige para disolver el error de SPIR-V tools de raíz
mkdir -p glslang_source/External
rm -rf glslang_source/External/spirv-tools
ln -sf "$PWD/spirv_source" glslang_source/External/spirv-tools

# 5. Forja de glslang de 64 bits Completo (Todo instalado y activo de origen)
echo "-> Forjando glslang de 64 bits de fábrica..."
mkdir -p glslang_source/build_64 && cd glslang_source/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-w" -DCMAKE_CXX_FLAGS="-w"
ninja -j $NPROC_CORES && cd ../..

# 6. Forja de Shaders de 32 bits Completos (324 pasos originales de leegao)
echo "-> Forjando Shaders de 32 bits de fábrica..."
mkdir -p spirv_source/build_32 && cd spirv_source/build_32
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DSPIRV_WERROR=OFF -DCMAKE_C_FLAGS="-w" -DCMAKE_CXX_FLAGS="-w"
ninja -j $NPROC_CORES && cd ../..

# Reajustamos el puente simbólico interno hacia la arquitectura de 32 bits justo antes de compilar su variante
ln -sf "$PWD/spirv_source" glslang_source/External/spirv-tools

# 7. Forja de glslang de 32 bits Completo (Todo instalado y activo de origen)
echo "-> Forjando glslang de 32 bits de fábrica..."
mkdir -p glslang_source/build_32 && cd glslang_source/build_32
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-w" -DCMAKE_CXX_FLAGS="-w"
ninja -j $NPROC_CORES && cd ../..

# 8. Volcado simétrico de librerías estáticas en los pasillos del NDK de Google
mkdir -p "$NDK_LIB_DIR_64" && mkdir -p "$NDK_LIB_DIR_32"
cp -f spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_64/libSPIRV-Tools-opt.a"
cp -f spirv_source/build_64/source/libSPIRV-Tools.a "$NDK_LIB_DIR_64/libSPIRV-Tools.a"
cp -f spirv_source/build_32/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_32/libSPIRV-Tools-opt.a"
cp -f spirv_source/build_32/source/libSPIRV-Tools.a "$NDK_LIB_DIR_32/libSPIRV-Tools.a"

cp -f glslang_source/build_64/glslang/libglslang.a "$NDK_LIB_DIR_64/libglslang.a"
cp -f glslang_source/build_32/glslang/libglslang.a "$NDK_LIB_DIR_32/libglslang.a"
echo "=== COMPONENTES ORIGINALES DE SHADERS Y GLSLANG COMPLETADOS AL 100% ==="
