#!/bin/bash
set -e
echo "=== ETAPA C-1: COMPILACIÓN PURA DE ADRENOTOOLS NATIVO EN EL COMPILADOR (64 BITS) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"

# Forzamos la actualización recursiva interna de los submódulos de adrenotools de forma puramente local y segura
cd adrenotools_source
git submodule update --init --recursive --force || true
cd ..

echo "-> Forjando Adrenotools oficial de bylaws en 64 bits legítimos (carril Box64)..."
mkdir -p adrenotools_source/build_64 && cd adrenotools_source/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release
ninja
cd ../..

echo "-> Volcando binario estático de 64 bits en las venas del compilador..."
mkdir -p "$NDK_LIB_DIR_64"
cp adrenotools_source/build_64/libadrenotools.a "$NDK_LIB_DIR_64/libadrenotools.a"

echo "=== LIBRERÍA LIBADRENOTOOLS.A DE 64 BITS FORJADA E INYECTADA CON ÉXITO TOTAL ==="
