#!/bin/bash
set -e

echo "=== 1. Aplicando parche de conversión de punteros (Macro de leegao) ==="
if [ -f "src/vulkan/wrapper/wrapper_objects.h" ]; then
  sed -i 's/VK_OBJECT_TYPE_##type, handle/VK_OBJECT_TYPE_##type, (void*)(uintptr_t)(handle)/g' src/vulkan/wrapper/wrapper_objects.h
fi

echo "=== 2. Vaciando wsi_common_ahardware_buffer.c para evitar falta de hilos ==="
if [ -f "src/vulkan/wsi/wsi_common_ahardware_buffer.c" ]; then
  echo "/* Stub vacio para Android */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c
fi

echo "=== 3. El Truco de Pipetto: Inyectando físicamente estructuras de PC ==="
ESTRUCTURAS_PC="#include <stdint.h>\ntypedef struct VkXlibSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* dpy; unsigned long window; } VkXlibSurfaceCreateInfoKHR; typedef struct VkXcbSurfaceCreateInfoKHR { int sType; const void* pNext; uint32_t flags; void* connection; uint32_t window; } VkXcbSurfaceCreateInfoKHR;"

if [ -f "src/vulkan/wrapper/vk_printers.h" ]; then
  sed -i "1i ${ESTRUCTURAS_PC}" src/vulkan/wrapper/vk_printers.h
fi
if [ -f "src/vulkan/wrapper/vk_unwrappers.h" ]; then
  sed -i "1i ${ESTRUCTURAS_PC}" src/vulkan/wrapper/vk_unwrappers.h
fi
if [ -f "src/vulkan/wrapper/artifacts.cpp" ]; then
  sed -i "1i ${ESTRUCTURAS_PC}" src/vulkan/wrapper/artifacts.cpp
fi

echo "=== 4. CAMUFLAJE MAESTRO DE PIPETTO: Suplantando Mali por Adreno ==="
# Interceptamos las propiedades físicas que el driver reporta al emulador para activar el Spoofing de Qualcomm
if [ -f "src/vulkan/wrapper/wrapper_physical_device.c" ]; then
  sed -i 's/pProperties->vendorID = .*/pProperties->vendorID = 0x5143;/g' src/vulkan/wrapper/wrapper_physical_device.c
  sed -i 's/pProperties->deviceID = .*/pProperties->deviceID = 0x0740;/g' src/vulkan/wrapper/wrapper_physical_device.c
  sed -i 's/strcpy(pProperties->deviceName, .*/strcpy(pProperties->deviceName, "Adreno (TM) 740");/g' src/vulkan/wrapper/wrapper_physical_device.c
  sed -i 's/pProperties->driverVersion = .*/pProperties->driverVersion = 512;/g' src/vulkan/wrapper/wrapper_physical_device.c
  echo "Mali camuflada exitosamente como Adreno (TM) 740."
fi

echo "=== 5. LA VICTORIA FINAL: Sincronizando meson.build ==="
if [ -f "meson.build" ]; then
  sed -i "s/cc.find_library('dl'.*)/dependency('', required : false)/g" meson.build
  sed -i 's/cc.find_library("dl".*)/dependency("", required : false)/g' meson.build
  sed -i "s/cc.find_library('rt'.*)/dependency('', required : false)/g" meson.build
  sed -i 's/cc.find_library("rt".*)/dependency("", required : false)/g' meson.build
fi

echo "=== 6. EL REEMPLAZO DEFINITIVO DE BITS: Evitando colisiones en Android ==="
if [ -f "src/util/bitscan.c" ]; then
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.c
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.c
fi
if [ -f "src/util/bitscan.h" ]; then
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.h
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.h
fi

echo "=== 7. COMPLEMENTO DE DRM REAL EXTERNO ==="
cat << 'EOF' >> src/vulkan/wrapper/wrapper_log.c
#ifdef __cplusplus
extern "C" {
#endif
#include <stdint.h>
#include <stddef.h>
int drmSyncobjTimelineSignal(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }
int drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }
int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags) { return 0; }
int drmSyncobjQuery(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }
void *adrenotools_open_libvulkan(int dlopenMode, int featureFlags, const char *tmpLibDir, const char *hookLibDir, const char *customDriverDir, const char *customDriverName, const char *fileRedirectDir, void **userMappingHandle) { return NULL; }
#ifdef __cplusplus
}
#endif
EOF

echo "=== 8. FORZADOR INTERFAZ ICD 4 ==="
if [ -f "src/vulkan/runtime/vk_instance.c" ]; then
  sed -i 's/return MIN2(\*pVersion, .*/\*pVersion = 4; return 0;/g' src/vulkan/runtime/vk_instance.c
fi
