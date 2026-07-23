#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_DESTINO="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"

# 1. LOCALIZACIÓN DE FUENTES REALES DE KHRONOS DE FÁBRICA EN EL NDK
# Extraemos el código fuente verdadero de SPIRV-Tools integrado por Google en el NDK para evitar descargas por red
rm -rf /tmp/spirv-tools
mkdir -p /tmp/spirv-tools/external
cp -r "${ANDROID_SDK_ROOT}/ndk/25.2.9519653/sources/third_party/shaderc/third_party/spirv-tools" /tmp/spirv-tools/core
cp -r "${ANDROID_SDK_ROOT}/ndk/25.2.9519653/sources/third_party/shaderc/third_party/spirv-headers" /tmp/spirv-tools/external/spirv-headers

# Movemos los fuentes a la raíz de compilación de CMake
mv /tmp/spirv-tools/core/* /tmp/spirv-tools/
rm -rf /tmp/spirv-tools/core

# 2. COMPILACIÓN NATIVA REAL CON CMAKE PARA ANDROID ARM64
cd /tmp/spirv-tools
mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-26 \
      -DSPIRV_SKIP_TESTS=ON \
      -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)

# 3. INSTALACIÓN DE LIBRERÍAS ESTÁTICAS VERDADERAS .A EN EL CORAZÓN DEL NDK
# Sembramos los binarios cargados con todos los bytes reales que la línea 203 exige
cp -f source/libSPIRV-Tools.a "$LIB_DESTINO/"
cp -f source/opt/libSPIRV-Tools-opt.a "$LIB_DESTINO/"

mkdir -p "${SYSROOT_MAESTRO}/usr/lib"
cp -f source/libSPIRV-Tools.a "${SYSROOT_MAESTRO}/usr/lib/"
cp -f source/opt/libSPIRV-Tools-opt.a "${SYSROOT_MAESTRO}/usr/lib/"

cd $GITHUB_WORKSPACE
