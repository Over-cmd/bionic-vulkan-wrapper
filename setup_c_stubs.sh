#!/bin/bash
set -e

INC="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"

# 1. bits/pthreadtypes.h obligatorio para wsi_common.c
mkdir -p "$INC/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "$INC/bits/pthreadtypes.h"

# 2. CENTRALIZACIÓN DE STUBS COMPLETA: Metemos Zstd, Zlib y PC juntos 
# para obligar a Clang a leerlos de forma masiva en cada archivo de Mesa
cat << 'EOF' > "$INC/vk_pc_stubs.h"
#ifndef _VK_PC_STUBS_H
#define _VK_PC_STUBS_H
#include <stdint.h>
#include <stddef.h>

// Bypass global para compress.c y crc32.c
#define HAVE_ZSTD 1
#define HAVE_ZLIB 1

// Tipos requeridos por crc32.c
typedef unsigned char Byte;
typedef unsigned int uInt;
typedef unsigned long uLong;
typedef void *voidpf;

// Prototipos de Zstandard exigidos por compress.c
typedef size_t ZSTD_ErrorCode;
unsigned int ZSTD_isError(size_t code);
const char* ZSTD_getErrorName(size_t code);
size_t ZSTD_compressBound(size_t srcSize);
size_t ZSTD_compress(void* dst, size_t dstCapacity, const void* src, size_t srcSize, int compressionLevel);
size_t ZSTD_decompress(void* dst, size_t dstCapacity, const void* src, size_t srcSize);

// Prototipo de hash exigido por crc32.c
unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);

// Prototipos del sistema de archivos de Android
int open(const char *pathname, int flags, ...);

// Estructuras de PC para vk_printers.h
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
