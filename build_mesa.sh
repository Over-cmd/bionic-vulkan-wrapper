#!/bin/bash
set -e
echo "=== ETAPA C: PRECOMPILACIÓN ABSOLUTA DE MOTORES E INYECCIÓN REAL DUAL ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"

# 1. Reparación del enum de Khronos para activar el parcheador de shaders de leegao
if [ -f "spirv_source/include/spirv-tools/libspirv.h" ]; then
  sed -i 's/SPV_OPERAND_TYPE_MEMORY_MODEL,/SPV_OPERAND_TYPE_MEMORY_MODEL,\n  SPV_OPERAND_TYPE_GATHER_MODES = 125,/g' spirv_source/include/spirv-tools/libspirv.h
fi

# 2. PRECOMPILACIÓN EN LIMPIO DE SPIRV-TOOLS (64 y 32 bits)
mkdir -p spirv_source/build_64 && cd spirv_source/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DSPIRV_SKIP_TESTS=ON -DSPIRV_WERROR=OFF
ninja && cd ../..

mkdir -p spirv_source/build_32 && cd spirv_source/build_32
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DSPIRV_SKIP_TESTS=ON -DSPIRV_WERROR=OFF
ninja && cd ../..

# 3. PRECOMPILACIÓN MANUAL REAL DE ADRENOTOOLS (Bypass del bloqueo de Meson)
# Forzamos a CMake a compilar adrenotools directamente con el soplete del NDK para crear los archivos físicos .a
mkdir -p subprojects/libadrenotools/build_64 && cd subprojects/libadrenotools/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release
ninja && cd ../../..

mkdir -p subprojects/libadrenotools/build_32 && cd subprojects/libadrenotools/build_32
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release
ninja && cd ../../..

# Volcamos las librerías del motor en el Sysroot para que el enlazador dinámico las succione con whole-archive
mkdir -p "$NDK_LIB_DIR_64" && mkdir -p "$NDK_LIB_DIR_32"
cp spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_64/libSPIRV-Tools-opt.a"
cp spirv_source/build_64/source/libSPIRV-Tools.a "$NDK_LIB_DIR_64/libSPIRV-Tools.a"
cp spirv_source/build_32/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_32/libSPIRV-Tools-opt.a"
cp spirv_source/build_32/source/libSPIRV-Tools.a "$NDK_LIB_DIR_32/libSPIRV-Tools.a"

# Volcamos adrenotools real precompilada directamente en los carriles del enlazador del NDK
cp subprojects/libadrenotools/build_64/libadrenotools.a "$NDK_LIB_DIR_64/libadrenotools.a"
cp subprojects/libadrenotools/build_32/libadrenotools.a "$NDK_LIB_DIR_32/libadrenotools.a"

mkdir -p local_pkgconfig
printf "prefix=%s\nlibdir=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$NDK_PATH" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"
unset LDFLAGS CXXFLAGS CFLAGS

# --- COMPILACIÓN 64 BITS (BOX64 / PROTON 9) ---
# Al estar adrenotools inyectada en NDK_LIB_DIR_64, podemos meter la bandera nativa limpia lícita -ladrenotools en c_link_args sin fallos
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-ladrenotools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-ladrenotools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\n[host_machine]\nsystem = 'linux'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" > cross64.txt
meson setup build64 --cross-file cross64.txt --buildtype=release -Doptimization=3 -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dgbm=disabled -Degl=disabled -Dopengl=false -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload
ninja -C build64

# --- COMPILACIÓN 32 BITS (BOX86 / WOWBOX64) ---
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include', '-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=neon']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include', '-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=neon']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-ladrenotools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-ladrenotools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\n[host_machine]\nsystem = 'linux'\ncpu_family = 'arm'\ncpu = 'armv7-a'\nendian = 'little'\n" > cross32.txt
meson setup build32 --cross-file cross32.txt --buildtype=release -Doptimization=3 -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dgbm=disabled -Degl=disabled -Dopengl=false -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload
ninja -C build32

# --- CONSTRUCCIÓN DE LA ARQUITECTURA MAPA DE WINLATOR STEVEN MXZ ---
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/lib64
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

cp -L build32/src/vulkan/wrapper/libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
cp -L build64/src/vulkan/wrapper/libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib64/libvulkan_wrapper.so

"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug wrapper_output/vulkan_wrapper/usr/lib64/libvulkan_wrapper.so

printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "/usr/lib64/libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.aarch64.json

tar -cf ../wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 ../wrapper.tar -o ../wrapper.tzst
echo "Estructura unificada de 32 y 64 bits con inyección física de adrenotools finalizada con éxito absoluto."
