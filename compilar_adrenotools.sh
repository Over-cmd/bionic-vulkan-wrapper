#!/bin/bash
set -e
echo "=== ETAPA C-1: COMPILACIÓN PURA DE ADRENOTOOLS NATIVO EN EL COMPILADOR (CHASIS PIPETTO) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"

# Forzamos la actualización recursiva interna de los submódulos de adrenotools de forma puramente local y segura
cd adrenotools_source
git submodule update --init --recursive --force || true
cd ..

echo "-> Forjando Adrenotools de Pipetto-crypto en 64 bits legítimos (carril Box64)..."
mkdir -p adrenotools_source/build_64 && cd adrenotools_source/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release
ninja
cd ../..

echo "-> Volcando ambas librerías estáticas oficiales en las venas del NDK de Google..."
mkdir -p "$NDK_LIB_DIR_64"
# Copiamos tanto la librería principal como su submódulo indispensable de bypass del linker
cp adrenotools_source/build_64/libadrenotools.a "$NDK_LIB_DIR_64/libadrenotools.a"
cp adrenotools_source/build_64/lib/linkernsbypass/liblinkernsbypass.a "$NDK_LIB_DIR_64/liblinkernsbypass.a"

echo "=== LIBRERÍAS DE CÓDIGO FUENTE DE PIPETTO COPIADAS CON ÉXITO TOTAL ==="
