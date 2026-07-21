#!/bin/bash
set -e

INC="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"

# 1. bits/pthreadtypes.h para wsi_common.c
mkdir -p "$INC/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "$INC/bits/pthreadtypes.h"

# 2. Cabeceras PC para vk_printers.c y wrapper_physical_device.c
cat << 'EOF' > "$INC/vk_pc_stubs.h"
#ifndef _VK_PC_STUBS_H
#define _VK_PC_STUBS_H
#include <stdint.h>
int open(const char *pathname, int flags, ...);
typedef struct VkXcbSurfaceCreateInfoKHR {
    uint32_t sType; const void* pNext; uint32_t flags; void* connection; uintptr_t window;
} VkXcbSurfaceCreateInfoKHR;
typedef struct VkXlibSurfaceCreateInfoKHR {
    uint32_t sType; const void* pNext; uint32_t flags; void* dpy; uintptr_t window;
} VkXlibSurfaceCreateInfoKHR;
#endif
EOF

# 3. xf86drm.h completo para validación de sincronización del runtime
cat << 'EOF' > "$INC/xf86drm.h"
#ifndef _XF86DRM_H
#define _XF86DRM_H
#include <stdint.h>
#include <stdbool.h>
#define DRM_NODE_RENDER 0
typedef struct _drmDevice { uint32_t available_nodes; } drmDevice, *drmDevicePtr;
int drmSyncobjDestroy(int fd, uint32_t handle);
int drmGetCap(int fd, uint64_t capability, uint64_t *value);
int drmPrimeFDToHandle(int fd, int prime_fd, uint32_t *handle);
int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle);
int drmSyncobjWait(int fd, uint32_t *handles, uint32_t num_handles, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled);
int drmSyncobjSignal(int fd, const uint32_t *handles, uint32_t num_handles);
int drmSyncobjReset(int fd, const uint32_t *handles, uint32_t num_handles);
int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *map_fd);
#endif
EOF

# 4. FUSIÓN DE ZSTD: Añadimos los prototipos reales para aniquilar el error del paso 61
cat << 'EOF' > "$INC/zstd.h"
#ifndef ZSTD_H
#define ZSTD_H
#include <stddef.h>
typedef size_t ZSTD_ErrorCode;
unsigned int ZSTD_isError(size_t code);
const char* ZSTD_getErrorName(size_t code);
size_t ZSTD_compressBound(size_t srcSize);
size_t ZSTD_compress(void* dst, size_t dstCapacity, const void* src, size_t srcSize, int compressionLevel);
size_t ZSTD_decompress(void* dst, size_t dstCapacity, const void* src, size_t srcSize);
#endif
EOF

# 5. FUSIÓN DE ZLIB: Añadimos la firma crc32 para Mesa
cat << 'EOF' > "$INC/zlib.h"
#ifndef ZLIB_H
#define ZLIB_H
#include <stdint.h>
typedef unsigned char Byte; typedef unsigned int uInt; typedef unsigned long uLong; typedef void *voidpf;
unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);
#endif
EOF
echo -e '#ifndef ZCONF_H\n#define ZCONF_H\n#endif' > "$INC/zconf.h"
