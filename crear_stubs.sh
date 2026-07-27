#!/bin/bash
set -e
echo "=== ETAPA B: PREPARANDO CABECERAS PARA EL WRAPPER ORIGINAL DE LEEGAO ==="

# 1. Bypass de librerías find_library rígidas en Mesa 23
if [ -f "meson.build" ]; then
  sed -i "s/cc.find_library('dl'.*)/dependency('', required : false)/g" meson.build
  sed -i 's/cc.find_library("dl".*)/dependency("", required : false)/g' meson.build
  sed -i "s/cc.find_library('rt'.*)/dependency('', required : false)/g" meson.build
  sed -i 's/cc.find_library("rt".*)/dependency("", required : false)/g' meson.build
fi

# 2. Sincronización de bits para el compilador biónico de Google
if [ -f "src/util/bitscan.c" ]; then
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.c
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.c
fi
if [ -f "src/util/bitscan.h" ]; then
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.h
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.h
fi

# 3. Solución a los pasos de sincronización DRM de Mesa 23
if [ -f "src/vulkan/runtime/vk_drm_syncobj.c" ]; then
  PARCHE_DRM="#include <stdint.h>\n#define DRM_CAP_SYNCOBJ_TIMELINE 0x14\n#define DRM_SYNCOBJ_WAIT_FLAGS_WAIT_AVAILABLE (1 << 2)\nstatic int drmSyncobjTimelineSignal(int fd, const uint32_t *handles, const uint64_t *points, uint32_t handle_count) { return 0; }\nstatic int drmSyncobjTimelineWait(int fd, const uint32_t *handles, const uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }\nstatic int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }"
  sed -i "1i ${PARCHE_DRM}" src/vulkan/runtime/vk_drm_syncobj.c
fi

if [ -f "src/vulkan/wsi/wsi_common_drm.c" ]; then
  PARCHE_WSI="#include <stdint.h>\nstatic int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags) { return 0; }\nstatic int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }\nstatic int drmSyncobjTimelineWait(int fd, const uint32_t *handles, const uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }"
  sed -i "1i ${PARCHE_WSI}" src/vulkan/wsi/wsi_common_drm.c
fi

if [ -f "src/vulkan/wsi/wsi_common_android.c" ]; then
  echo "/* Stub vacio para Android compilacion cruzada wrapper monolítico */" > src/vulkan/wsi/wsi_common_android.c
fi

# 4. Inyección de cabeceras estándar de C exigidas por Clang en los archivos del wrapper de leegao
if [ -f "src/vulkan/wrapper/wrapper_log.c" ]; then
  sed -i "1i #include <time.h>\n#include <fcntl.h>\n#include <unistd.h>" src/vulkan/wrapper/wrapper_log.c
fi

if [ -f "src/vulkan/wrapper/wrapper_physical_device.c" ]; then
  sed -i "1i #include <fcntl.h>\n#include <unistd.h>" src/vulkan/wrapper/wrapper_physical_device.c
fi

if [ -f "src/vulkan/wrapper/spirv_patcher.cpp" ]; then
  sed -i '1i #include <unordered_map>' src/vulkan/wrapper/spirv_patcher.cpp
fi

echo "Entorno de código purificado para el Wrapper Original de leegao."
