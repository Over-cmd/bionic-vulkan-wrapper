#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO WINLATOR FOCAL (MALI PURO) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# 1. Creación fragmentada y segura de xf86drm.h para GPU Mali (Evita truncamiento web)
mkdir -p local_pkgconfig local_include/libdrm local_include/bits
echo '#ifndef _XF86DRM_H_' > local_include/xf86drm.h
echo '#define _XF86DRM_H_' >> local_include/xf86drm.h
echo '#include <stdint.h>' >> local_include/xf86drm.h
echo '#include <stddef.h>' >> local_include/xf86drm.h
echo '#include <stdbool.h>' >> local_include/xf86drm.h
echo '#define DRM_CAP_SYNCOBJ_TIMELINE 0x13' >> local_include/xf86drm.h
echo '#define DRM_BUS_PCI 0' >> local_include/xf86drm.h
echo '#define DRM_BUS_PLATFORM 3' >> local_include/xf86drm.h
echo '#define DRM_BUS_HOST1X 4' >> local_include/xf86drm.h
echo '#define DRM_NODE_RENDER 2' >> local_include/xf86drm.h
echo 'typedef struct _drmVersion { int version_major; int version_minor; int version_patchlevel; char *name; char *date; char *desc; int name_len; int date_len; int desc_len; } drmVersion, *drmVersionPtr;' >> local_include/xf86drm.h
echo 'typedef struct _drmPciBusInfo { uint16_t domain; uint8_t bus; uint8_t dev; uint8_t func; } drmPciBusInfo, *drmPciBusInfoPtr;' >> local_include/xf86drm.h
echo 'typedef struct _drmPciDeviceInfo { uint16_t vendor_id; uint16_t device_id; uint16_t subvendor_id; uint16_t subdevice_id; uint8_t revision_id; } drmPciDeviceInfo, *drmPciDeviceInfoPtr;' >> local_include/xf86drm.h
echo 'typedef struct _drmPlatformBusInfo { char *fullname; } drmPlatformBusInfo, *drmPlatformBusInfoPtr;' >> local_include/xf86drm.h
echo 'typedef struct _drmHost1xBusInfo { char *fullname; } drmHost1xBusInfo, *drmHost1xBusInfoPtr;' >> local_include/xf86drm.h
echo 'struct _drmDevice { char **nodes; int available_nodes; int bustype; union { drmPciBusInfoPtr pci; int usb; drmPlatformBusInfoPtr platform; drmHost1xBusInfoPtr host1x; } businfo; union { drmPciDeviceInfoPtr pci; } deviceinfo; };' >> local_include/xf86drm.h
echo 'typedef struct _drmDevice *drmDevicePtr;' >> local_include/xf86drm.h
echo 'drmVersionPtr drmGetVersion(int fd); void drmFreeVersion(drmVersionPtr v); char *drmGetDeviceNameFromFd2(int fd); int drmIoctl(int fd, unsigned long request, void *arg);' >> local_include/xf86drm.h
echo 'int drmGetCap(int fd, uint64_t capability, uint64_t *value); int drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device); void drmFreeDevice(drmDevicePtr *device);' >> local_include/xf86drm.h
echo 'int drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices); void drmFreeDevices(drmDevicePtr devices[], int count); int drmDevicesEqual(void *a, void *b);' >> local_include/xf86drm.h
echo 'int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle); int drmSyncobjDestroy(int fd, uint32_t handle);' >> local_include/xf86drm.h
echo 'int drmSyncobjTimelineSignal(int fd, uint32_t *handles, uint64_t *points, uint32_t count); int drmSyncobjSignal(int fd, uint32_t *handles, uint32_t count);' >> local_include/xf86drm.h
echo 'int drmSyncobjQuery(int fd, uint32_t *handles, uint64_t *points, uint32_t count); int drmSyncobjReset(int fd, uint32_t *handles, uint32_t count);' >> local_include/xf86drm.h
echo 'int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *fd_out); int drmSyncobjImportSyncFile(int fd, uint32_t handle, int sync_file);' >> local_include/xf86drm.h
echo 'int drmSyncobjFDToHandle(int fd, int handle_fd, uint32_t *handle); int drmSyncobjHandleToFD(int fd, uint32_t handle, int *handle_fd);' >> local_include/xf86drm.h
echo 'int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags);' >> local_include/xf86drm.h
echo 'int drmSyncobjWait(int fd, uint32_t *handles, uint32_t count, int64_t timeout_ns, uint32_t flags, uint32_t *first_signaled);' >> local_include/xf86drm.h
echo 'int drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint64_t count, int64_t timeout_ns, uint32_t flags, uint32_t *first_signaled);' >> local_include/xf86drm.h
echo '#endif' >> local_include/xf86drm.h
cp -f local_include/xf86drm.h local_include/libdrm/xf86drm.h

# 2. Pthreads y superficies gráficas WSI de leegao
printf '#ifndef _BITS_PTHREADTYPES_H_\n#define _BITS_PTHREADTYPES_H_\n#include <pthread.h>\n#endif\n' > "local_include/bits/pthreadtypes.h"
if [ -f "include/vulkan/vulkan_core.h" ]; then
  sed -i 's/\r$//' include/vulkan/vulkan_core.h
  vulkan_wsi="#ifndef _MESA_MALI_X11_SURFACE_GUARD_\n#define _MESA_MALI_X11_SURFACE_GUARD_\n#include <stdint.h>\ntypedef struct VkXlibSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* dpy; unsigned long window; } VkXlibSurfaceCreateInfoKHR;\ntypedef struct VkXcbSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* connection; uint32_t window; } VkXcbSurfaceCreateInfoKHR;\n#endif\n"
  sed -i "1i$vulkan_wsi" include/vulkan/vulkan_core.h
fi

# 3. Pkg-Config equilibrados de factoría
printf "prefix=%s\nlibdir=%s\nincludedir=\textprefix\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -L\${libdir} -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$BASE_PWD/build_drm" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source/opt -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: glslang\nVersion: 14.0.0\nLibs: -L$BASE_PWD/glslang_source/build_64/glslang -lglslang\nCflags: -I$BASE_PWD/glslang_source\n" > local_pkgconfig/glslang.pc
printf "prefix=%s\nexec_prefix=\${prefix}\nlibdir=%s\nincludedir=\${prefix}/local_include\npkgconfig_libdir=\${libdir}\n\nName: libclc\nDescription: Library Compiler for OpenCL bytecode\nVersion: 18.0.0\nLibs: -L\textprefix\${libdir} -lclc\nCflags: -I\${includedir}\n" "$BASE_PWD" "$NDK_LIB_DIR_64" > local_pkgconfig/libclc.pc

# 4. Configurar Crossfiles puros para Winlator Bionic/Focal
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
echo "=== ENTORNO REPARTIDO Y SANEADO AL 100% ==="
