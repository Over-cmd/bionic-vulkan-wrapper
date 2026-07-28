#!/bin/bash
set -e
echo "=== ETAPA C-1: COMPILACIÓN PURA DE ADRENOTOOLS NATIVO EN EL COMPILADOR ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"

# Forzamos la actualización recursiva interna de los submódulos de adrenotools de forma puramente local y segura
cd adrenotools_source
git submodule update --init --recursive --force || true
cd ..

echo "-> Forjando Adrenotools en 64 bits (carril Box64)..."
mkdir -p adrenotools_source/build_64 && cd adrenotools_source/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release
ninja
cd ../..

echo "-> Forjando Adrenotools en 32 bits (carril WoWBox64)..."
mkdir -p adrenotools_source/build_32 && cd adrenotools_source/build_32
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release
ninja
cd ../..

echo "-> Volcando binarios estáticos en las venas del compilador..."
mkdir -p "$NDK_LIB_DIR_64" && mkdir -p "$NDK_LIB_DIR_32"
cp adrenotools_source/build_64/libadrenotools.a "$NDK_LIB_DIR_64/libadrenotools.a"
cp adrenotools_source/build_32/libadrenotools.a "$NDK_LIB_DIR_32/libadrenotools.a"

echo "=== LIBRERÍA LIBADRENOTOOLS.A FORJADA E INYECTADA CON ÉXITO TOTAL ==="
