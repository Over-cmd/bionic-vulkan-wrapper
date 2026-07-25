#!/bin/bash
set -e

echo "=== 1. Compilando e Inyectando el Motor de leegao Completo con Peso Real ==="
mkdir -p spirv_source/build_64
cd spirv_source/build_64
cmake .. -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release \
  -DSPIRV_SKIP_TESTS=ON \
  -DSPIRV_WERROR=OFF
ninja
cd ../..

echo "=== 2. Generando Entorno de Cabeceras e Inyecciones ==="
chmod +x crear_cabeceras.sh && ./crear_cabeceras.sh || true
chmod +x crear_stubs.sh && ./crear_stubs.sh || true

echo "=== 3. COMPILACIÓN DIRECTA DE CLANG (El Método Real de leegao) ==="
mkdir -p wrapper_output
CLANG_64="$ANDROID_NDK_LATEST_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++"
SYSROOT="$ANDROID_NDK_LATEST_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

$CLANG_64 --sysroot="$SYSROOT" -O3 -shared -fPIC -std=c++17 \
  -I./spirv_source/include \
  -I./spirv_source/external/spirv-headers/include \
  src/vulkan/wrapper/wrapper_device.c \
  src/vulkan/wrapper/wrapper_instance.c \
  src/vulkan/wrapper/wrapper_log.c \
  src/vulkan/wrapper/spirv_edit.cpp \
  -Wl,--whole-archive \
  spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a \
  spirv_source/build_64/source/libSPIRV-Tools.a \
  -Wl,--no-whole-archive \
  -lm -llog -landroid \
  -o wrapper_output/libvulkan_wrapper.so

echo "=== 4. EMPAQUETADO BRUTO: Comprobando Peso de leegao y Comprimiendo ==="
ls -lh wrapper_output/libvulkan_wrapper.so
tar -cf wrapper.tar -C wrapper_output libvulkan_wrapper.so
zstd -19 wrapper.tar -o wrapper.tzst

echo "Proceso finalizado con éxito absoluto."
