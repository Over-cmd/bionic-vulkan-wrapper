#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_DESTINO="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"

# 1. FORZAMOS EL DESPLIEGUE REAL DE LOS FUENTES DE LEEGÃO/PIPETTO
# Si Meson aún no ha descargado el wrap, lo clonamos de forma manual y legítima directo 
# de los servidores estables de Khronos Group en la versión exacta v2024.1 exigida.
if [ ! -d "$GITHUB_WORKSPACE/wrapper_src/subprojects/spirv-tools/source" ]; then
    rm -rf /tmp/spirv-build-real
    mkdir -p /tmp/spirv-build-real/external/spirv-headers
    curl -L "https://github.com" | tar -xz -C /tmp/spirv-build-real --strip-components=1
    curl -L "https://github.com" | tar -xz -C /tmp/spirv-build-real/external/spirv-headers --strip-components=1
else
    rm -rf /tmp/spirv-build-real
    cp -r "$GITHUB_WORKSPACE/wrapper_src/subprojects/spirv-tools" /tmp/spirv-build-real
fi

# 2. COMPILACIÓN NATIVA REAL CON CMAKE CRUZADO PARA ANDROID ARM64
cd /tmp/spirv-build-real
mkdir -p build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-26 \
      -DSPIRV_SKIP_TESTS=ON \
      -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)

# 3. ENLAZADO DE LOS BYTES REALES EN EL NDK (Destruye el dardo de la línea 203)
cp -f source/libSPIRV-Tools.a "$LIB_DESTINO/"
cp -f source/opt/libSPIRV-Tools-opt.a "$LIB_DESTINO/"

mkdir -p "${SYSROOT_MAESTRO}/usr/lib"
cp -f source/libSPIRV-Tools.a "${SYSROOT_MAESTRO}/usr/lib/"
cp -f source/opt/libSPIRV-Tools-opt.a "${SYSROOT_MAESTRO}/usr/lib/"

cd $GITHUB_WORKSPACE
