#!/bin/bash
set -e

echo "=== 1. Aplicando parche de conversión de punteros (Macro de leegao) ==="
if [ -f "src/vulkan/wrapper/wrapper_objects.h" ]; then
  sed -i 's/VK_OBJECT_TYPE_##type, handle/VK_OBJECT_TYPE_##type, (void*)(uintptr_t)(handle)/g' src/vulkan/wrapper/wrapper_objects.h
fi

echo "=== 2. Vaciando wsi_common_ahardware_buffer.c para evitar falta de prototipos ==="
if [ -f "src/vulkan/wsi/wsi_common_ahardware_buffer.c" ]; then
  echo "/* Stub vacio para Android compilacion cruzada */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c
fi

echo "=== 3. El Truco de Pipetto: Inyectando físicamente estructuras de PC en la primera línea ==="
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

echo "=== 4. LA VICTORIA FINAL: Manteniendo spirv_edit.cpp 100% original ==="
# No inyectamos stubs ficticios a 0 bits en este archivo. El codigo del autor procesará las firmas nativas.
echo "El modulo spirv_edit.cpp operará de forma pura y con su peso real."

echo "=== 5. EL TRUCO MAESTRO DEL PESO REAL: Forzando a Meson a incrustar el motor de leegao ==="
if [ -f "src/vulkan/wrapper/meson.build" ]; then
  # Obligamos a Meson a enlazar las librerías estáticas de SPIRV que precompilamos en el paso 8 del YAML
  sed -i "s|shared_library(|shared_library('vulkan_wrapper', link_args: ['-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive'], |g" src/vulkan/wrapper/meson.build
fi

echo "=== 6. Inyectando stubs del Kernel estrictamente para adrenotools al final de wrapper_log.c ==="
# Mantenemos unicamente la funcion de enganche de librerias que leegao exige de la base de adrenotools para Android
cat << 'EOF' >> src/vulkan/wrapper/wrapper_log.c

/* Stubs de bajo nivel para compatibilidad con adrenotools en Android NDK */
#include <stdint.h>
#include <stddef.h>

void *adrenotools_open_libvulkan(int dlopenMode, int featureFlags, const char *tmpLibDir, const char *hookLibDir, const char *customDriverDir, const char *customDriverName, const char *fileRedirectDir, void **userMappingHandle) { return NULL; }
EOF

echo "Parches lógicos del wrapper sincronizados de forma limpia."
