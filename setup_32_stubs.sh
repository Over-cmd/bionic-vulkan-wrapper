#!/bin/bash
set -e

LIB_NDK_32_A="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-android/26"

# Compilamos físicamente el stub objeto de 32 bits con el flag de posición dinámica -fPIC
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang++ -std=gnu++17 -stdlib=libc++ -fPIC -c /tmp/stub.cpp -o /tmp/stub_32.o

# Lo empaquetamos de forma legítima en la ruta primaria de la sysroot
mkdir -p "$LIB_NDK_32_A"
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK_32_A/libSPIRV-Tools-opt.a" /tmp/stub_32.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK_32_A/libSPIRV-Tools.a" /tmp/stub_32.o

# Clonamos los archivos estáticos en los directorios alternativos de 32 bits para que Meson no se pierda
for dir in arm-linux-androideabi/26 armv7a-linux-androideabi/26; do
    LIB_NDK_32_ALT="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$dir"
    mkdir -p "$LIB_NDK_32_ALT"
    cp -f "$LIB_NDK_32_A/libSPIRV-Tools-opt.a" "$LIB_NDK_32_ALT/libSPIRV-Tools-opt.a" || true
    cp -f "$LIB_NDK_32_A/libSPIRV-Tools.a" "$LIB_NDK_32_ALT/libSPIRV-Tools.a" || true
done
