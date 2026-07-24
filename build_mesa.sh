#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
CLANG_LIB_DIR="/usr/lib/llvm-18/lib"

mkdir -p local_pkgconfig

echo "=== 1. Generando descriptores de control .pc ==="
printf "prefix=%s\nlibdir=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs:\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$NDK_PATH" > local_pkgconfig/libdrm.pc
printf "prefix=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr\nlibdir=\${prefix}/lib\nincludedir=\${prefix}/include\nlibexecdir=\${prefix}/libexec\n\nName: libclc\nDescription: OpenCL C library stub for Android\nVersion: 0.2.0\nLibs:\nCflags: -I\${includedir}\n" "$NDK_PATH" > local_pkgconfig/libclc.pc
printf "Name: SPIRV-Tools\nDescription: SPIRV Tools\nVersion: 2024.1\nLibs: -lSPIRV-Tools\nCflags:\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nDescription: SPIRV Tools Opt\nVersion: 2024.1\nLibs: -lSPIRV-Tools-opt\nCflags:\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: LLVMSPIRVLib\nDescription: LLVM SPIR-V Translator Library\nVersion: 18.1.0\nLibs: -lLLVMSPIRVLib\nCflags:\n" > local_pkgconfig/LLVMSPIRVLib.pc

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

echo "=== 2. Configurando ETAPA 1: 32 BITS ==="
printf "[binaries]\nc = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'\ncpp = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi25-clang++'\nar = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'\npkg-config = 'pkg-config'\nllvm-config = '/usr/bin/llvm-config'\n[built-in options]\nc_args = ['%s/local_drm_stubs.c', '-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-include', '%s/local_include/xf86drm.h', '-Wno-error=format', '-Wno-format']\ncpp_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-include', '%s/local_include/xf86drm.h', '-Wno-error=format', '-Wno-format']\n[properties]\nlib_dirs = ['%s']\n[host_machine]\nsystem = 'android'\ncpu_family = 'arm'\ncpu = 'armv7-a'\nendian = 'little'\n" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$CLANG_LIB_DIR" > arm32_cross.txt

export LDFLAGS="-L$CLANG_LIB_DIR -Wl,--no-fatal-warnings"
export CXXFLAGS="-I$BASE_PWD/spirv_source/include -I$BASE_PWD/local_include -Wno-format"
export CFLAGS="-I$BASE_PWD/local_include -Wno-format"

meson setup build32 --cross-file arm32_cross.txt --buildtype=release -Dplatforms=android -Dplatform-sdk-version=26 -Dvulkan-drivers=wrapper -Dgallium-drivers= --wrap-mode=nodownload
ninja -C build32

echo "=== 3. Configurando ETAPA 2: 64 BITS (Truco Pipetto) ==="
printf "[binaries]\nc = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android25-clang++'\nar = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'\npkg-config = 'pkg-config'\nllvm-config = '/usr/bin/llvm-config'\n[built-in options]\nc_args = ['%s/local_drm_stubs.c', '-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-include', '%s/local_include/xf86drm.h', '-Wno-error=format', '-Wno-format']\ncpp_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-include', '%s/local_include/xf86drm.h', '-Wno-error=format', '-Wno-format']\n[properties]\nlib_dirs = ['%s']\n[host_machine]\nsystem = 'android'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$CLANG_LIB_DIR" > arm64_cross.txt

SO_32_PATH="$BASE_PWD/build32/src/vulkan/wrapper/libvulkan_wrapper.so"
export LDFLAGS="-L$CLANG_LIB_DIR -Wl,-q -Wl,--eh-frame-hdr -Wl,--just-symbols=$SO_32_PATH -Wl,--no-fatal-warnings"
export CXXFLAGS="-I$BASE_PWD/spirv_source/include -I$BASE_PWD/local_include -Wno-format"
export CFLAGS="-I$BASE_PWD/local_include" -Wno-format

meson setup build64 --cross-file arm64_cross.txt --buildtype=release -Dplatforms=android -Dplatform-sdk-version=26 -Dvulkan-drivers=wrapper -Dgallium-drivers= --wrap-mode=nodownload
ninja -C build64
