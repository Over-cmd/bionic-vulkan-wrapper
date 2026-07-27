#!/bin/bash
set -e
echo "=== ETAPA C: COMPILACIÓN DE TU ARCHIVO Custom LIBVULKAN_WRAPPER.SO COMPATIBLE ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"

# Reparación del enum de Khronos para activar el parcheador de shaders de leegao sin duplicar casos en table2.cpp
if [ -f "spirv_source/include/spirv-tools/libspirv.h" ]; then
  sed -i 's/SPV_OPERAND_TYPE_MEMORY_MODEL,/SPV_OPERAND_TYPE_MEMORY_MODEL,\n  SPV_OPERAND_TYPE_GATHER_MODES = 125,/g' spirv_source/include/spirv-tools/libspirv.h
fi

# Precompilación del optimizador SPIRV-Tools en 32 bits
mkdir -p spirv_source/build_32 && cd spirv_source/build_32
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=armeabi-v7a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DSPIRV_SKIP_TESTS=ON -DSPIRV_WERROR=OFF
ninja && cd ../..

mkdir -p "$NDK_LIB_DIR_32"
cp spirv_source/build_32/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_32/libSPIRV-Tools-opt.a"
cp spirv_source/build_32/source/libSPIRV-Tools.a "$NDK_LIB_DIR_32/libSPIRV-Tools.a"

mkdir -p local_pkgconfig
printf "prefix=%s\nlibdir=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$NDK_PATH" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"
unset LDFLAGS CXXFLAGS CFLAGS

# --- COMPILACIÓN DE TU ARCHIVO CON CONEXIÓN COMPATIBLE ANDROID ---
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-D_GNU_SOURCE', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include', '-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=neon']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-D_GNU_SOURCE', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/subprojects/libadrenotools/include', '-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=neon']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\n[host_machine]\nsystem = 'android'\ncpu_family = 'arm'\ncpu = 'armv7-a'\nendian = 'little'\n" > cross32.txt

# El setup limpio nativo hereda werror=false para los formatos estéticos de 32 bits
meson setup build32 --cross-file cross32.txt --buildtype=release -Doptimization=3 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dgbm=disabled -Degl=disabled -Dopengl=false -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload

# Lanzamiento directo de Ninja nativo sin parches externos colgados
ninja -C build32

# --- MAPA REGLAMENTARIO QUE WINLATOR EXIGE DE TU ARCHIVO ---
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
cp -L build32/src/vulkan/wrapper/libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so

tar -cf ../wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 ../wrapper.tar -o ../wrapper.tzst
echo "¡Tu archivo libvulkan_wrapper.so ha sido forjado con éxito total!"
