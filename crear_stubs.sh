#!/bin/bash
set -e
echo "=== ETAPA B: PREPARANDO ENTORNO ESTABLE DE MESA 23 DE PIPETTO ==="

ESTRUCTURAS_PC_REALES="#ifndef MESA_WRAPPER_PC_STRUCTS_GUARD\n#define MESA_WRAPPER_PC_STRUCTS_GUARD\n#include <stdint.h>\ntypedef struct Display Display;\ntypedef unsigned long Window;\ntypedef unsigned long VisualID;\ntypedef struct xcb_connection_t xcb_connection_t;\ntypedef uint32_t xcb_window_t;\ntypedef uint32_t xcb_visualid_t;\ntypedef struct VkXlibSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; Display* dpy; Window window; } VkXlibSurfaceCreateInfoKHR;\ntypedef struct VkXcbSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; xcb_connection_t* connection; xcb_window_t window; } VkXcbSurfaceCreateInfoKHR;\n#endif"

if [ -f "include/vulkan/vulkan_core.h" ]; then
  sed -i "1i ${ESTRUCTURAS_PC_REALES}" include/vulkan/vulkan_core.h
fi
if [ -f "src/vulkan/wrapper/vk_printers.h" ]; then
  sed -i "1i ${ESTRUCTURAS_PC_REALES}" src/vulkan/wrapper/vk_printers.h
fi
if [ -f "src/vulkan/wrapper/vk_unwrappers.h" ]; then
  sed -i "1i ${ESTRUCTURAS_PC_REALES}" src/vulkan/wrapper/vk_unwrappers.h
fi

if [ -f "meson.build" ]; then
  sed -i "s/'-Werror=format'/'-Wno-error=format'/g" meson.build 2>/dev/null || true
  sed -i "s/'-Werror=format-security'/'-Wno-error=format-security'/g" meson.build 2>/dev/null || true
  sed -i "s/cc.find_library('dl'.*)/dependency('', required : false)/g" meson.build 2>/dev/null || true
  sed -i 's/cc.find_library("dl".*)/dependency("", required : false)/g' meson.build 2>/dev/null || true
  sed -i "s/cc.find_library('rt'.*)/dependency('', required : false)/g" meson.build 2>/dev/null || true
  sed -i 's/cc.find_library("rt".*)/dependency("", required : false)/g' meson.build 2>/dev/null || true
fi

if [ -f "src/util/bitscan.c" ]; then
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.c
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.c
fi
if [ -f "src/util/bitscan.h" ]; then
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.h
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.h
fi

if [ -f "src/vulkan/runtime/vk_drm_syncobj.c" ]; then
  PARCHE_DRM="#include <stdint.h>\n#define DRM_CAP_SYNCOBJ_TIMELINE 0x14\n#define DRM_SYNCOBJ_WAIT_FLAGS_WAIT_AVAILABLE (1 << 2)\nstatic int drmSyncobjTimelineSignal(int fd, const uint32_t *handles, const uint64_t *points, uint32_t handle_count) { return 0; }\nstatic int drmSyncobjTimelineWait(int fd, const uint32_t *handles, const uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }\nstatic int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }"
  sed -i "1i ${PARCHE_DRM}" src/vulkan/runtime/vk_drm_syncobj.c
fi

if [ -f "src/vulkan/wsi/wsi_common_drm.c" ]; then
  PARCHE_WSI="#include <stdint.h>\nstatic int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags) { return 0; }\nstatic int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }\nstatic int drmSyncobjTimelineWait(int fd, const uint32_t *handles, const uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }"
  sed -i "1i ${PARCHE_WSI}" src/vulkan/wsi/wsi_common_drm.c
fi

if [ -f "src/vulkan/wsi/wsi_common.c" ]; then
  sed -i 's|#include <bits/pthreadtypes.h>|#include <pthread.h>|g' src/vulkan/wsi/wsi_common.c
fi

if [ -f "src/vulkan/wsi/wsi_common_ahardware_buffer.c" ]; then
  echo "/* Stub vacio para Android */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c
fi

if [ -f "src/vulkan/wrapper/wrapper_device_memory.c" ]; then
  sed -i "1i #include <fcntl.h>" src/vulkan/wrapper/wrapper_device_memory.c
fi

sed -i "1i #include <time.h>\n#include <fcntl.h>\n#include <unistd.h>" src/vulkan/wrapper/wrapper_log.c 2>/dev/null || true
sed -i "1i #include <fcntl.h>\n#include <unistd.h>" src/vulkan/wrapper/wrapper_physical_device.c 2>/dev/null || true
sed -i '1i #include <unordered_map>' src/vulkan/wrapper/spirv_patcher.cpp 2>/dev/null || true
echo "Fase de stubs finalizada en limpio para tu chasis compatible de Android."
