#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO WINLATOR FOCAL (MALI PURO) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# 1. Creación segura y genérica de xf86drm.h para GPU Mali (Evita conflictos de tipos)
mkdir -p local_pkgconfig local_include/libdrm local_include/bits
echo '#ifndef _XF86DRM_H_' > local_include/xf86drm.h
echo '#define _XF86DRM_H_' >> local_include/xf86drm.h
echo '#include <stdint.h>' >> local_include/xf86drm.h
echo '#include <stddef.h>' >> local_include/xf86drm.h
echo '#include <stdbool.h>' >> local_include/xf86drm.h
echo '#define DRM_CAP_SYNCOBJ_TIMELINE 0x13' >> local_include/xf86drm.h
echo 'int drmIoctl(int fd, unsigned long req, void *arg); int drmGetCap(int fd, uint64_t cap, uint64_t *v);' >> local_include/xf86drm.h
echo 'int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *h); int drmSyncobjDestroy(int fd, uint32_t h);' >> local_include/xf86drm.h
echo 'int drmSyncobjSignal(int fd, uint32_t *h, uint32_t c); int drmSyncobjWait(int fd, uint32_t *h, uint32_t c, int64_t t, uint32_t f, uint32_t *s);' >> local_include/xf86drm.h
echo 'int drmGetDevice2(int fd, uint32_t flags, void *device); void drmFreeDevice(void *device);' >> local_include/xf86drm.h
echo 'int drmGetDevices2(uint32_t flags, void *devices[], int max_devices); void drmFreeDevices(void *devices[], int count); int drmDevicesEqual(void *a, void *b);' >> local_include/xf86drm.h
echo '#endif' >> local_include/xf86drm.h
cp -f local_include/xf86drm.h local_include/libdrm/xf86drm.h

# 2. Pthreads y superficies gráficas WSI de leegao
printf '#ifndef _BITS_PTHREADTYPES_H_\n#define _BITS_PTHREADTYPES_H_\n#include <pthread.h>\n#endif\n' > "local_include/bits/pthreadtypes.h"
if [ -f "include/vulkan/vulkan_core.h" ]; then
  sed -i 's/\r$//' include/vulkan/vulkan_core.h
  vulkan_wsi="#ifndef _MESA_MALI_X11_SURFACE_GUARD_\n#define _MESA_MALI_X11_SURFACE_GUARD_\n#include <stdint.h>\ntypedef struct VkXlibSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* dpy; unsigned long window; } VkXlibSurfaceCreateInfoKHR;\ntypedef struct VkXcbSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* connection; uint32_t window; } VkXcbSurfaceCreateInfoKHR;\n#endif\n"
  sed -i "1i$vulkan_wsi" include/vulkan/vulkan_core.h
fi

# 3. Pkg-Config puros de factoría (PURGADOS DE EXTPREFIX DE RAÍZ)
printf "prefix=%s\nlibdir=%s\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -L\${libdir} -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$BASE_PWD/build_drm" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source/opt -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: glslang\nVersion: 14.0.0\nLibs: -L$BASE_PWD/glslang_source/build_64/glslang -lglslang\nCflags: -I$BASE_PWD/glslang_source\n" > local_pkgconfig/glslang.pc
printf "prefix=%s\nexec_prefix=\${prefix}\nlibdir=%s\nincludedir=\${prefix}/local_include\npkgconfig_libdir=\${libdir}\n\nName: libclc\nDescription: Library Compiler for OpenCL bytecode\nVersion: 18.0.0\nLibs: -L\${libdir} -lclc\nCflags: -I\${includedir}\n" "$BASE_PWD" "$NDK_LIB_DIR_64" > local_pkgconfig/libclc.pc

# 4. Configurar Crossfiles oficiales limpios de catálogo
cat << EOF > cross64.txt
[binaries]
c = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '/bin/true'
pkg-config = '/usr/bin/pkg-config'
[built-in options]
c_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include']
cpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include']
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
[built-in options]
c_args = ['-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-march=armv7-a', '-mfpu=neon', '-I$SYSROOT_PATH/usr/include']
cpp_args = ['-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-march=armv7-a', '-mfpu=neon', '-I$SYSROOT_PATH/usr/include']
c_link_args = ['-fuse-ld=lld', '-L$NDK_LIB_DIR_32', '-lc', '-lm', '-ldl', '-llog', '-landroid']
cpp_link_args = ['-fuse-ld=lld', '-L$NDK_LIB_DIR_32', '-lc', '-lm', '-ldl', '-llog', '-landroid']
[host_machine]
system = 'android'
cpu_family = 'arm'
cpu = 'armv7-a'
endian = 'little'
EOF
echo "=== ENTORNO REPARTIDO Y SANEADO AL 100% ==="
