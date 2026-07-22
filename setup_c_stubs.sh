#!/bin/bash
set -e

INC="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"

# 1. bits/pthreadtypes.h obligatorio para wsi_common.c
mkdir -p "$INC/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "$INC/bits/pthreadtypes.h"

# 2. CENTRALIZACIÓN ABSOLUTA: Agregamos las firmas de libdrm completas en la cabecera de PC
# para que el sed del workflow inyecte todo el ecosistema de sincronización al vuelo en vk_drm_syncobj.c
cat << 'EOF' > "$INC/vk_pc_stubs.h"
#ifndef _VK_PC_STUBS_H
#define _VK_PC_STUBS_H
#include <stdint.h>
#include <stdbool.h>
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
unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);

// Prototipos de sincronización libdrm exigidos en el paso 407 por vk_drm_syncobj.c y wsi_common_drm.c
#define DRM_NODE_RENDER 0
#define DRM_BUS_PCI 0
enum { DRM_BUS_PLATFORM = 1 };
typedef struct { uint16_t domain; uint8_t bus; uint8_t dev; uint8_t func; } drmPciBusInfo, *drmPciBusInfoPtr;
typedef union { drmPciBusInfoPtr pci; void *foo; } drmBusInfo;
typedef struct _drmDevice { uint32_t available_nodes; char **nodes; int bustype; drmBusInfo businfo; } drmDevice, *drmDevicePtr;

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

// Prototipos del sistema de archivos de Android
int open(const char *pathname, int flags, ...);

// Estructuras de PC para vk_printers.c
typedef struct VkXcbSurfaceCreateInfoKHR {
    uint32_t sType; const void* pNext; uint32_t flags; void* connection; uintptr_t window;
} VkXcbSurfaceCreateInfoKHR;

typedef struct VkXlibSurfaceCreateInfoKHR {
    uint32_t sType; const void* pNext; uint32_t flags; void* dpy; uintptr_t window;
} VkXlibSurfaceCreateInfoKHR;

#endif
EOF
