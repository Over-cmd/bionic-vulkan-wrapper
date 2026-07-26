#!/bin/bash
set -e
echo "=== ETAPA C: PRECOMPILACIÓN DE SHADERS Y MONTAJE DE MESA ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# 1. Compilamos el optimizador SPIRV-Tools real de leegao
mkdir -p spirv_source/build_64 && cd spirv_source/build_64
cmake .. -G Ninja -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DSPIRV_SKIP_TESTS=ON -DSPIRV_WERROR=OFF
ninja && cd ../..

# Registramos las dependencias .a en el sysroot
cp spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_64/libSPIRV-Tools-opt.a"
cp spirv_source/build_64/source/libSPIRV-Tools.a "$NDK_LIB_DIR_64/libSPIRV-Tools.a"

mkdir -p local_pkgconfig
printf "prefix=%s\nlibdir=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$NDK_PATH" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nDescription: SPIRV Tools\nVersion: 2024.1\nLibs: -lSPIRV-Tools\nCflags:\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nDescription: SPIRV Tools Opt\nVersion: 2024.1\nLibs: -lSPIRV-Tools-opt\nCflags:\n" > local_pkgconfig/SPIRV-Tools-opt.pc

# 2. Archivo cruzado estructurado de Pipetto estable
cat << EOF > arm64_cross.txt
[binaries]
c = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '/bin/true'
pkg-config = 'pkg-config'
[built-in options]
c_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000']
cpp_args = ['--sysroot=$SYSROOT_PATH', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000']
c_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']
cpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']
[properties]
lib_dirs = ['$NDK_LIB_DIR_64']
[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"
unset LDFLAGS CXXFLAGS CFLAGS

# Configuración limpia de Mesa 23 compatible sin recortes
meson setup build64 --cross-file arm64_cross.txt --buildtype=release -Doptimization=3 -Dplatforms=android -Dplatform-sdk-version=26 -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dgbm=disabled -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dopengl=false -Dglx=disabled -Dglvnd=disabled -Dllvm=disabled
ninja -C build64

# 3. Empaquetado ICD reglamentario para Steven MXZ
mkdir -p "$BASE_PWD/wrapper_output/vulkan_wrapper"
cp -L "$BASE_PWD/build64/src/vulkan/wrapper/libvulkan_wrapper.so" "$BASE_PWD/wrapper_output/vulkan_wrapper/libvulkan_wrapper.so"
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug "$BASE_PWD/wrapper_output/vulkan_wrapper/libvulkan_wrapper.so"

ls -lh "$BASE_PWD/wrapper_output/vulkan_wrapper/libvulkan_wrapper.so"
tar -cf "$BASE_PWD/wrapper.tar" -C "$BASE_PWD/wrapper_output" vulkan_wrapper
zstd -19 "$BASE_PWD/wrapper.tar" -o "$BASE_PWD/wrapper.tzst"
echo "Proceso monolítico modular finalizado con éxito rotundo."
