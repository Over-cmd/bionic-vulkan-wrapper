#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# 1. Cabeceras biónicas del preprocesador de Android
mkdir -p "${SYSROOT_MAESTRO}/usr/include/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/bits/pthreadtypes.h"
echo -e '#ifndef ZSTD_H\n#define ZSTD_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zstd.h"
echo -e '#ifndef ZLIB_H\n#define ZLIB_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zlib.h"
echo -e '#ifndef ZCONF_H\n#define ZCONF_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zconf.h"

# 2. Inyector de firmas completo del Kernel y DRM (Soluciona error del paso 409)
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
unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);
size_t ZSTD_compressBound(size_t srcSize);
size_t ZSTD_compress(void* dst, size_t dstCapacity, const void* src, size_t srcSize, int compressionLevel);
size_t ZSTD_decompress(void* dst, size_t dstCapacity, const void* src, size_t srcSize);
unsigned int ZSTD_isError(size_t code); const char* ZSTD_getErrorName(size_t code);
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
typedef struct VkXcbSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* connection; uintptr_t window; } VkXcbSurfaceCreateInfoKHR;
typedef struct VkXlibSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* dpy; uintptr_t window; } VkXlibSurfaceCreateInfoKHR;
void* adrenotools_open_libvulkan(const char* a, const char* s);
#endif
EOF

# 3. Interceptor pkg-config e INI cross-file
echo -e '#!/bin/bash\nif [[ "$*" == *"--modversion"* ]]; then echo "14.0.0"; else echo "-I/tmp"; fi\nexit 0' > /tmp/fake-pkg-config
chmod +x /tmp/fake-pkg-config

cat << EOF > /tmp/cross.txt
[binaries]
c='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config='/tmp/fake-pkg-config'
glslangValidator='/usr/bin/glslangValidator'
[properties]
sys_root='${SYSROOT_MAESTRO}'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
c_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic']
cpp_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-stdlib=libc++']
[host_machine]
system='linux' ; cpu_family='aarch64' ; cpu='armv8-a' ; endian='little'
EOF
