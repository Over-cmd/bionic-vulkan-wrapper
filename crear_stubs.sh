#!/bin/bash
set -e
echo "=== ETAPA B: APLICANDO PARCHES FÍSICOS AL CÓDIGO FUENTE ==="

if [ -f "meson.build" ]; then
  sed -i "s/cc.find_library('dl'.*)/dependency('', required : false)/g" meson.build
  sed -i 's/cc.find_library("dl".*)/dependency("", required : false)/g' meson.build
  sed -i "s/cc.find_library('rt'.*)/dependency('', required : false)/g" meson.build
  sed -i 's/cc.find_library("rt".*)/dependency("", required : false)/g' meson.build
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
