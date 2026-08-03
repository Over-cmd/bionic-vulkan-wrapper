#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO WINLATOR FOCAL (MALI PURO) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# 1. Copiar stubs sin usar printf kilométricos
mkdir -p local_pkgconfig local_include/libdrm local_include/bits
if [ -f "drm_stubs.h" ]; then
  cp -f drm_stubs.h local_include/xf86drm.h
  cp -f drm_stubs.h local_include/libdrm/xf86drm.h
fi

# 2. Pthreads y estructuras de superficies gráficas WSI de leegao
printf '#ifndef _BITS_PTHREADTYPES_H_\n#define _BITS_PTHREADTYPES_H_\n#include <pthread.h>\n#endif\n' > "local_include/bits/pthreadtypes.h"
if [ -f "include/vulkan/vulkan_core.h" ]; then
  sed -i 's/\r$//' include/vulkan/vulkan_core.h
  vulkan_wsi="#ifndef _MESA_MALI_X11_SURFACE_GUARD_\n#define _MESA_MALI_X11_SURFACE_GUARD_\n#include <stdint.h>\ntypedef struct VkXlibSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* dpy; unsigned long window; } VkXlibSurfaceCreateInfoKHR;\ntypedef struct VkXcbSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* connection; uint32_t window; } VkXcbSurfaceCreateInfoKHR;\n#endif\n"
  sed -i "1i$vulkan_wsi" include/vulkan/vulkan_core.h
fi

# 3. Pkg-Config equilibrados de factoría
printf "prefix=%s\nlibdir=%s\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -L\${libdir} -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$BASE_PWD/build_drm" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source/opt -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: glslang\nVersion: 14.0.0\nLibs: -L$BASE_PWD/glslang_source/build_64/glslang -lglslang\nCflags: -I$BASE_PWD/glslang_source\n" > local_pkgconfig/glslang.pc
printf "prefix=%s\nexec_prefix=\${prefix}\nlibdir=%s\nincludedir=\${prefix}/local_include\npkgconfig_libdir=\${libdir}\n\nName: libclc\nDescription: Library Compiler for OpenCL bytecode\nVersion: 18.0.0\nLibs: -L\${libdir} -lclc\nCflags: -I\${includedir}\n" "$BASE_PWD" "$NDK_LIB_DIR_64" > local_pkgconfig/libclc.pc

# 4. Configurar Crossfiles puros de catálogo de la Scene
cat << EOF > cross64.txt
[binaries]
c = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '/bin/true'
pkg-config = '/usr/bin/pkg-config'
glslangValidator = '/usr/bin/glslangValidator'
[built-in options]
c_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source']
cpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source']
c_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-lc', '-llog', '-landroid', '-ldl']
cpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-lc', '-llog', '-landroid', '-ldl']
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF

cat << EOF > cross32.txt
[binaries]
c = ['$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/clang', '-target', 'armv7a-linux-androideabi26', '--sysroot=$SYSROOT_PATH']
cpp = ['$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++', '-target', 'armv7a-linux-androideabi26', '--sysroot=$SYSROOT_PATH']
ar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '/bin/true'
pkg-config = '/usr/bin/pkg-config'
glslangValidator = '/usr/bin/glslangValidator'
[built-in options]
c_args = ['-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-march=armv7-a', '-mfpu=neon', '-I$SYSROOT_PATH/usr/include']
cpp_args = ['-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-march=armv7-a', '-mfpu=neon', '-I$SYSROOT_PATH/usr/include']
c_link_args = ['-fuse-ld=lld', '-L$NDK_LIB_DIR_32', '-lc', '-lm', '-ldl', '-llog', '-landroid']
cpp_link_args = ['-fuse-ld=lld', '-L$NDK_LIB_DIR_32', '-lc', '-lm', '-ldl', '-llog', '-landroid']
[host_machine]
system = 'android'
cpu_family = 'arm'
cpu = 'armv7-a'
endian = 'little'
EOF
echo "=== ETAPA C-2 COMPLETADA SIN SOBRECARGAS ==="
