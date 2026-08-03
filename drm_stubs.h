#ifndef _XF86DRM_H_
#define _XF86DRM_H_
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define DRM_CAP_SYNCOBJ_TIMELINE 0x13
#define DRM_BUS_PCI 0
#define DRM_BUS_PLATFORM 3
#define DRM_BUS_HOST1X 4
#define DRM_NODE_RENDER 2

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _drmVersion { int version_major; int version_minor; int version_patchlevel; char *name; char *date; char *desc; int name_len; int date_len; int desc_len; } drmVersion, *drmVersionPtr;
typedef struct _drmPciBusInfo { uint16_t domain; uint8_t bus; uint8_t dev; uint8_t func; } drmPciBusInfo, *drmPciBusInfoPtr;
typedef struct _drmPciDeviceInfo { uint16_t vendor_id; uint16_t device_id; uint16_t subvendor_id; uint16_t subdevice_id; uint8_t revision_id; } drmPciDeviceInfo, *drmPciDeviceInfoPtr;
typedef struct _drmPlatformBusInfo { char *fullname; } drmPlatformBusInfo, *drmPlatformBusInfoPtr;
typedef struct _drmHost1xBusInfo { char *fullname; } drmHost1xBusInfo, *drmHost1xBusInfoPtr;

struct _drmDevice {
    char **nodes;
    int available_nodes;
    int bustype;
    union { drmPciBusInfoPtr pci; int usb; drmPlatformBusInfoPtr platform; drmHost1xBusInfoPtr host1x; } businfo;
    union { drmPciDeviceInfoPtr pci; } deviceinfo;
};
typedef struct _drmDevice *drmDevicePtr;

drmVersionPtr drmGetVersion(int fd);
void drmFreeVersion(drmVersionPtr v);
char *drmGetDeviceNameFromFd2(int fd);
int drmIoctl(int fd, unsigned long request, void *arg);
int drmGetCap(int fd, uint64_t capability, uint64_t *value);
int drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device);
void drmFreeDevice(drmDevicePtr *device);
int drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices);
void drmFreeDevices(drmDevicePtr devices[], int count);
int drmDevicesEqual(void *a, void *b);
int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle);
int drmSyncobjDestroy(int fd, uint32_t handle);
int drmSyncobjTimelineSignal(int fd, uint32_t *handles, uint64_t *points, uint32_t count);
int drmSyncobjSignal(int fd, uint32_t *handles, uint32_t count);
int drmSyncobjQuery(int fd, uint32_t *handles, uint64_t *points, uint32_t count);
int drmSyncobjReset(int fd, uint32_t *handles, uint32_t count);
int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *fd_out);
int drmSyncobjImportSyncFile(int fd, uint32_t handle, int sync_file);
int drmSyncobjFDToHandle(int fd, int handle_fd, uint32_t *handle);
int drmSyncobjHandleToFD(int fd, uint32_t handle, int *handle_fd);
int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags);
int drmSyncobjWait(int fd, uint32_t *handles, uint32_t count, int64_t timeout_ns, uint32_t flags, uint32_t *first_signaled);
int drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint64_t count, int64_t timeout_ns, uint32_t flags, uint32_t *first_signaled);

#ifdef __cplusplus
}
#endif
#endif
