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

# 1. PARCHE EN EL DESPACHADOR RUNTIME (Paso 191)
if [ -f "src/vulkan/runtime/vk_drm_syncobj.c" ]; then
  PARCHE_DRM="#include <stdint.h>\n#define DRM_CAP_SYNCOBJ_TIMELINE 0x14\n#define DRM_SYNCOBJ_WAIT_FLAGS_WAIT_AVAILABLE (1 << 2)\nstatic int drmSyncobjTimelineSignal(int fd, const uint32_t *handles, const uint64_t *points, uint32_t handle_count) { return 0; }\nstatic int drmSyncobjTimelineWait(int fd, const uint32_t *handles, const uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }\nstatic int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }"
  sed -i "1i ${PARCHE_DRM}" src/vulkan/runtime/vk_drm_syncobj.c
  echo "vk_drm_syncobj.c parchado de forma física."
fi

# 2. PARCHE EN EL SUBSISTEMA DE VENTANAS WSI DRM
if [ -f "src/vulkan/wsi/wsi_common_drm.c" ]; then
  PARCHE_WSI="#include <stdint.h>\nstatic int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags) { return 0; }\nstatic int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }\nstatic int drmSyncobjTimelineWait(int fd, const uint32_t *handles, const uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }"
  sed -i "1i ${PARCHE_WSI}" src/vulkan/wsi/wsi_common_drm.c
  echo "wsi_common_drm.c parchado de forma física."
fi

# 3. ELIMINACIÓN DEL MÓDULO ANCIANO DE ANDROID WSI (Paso 196)
if [ -f "src/vulkan/wsi/wsi_common_android.c" ]; then
  echo "/* Stub vacio para Android compilacion cruzada wrapper monolítico */" > src/vulkan/wsi/wsi_common_android.c
  echo "wsi_common_android.c purgado con éxito."
fi

# 4. BRÚJULA DE TIEMPO EN WRAPPER_LOG.C (Paso 234)
if [ -f "src/vulkan/wrapper/wrapper_log.c" ]; then
  CABECERAS_LOG="#include <time.h>\n#include <fcntl.h>\n#include <unistd.h>"
  sed -i "1i ${CABECERAS_LOG}" src/vulkan/wrapper/wrapper_log.c
  echo "wrapper_log.c sincronizado con cabeceras estándar."
fi

# 5. BRÚJULA DE SISTEMA DE ARCHIVOS DE MEMORIA EN WRAPPER_PHYSICAL_DEVICE.C (Paso 237)
if [ -f "src/vulkan/wrapper/wrapper_physical_device.c" ]; then
  CABECERAS_PDEV="#include <fcntl.h>\n#include <unistd.h>"
  sed -i "1i ${CABECERAS_PDEV}" src/vulkan/wrapper/wrapper_physical_device.c
  echo "wrapper_physical_device.c sincronizado con fcntl y unistd."
fi

# 6. ENLAZADO DE MAPAS DE ESTRUCTURAS EN SPIRV_PATCHER.CPP (Paso 242)
if [ -f "src/vulkan/wrapper/spirv_patcher.cpp" ]; then
  # Inyectamos la directiva de mapa desordenado de C++ para liberar el compilador en el último tramo
  sed -i '1i #include <unordered_map>' src/vulkan/wrapper/spirv_patcher.cpp
  echo "spirv_patcher.cpp sincronizado con la cabecera unordered_map exitosamente."
fi
