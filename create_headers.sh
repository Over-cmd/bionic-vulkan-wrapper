#!/bin/bash
set -e
mkdir -p local_include/libdrm
mkdir -p local_include/bits

echo "=== 1. Generando archivo de hilos vacío ==="
touch local_include/bits/pthreadtypes.h

echo "=== 2. Escribiendo xf86drm.h de Khronos de forma segura ==="
cat << 'EOF' > local_include/xf86drm.h
#ifndef _XF86DRM_H_
#define _XF86DRM_H__
#include <stdint.h>
#include <stddef.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include "../../include/drm-uapi/drm.h"

#ifndef DRM_SYNCOBJ_CREATE_SIGNALED
#define DRM_SYNCOBJ_CREATE_SIGNALED (1 << 0)
#endif
#ifndef DRM_SYNCOBJ_WAIT_FLAGS_WAIT_ALL
#define DRM_SYNCOBJ_WAIT_FLAGS_WAIT_FOR_SUBMIT (1 << 1)
#endif
#ifndef DRM_CAP_SYNCOBJ_TIMELINE
#define DRM_CAP_SYNCOBJ_TIMELINE 0x14
#endif

#ifndef DMA_BUF_IOCTL_EXPORT_SYNC_FILE
struct local_drm_syncobj_handle { uint32_t handle; uint32_t flags; int32_t fd; };
#define DMA_BUF_IOCTL_EXPORT_SYNC_FILE _IOWR('b', 2, struct local_drm_syncobj_handle)
#endif

typedef struct VkXlibSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* dpy; unsigned long window; } VkXlibSurfaceCreateInfoKHR;
typedef struct VkXcbSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* connection; uint32_t window; } VkXcbSurfaceCreateInfoKHR;

enum { DRM_BUS_PCI = 0, DRM_BUS_USB = 1, DRM_BUS_PLATFORM = 2, DRM_BUS_HOST1X = 3 };

typedef struct _drmPciBusInfo { uint16_t domain; uint8_t bus; uint8_t dev; uint8_t func; } drmPciBusInfo, *drmPciBusInfoPtr;

typedef struct _drmDevice { char **nodes; int available_nodes; int bustype; union { drmPciBusInfoPtr pci; void *usb; void *platform; void *oci; } businfo; union { void *pci; void *usb; void *platform; void *oci; } deviceinfo; } drmDevice, *drmDevicePtr;

#ifdef __cplusplus
extern "C" {
#endif
int drmIoctl(int fd, unsigned long request, void *arg);
int drmGetCap(int fd, uint64_t capability, uint64_t *value);
int drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device);
int drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices);
int drmDevicesEqual(drmDevicePtr a, drmDevicePtr b);
void drmFreeDevice(drmDevicePtr *device);
void drmFreeDevices(drmDevicePtr devices[], int count);
int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle);
int drmSyncobjDestroy(int fd, uint32_t handle);
int drmSyncobjHandleToFD(int fd, uint32_t handle, int *obj_fd);
int drmSyncobjFDToHandle(int fd, int obj_fd, uint32_t *handle);
int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags);
int drmSyncobjQuery(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count);
int drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled);
int drmSyncobjTimelineSignal(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count);
int drmSyncobjSignal(int fd, uint32_t *handles, uint32_t handle_count);
int drmSyncobjReset(int fd, uint32_t *handles, uint32_t handle_count);
int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *sync_file_fd);
int drmSyncobjImportSyncFile(int fd, uint32_t handle, int sync_file_fd);
int drmSyncobjWait(int fd, uint32_t *handles, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled);
#ifdef __cplusplus
}
#endif
#endif
EOF

cp local_include/xf86drm.h local_include/libdrm/xf86drm.h
echo "Cabeceras creadas con éxito."
