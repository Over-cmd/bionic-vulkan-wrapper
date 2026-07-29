#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA 24 (64 Y 32 BITS) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
NPROC_CORES=$(nproc)

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"
unset LDFLAGS CXXFLAGS CFLAGS

# --- CARRIEL A: 64 BITS ---
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/adrenotools_source/include']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/adrenotools_source/include']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\n[host_machine]\nsystem = 'android'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" > cross64.txt

meson setup build64 --cross-file cross64.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dgbm=disabled -Degl=disabled -Dopengl=false -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload

sed -i 's|-Wl,-soname,libvulkan_wrapper.so|-Wl,-soname,libvulkan_wrapper.so -Wl,--whole-archive '"$NDK_LIB_DIR_64"'/libadrenotools.a '"$NDK_LIB_DIR_64"'/liblinkernsbypass.a -Wl,--no-whole-archive|g' build64/build.ninja
ninja -C build64 -j $NPROC_CORES

# --- CARRIEL B: 32 BITS ---
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=neon']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=neon']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\n[host_machine]\nsystem = 'android'\ncpu_family = 'arm'\ncpu = 'armv7-a'\nendian = 'little'\n" > cross32.txt

sed -i "s|-L$BASE_PWD/spirv_source/build_64/source|-L$BASE_PWD/spirv_source/build_32/source|g" local_pkgconfig/SPIRV-Tools.pc
sed -i "s|-L$BASE_PWD/spirv_source/build_64/source/opt|-L$BASE_PWD/spirv_source/build_32/source/opt|g" local_pkgconfig/SPIRV-Tools-opt.pc

meson setup build32 --cross-file cross32.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dgbm=disabled -Degl=disabled -Dopengl=false -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload

sed -i 's|-Wl,-soname,libvulkan_wrapper.so|-Wl,-soname,libvulkan_wrapper.so -Wl,--whole-archive '"$NDK_LIB_DIR_32"'/libadrenotools.a -Wl,--no-whole-archive|g' build32/build.ninja
ninja -C build32 -j $NPROC_CORES

# --- EMPAQUETADO ---
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/lib64
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

cp -L build32/src/vulkan/wrapper/libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
cp -L build64/src/vulkan/wrapper/libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib64/libvulkan_wrapper.so

"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug wrapper_output/vulkan_wrapper/usr/lib64/libvulkan_wrapper.so

printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.aarch64.json

tar -cf ../wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 ../wrapper.tar -o ../wrapper.tzst
echo "¡Tu Fat Binary unificado simétrico stable nativo de Android ha sido forjado con éxito total!"
