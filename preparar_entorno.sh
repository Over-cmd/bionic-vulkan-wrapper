#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO PKG-CONFIG Y ARCHIVOS DE MÁQUINA ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# 1. Carpetas y blindaje xf86drm.h (fuerza carga DRM)
mkdir -p local_pkgconfig local_include/bits
printf '#ifndef _XF86DRM_H_\n#define _XF86DRM_H_\n#include <stdint.h>\n#include <stddef.h>\n#include <stdbool.h>\n#define DRM_CAP_SYNCOBJ_TIMELINE 0x13\n#define DRM_BUS_PCI 0\n#define DRM_BUS_PLATFORM 3\n#define DRM_BUS_HOST1X 4\n#define DRM_NODE_RENDER 2\n#ifdef __cplusplus\nextern "C" {\n#endif\ntypedef struct _drmVersion { int version_major; int version_minor; int version_patchlevel; char *name; char *date; char *desc; int name_len; int date_len; int desc_len; } drmVersion, *drmVersionPtr;\ntypedef struct _drmPciBusInfo { uint16_t domain; uint8_t bus; uint8_t dev; uint8_t func; } drmPciBusInfo, *drmPciBusInfoPtr;\ntypedef struct _drmPciDeviceInfo { uint16_t vendor_id; uint16_t device_id; uint16_t subvendor_id; uint16_t subdevice_id; uint8_t revision_id; } drmPciDeviceInfo, *drmPciDeviceInfoPtr;\ntypedef struct _drmPlatformBusInfo { char *fullname; } drmPlatformBusInfo, *drmPlatformBusInfoPtr;\ntypedef struct _drmHost1xBusInfo { char *fullname; } drmHost1xBusInfo, *drmHost1xBusInfoPtr;\nstruct _drmDevice {\n    char **nodes;\n    int available_nodes;\n    int bustype;\n    union {\n        drmPciBusInfoPtr pci;\n        int usb;\n        drmPlatformBusInfoPtr platform;\n        drmHost1xBusInfoPtr host1x;\n    } businfo;\n    union {\n        drmPciDeviceInfoPtr pci;\n    } deviceinfo;\n};\ntypedef struct _drmDevice *drmDevicePtr;\ndrmVersionPtr drmGetVersion(int fd);\nvoid drmFreeVersion(drmVersionPtr v);\nchar *drmGetDeviceNameFromFd2(int fd);\nint drmIoctl(int fd, unsigned long request, void *arg);\nint drmGetCap(int fd, uint64_t capability, uint64_t *value);\nint drmGetDeviceFromDevId(uint64_t device, uint32_t flags, drmDevicePtr *dev);\nint drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device);\nvoid drmFreeDevice(drmDevicePtr *device);\nint drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices);\nvoid drmFreeDevices(drmDevicePtr devices[], int count);\nint drmDevicesEqual(drmDevicePtr a, drmDevicePtr b);\nint drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle);\nint drmSyncobjDestroy(int fd, uint32_t handle);\nint drmSyncobjTimelineSignal(int fd, uint32_t *handles, uint64_t *points, uint32_t count);\nint drmSyncobjSignal(int fd, uint32_t *handles, uint32_t count);\nint drmSyncobjQuery(int fd, uint32_t *handles, uint64_t *points, uint32_t count);\nint drmSyncobjReset(int fd, uint32_t *handles, uint32_t count);\nint drmSyncobjExportSyncFile(int fd, uint32_t handle, int *fd_out);\nint drmSyncobjImportSyncFile(int fd, uint32_t handle, int sync_file);\nint drmSyncobjFDToHandle(int fd, int handle_fd, uint32_t *handle);\nint drmSyncobjHandleToFD(int fd, uint32_t handle, int *handle_fd);\nint drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags);\nint drmSyncobjWait(int fd, uint32_t *handles, uint32_t count, int64_t timeout_ns, uint32_t flags, uint32_t *first_signaled);\nint drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint64_t count, int64_t timeout_ns, uint32_t flags, uint32_t *first_signaled);\n#ifdef __cplusplus\n}\n#endif\n#endif\n' > "local_include/xf86drm.h"
mkdir -p local_include/libdrm
cp -f local_include/xf86drm.h local_include/libdrm/xf86drm.h

# 2. Bypass pthreads, guarda vulkan y restaurar Pkg-Config
printf '#ifndef _BITS_PTHREADTYPES_H_\n#define _BITS_PTHREADTYPES_H_\n#include <pthread.h>\n#endif\n' > "local_include/bits/pthreadtypes.h"
if [ -f "include/vulkan/vulkan_core.h" ]; then
  sed -i 's/\r$//' include/vulkan/vulkan_core.h
  vulkan_structures="#ifndef _MESA_MALI_X11_SURFACE_GUARD_\n#define _MESA_MALI_X11_SURFACE_GUARD_\n#include <stdint.h>\ntypedef struct VkXlibSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* dpy; unsigned long window; } VkXlibSurfaceCreateInfoKHR;\ntypedef struct VkXcbSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* connection; uint32_t window; } VkXcbSurfaceCreateInfoKHR;\n#endif\n"
  sed -i "1i$vulkan_structures" include/vulkan/vulkan_core.h
fi

printf "prefix=%s\nlibdir=%s\nincludedir=%s/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -L\${libdir} -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$BASE_PWD/build_drm" "$BASE_PWD" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source/opt -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: glslang\nVersion: 14.0.0\nLibs: -L$BASE_PWD/glslang_source/build_64/glslang -lglslang\nCflags: -I$BASE_PWD/glslang_source\n" > local_pkgconfig/glslang.pc
printf "prefix=%s\nexec_prefix=\${prefix}\nlibdir=%s\nincludedir=\${prefix}/local_include\npkgconfig_libdir=\${libdir}\n\nName: libclc\nDescription: Library Compiler for OpenCL bytecode\nVersion: 18.0.0\nLibs: -L\${libdir} -lclc\nCflags: -I\${includedir}\n" "$BASE_PWD" "$NDK_LIB_DIR_64" > local_pkgconfig/libclc.pc

# 3. Generar crossfiles oficiales limpios de factoría
cat << EOF > cross64.txt
[binaries]
c = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '/bin/true'
pkg-config = '/usr/bin/pkg-config'
glslangValidator = '/usr/bin/glslangValidator'
[built-in options]
c_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include']
cpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include']
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
c_args = ['-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=hard', '-mfpu=neon', '-I$SYSROOT_PATH/usr/include']
cpp_args = ['-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=hard', '-mfpu=neon', '-I$SYSROOT_PATH/usr/include']
c_link_args = ['-fuse-ld=lld', '-L$NDK_LIB_DIR_32', '-lc', '-lm', '-ldl', '-llog', '-landroid']
cpp_link_args = ['-fuse-ld=lld', '-L$NDK_LIB_DIR_32', '-lc', '-lm', '-ldl', '-llog', '-landroid']
[host_machine]
system = 'android'
cpu_family = 'arm'
cpu = 'armv7-a'
endian = 'little'
EOF
echo "=== ENTORNO ENLAZADOR RESTAURADO AL PLANO COMPLETO GANADOR ==="
