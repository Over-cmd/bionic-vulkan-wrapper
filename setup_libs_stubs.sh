#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_64="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"
LIB_32="${SYSROOT_MAESTRO}/usr/lib/arm-linux-androideabi/26"

# Descargamos los fuentes auténticos de Khronos Group
git clone --depth=1 https://github.com /tmp/spirv-tools
git clone --depth=1 https://github.com /tmp/spirv-tools/external/spirv-headers

# Compilación Real Cruzada de 64 bits usando CMake y el NDK
cd /tmp/spirv-tools && mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DSPIRV_SKIP_TESTS=ON -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
cp source/libSPIRV-Tools.a "$LIB_64/"
cp source/opt/libSPIRV-Tools-opt.a "$LIB_64/"

# Compilación Real Cruzada de 32 bits para dar soporte completo
cd /tmp/spirv-tools && rm -rf build && mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DSPIRV_SKIP_TESTS=ON -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
cp source/libSPIRV-Tools.a "$LIB_32/"
cp source/opt/libSPIRV-Tools-opt.a "$LIB_32/"
