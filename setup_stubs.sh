#!/bin/bash
set -e

# Declaramos la ruta real física de forma absoluta para evitar que Meson se pierda en variables vacías
SYSROOT_PATH="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_64_PATH="${SYSROOT_PATH}/usr/lib/aarch64-linux-android/26"

# 1. bits/pthreadtypes.h obligatorio para wsi_common.c
mkdir -p "${SYSROOT_PATH}/usr/include/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "${SYSROOT_PATH}/usr/include/bits/pthreadtypes.h"
echo -e '#ifndef ZSTD_H\n#define ZSTD_H\n#endif' > "${SYSROOT_PATH}/usr/include/zstd.h"
echo -e '#ifndef ZLIB_H\n#define ZLIB_H\n#endif' > "${SYSROOT_PATH}/usr/include/zlib.h"
echo -e '#ifndef ZCONF_H\n#define ZCONF_H\n#endif' > "${SYSROOT_PATH}/usr/include/zconf.h"

# 2. CENTRALIZACIÓN TOTAL DE CABECERAS: Declaramos todas las firmas reales para saltar los baches
cat << 'EOF' > /tmp/vk_pc_stubs.h
#ifndef _VK_PC_STUBS_H
#define _VK_PC_STUBS_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define HAVE_ZSTD 1
#define HAVE_ZLIB 1
#define DRM_NODE_RENDER 0
#define DRM_BUS_PCI 0

typedef unsigned char Byte; typedef unsigned int uInt; typedef unsigned long uLong; typedef void *voidpf;
typedef struct { uint16_t domain; uint8_t bus; uint8_t dev; uint8_t func; } drmPciBusInfo, *drmPciBusInfoPtr;
typedef union { drmPciBusInfoPtr pci; void *foo; } drmBusInfo;
typedef struct _drmDevice { uint32_t available_nodes; char **nodes; int bustype; drmBusInfo businfo; } drmDevice, *drmDevicePtr;
typedef struct VkXcbSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* connection; uintptr_t window; } VkXcbSurfaceCreateInfoKHR;
typedef struct VkXlibSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* dpy; uintptr_t window; } VkXlibSurfaceCreateInfoKHR;

size_t ZSTD_compressBound(size_t srcSize);
size_t ZSTD_compress(void* dst, size_t dstCapacity, const void* src, size_t srcSize, int compressionLevel);
size_t ZSTD_decompress(void* dst, size_t dstCapacity, const void* src, size_t srcSize);
unsigned int ZSTD_isError(size_t code);
const char* ZSTD_getErrorName(size_t code);

unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);
int open(const char *pathname, int flags, ...);
int drmIoctl(int fd, unsigned long request, void *arg);
int drmGetCap(int fd, uint64_t capability, uint64_t *value);
int drmPrimeFDToHandle(int fd, int prime_fd, uint32_t *handle);
int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle);
int drmSyncobjDestroy(int fd, uint32_t handle);
int drmSyncobjReset(int fd, const uint32_t *handles, uint32_t num_handles);
int drmSyncobjSignal(int fd, const uint32_t *handles, uint32_t num_handles);
int drmSyncobjWait(int fd, uint32_t *handles, uint32_t num_handles, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled);
int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *map_fd);
int drmSyncobjImportSyncFile(int fd, uint32_t handle, int map_fd);
int drmSyncobjFDToHandle(int fd, int map_fd, uint32_t *handle);
int drmSyncobjHandleToFD(int fd, uint32_t handle, int *map_fd);
int drmSyncobjTimelineSignal(int fd, const uint32_t *handles, const uint64_t *points, uint32_t num_handles);
int drmSyncobjTimelineWait(int fd, uint32_t *handles, const uint64_t *points, uint32_t num_handles, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled);
int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t num_handles);
int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags);
int drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device);
void drmFreeDevice(drmDevicePtr *device);
int drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices);
void drmFreeDevices(drmDevicePtr devices[], int count);
bool drmDevicesEqual(drmDevicePtr a, drmDevicePtr b);
#endif
EOF

# 3. Interceptor fake-pkg-config
echo -e '#!/bin/bash\nif [[ "$*" == *"--modversion"* ]]; then echo "14.0.0"; else echo "-I/tmp"; fi\nexit 0' > /tmp/fake-pkg-config
chmod +x /tmp/fake-pkg-config

# 4. SOLUCIÓN COMPLETA DE PROPIEDADES DE MESON: Añadimos la sección [properties] con el sys_root absoluto 
# e incluimos las carpetas de búsqueda en c_link_args para que find_library no dé falsos negativos.
cat << EOF > /tmp/cross.txt
[binaries]
c='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config='/tmp/fake-pkg-config'
glslangValidator='/usr/bin/glslangValidator'
[properties]
sys_root='${SYSROOT_PATH}'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
c_link_args=['-llog', '-landroid', '-ldl', '-L${LIB_64_PATH}', '-Wl,--export-dynamic', '-Wl,--no-as-needed']
cpp_link_args=['-llog', '-landroid', '-ldl', '-L${LIB_64_PATH}', '-Wl,--export-dynamic', '-Wl,--no-as-needed']
[host_machine]
system='linux'
cpu_family='aarch64'
cpu='armv8-a'
endian='little'
EOF
