#!/bin/bash
set -e
echo "=== ETAPA C: COMPILACIÓN DUAL DE ALTO RENDIMIENTO CON SUBSISTEMA ADRENOTOOLS INTEGRADO ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"

# Reparación del enum de Khronos para activar el parcheador de leegao sin duplicar casos en table2.cpp
if [ -f "spirv_source/include/spirv-tools/libspirv.h" ]; then
  sed -i 's/SPV_OPERAND_TYPE_MEMORY_MODEL,/SPV_OPERAND_TYPE_MEMORY_MODEL,\n  SPV_OPERAND_TYPE_GATHER_MODES = 125,/g' spirv_source/include/spirv-tools/libspirv.h
fi

mkdir -p spirv_source/build_64 && cd spirv_source/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DSPIRV_SKIP_TESTS=ON -DSPIRV_WERROR=OFF
ninja && cd ../..

mkdir -p spirv_source/build_32 && cd spirv_source/build_32
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DSPIRV_SKIP_TESTS=ON -DSPIRV_WERROR=OFF
ninja && cd ../..

mkdir -p "$NDK_LIB_DIR_64" && mkdir -p "$NDK_LIB_DIR_32"
cp spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_64/libSPIRV-Tools-opt.a"
cp spirv_source/build_64/source/libSPIRV-Tools.a "$NDK_LIB_DIR_64/libSPIRV-Tools.a"
cp spirv_source/build_32/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_32/libSPIRV-Tools-opt.a"
cp spirv_source/build_32/source/libSPIRV-Tools.a "$NDK_LIB_DIR_32/libSPIRV-Tools.a"

mkdir -p local_pkgconfig
printf "prefix=%s\nlibdir=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$NDK_PATH" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"
unset LDFLAGS CXXFLAGS CFLAGS

# --- COMPILACIÓN 64 BITS (BOX64 / PROTON 9) ---
# SOLUCIÓN DE ENLAZADO DE 64 BITS: Añadimos -ladrenotools de forma estricta para resolver el símbolo indefinido en la línea 483
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl', '-Wl,--whole-archive', '$BASE_PWD/build64/subprojects/libadrenotools/libadrenotools.a', '-Wl,--no-whole-archive']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl', '-Wl,--whole-archive', '$BASE_PWD/build64/subprojects/libadrenotools/libadrenotools.a', '-Wl,--no-whole-archive']\n[host_machine]\nsystem = 'linux'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" > cross64.txt
meson setup build64 --cross-file cross64.txt --buildtype=release -Doptimization=3 -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dgbm=disabled -Degl=disabled -Dopengl=false -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload
ninja -C build64

# --- COMPILACIÓN 32 BITS (BOX86 / WOWBOX64) ---
# SOLUCIÓN DE ENLAZADO DE 32 BITS: Añadimos su respectivo espejo estático para la arquitectura armhf gemela
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include', '-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=neon']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include', '-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=neon']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-Wl,--whole-archive', '-L$BASE_PWD/spirv_source/build_32/source/opt', '-lSPIRV-Tools-opt', '-L$BASE_PWD/spirv_source/build_32/source', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl', '-Wl,--whole-archive', '$BASE_PWD/build32/subprojects/libadrenotools/libadrenotools.a', '-Wl,--no-whole-archive']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-Wl,--whole-archive', '-L$BASE_PWD/spirv_source/build_32/source/opt', '-lSPIRV-Tools-opt', '-L$BASE_PWD/spirv_source/build_32/source', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl', '-Wl,--whole-archive', '$BASE_PWD/build32/subprojects/libadrenotools/libadrenotools.a', '-Wl,--no-whole-archive']\n[host_machine]\nsystem = 'linux'\ncpu_family = 'arm'\ncpu = 'armv8-a'\nendian = 'little'\n" > cross32.txt
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
echo "Estructura unificada dual finalizada con éxito total."
