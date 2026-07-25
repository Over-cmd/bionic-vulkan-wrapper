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
  sed -i "1i ${ESTRIC_PC}" src/vulkan/wrapper/artifacts.cpp 2>/dev/null || sed -i "1i ${ESTRUCTURAS_PC}" src/vulkan/wrapper/artifacts.cpp
fi

echo "=== 4. LA VICTORIA FINAL: Manteniendo meson.build y dependencias de tu Link ==="
if [ -f "meson.build" ]; then
  sed -i "s/cc.find_library('dl'.*)/dependency('', required : false)/g" meson.build
  sed -i 's/cc.find_library("dl".*)/dependency("", required : false)/g' meson.build
  sed -i "s/cc.find_library('rt'.*)/dependency('', required : false)/g" meson.build
  sed -i 's/cc.find_library("rt".*)/dependency("", required : false)/g' meson.build
  echo "Bypasses de dependencias sincronizados."
fi

echo "=== 5. EL REEMPLAZO DEFINITIVO DE BITS: Renombrando ffs y ffsll en el código fuente ==="
if [ -f "src/util/bitscan.c" ]; then
  # Renombramos las funciones lógicas para que Clang no choque contra strings.h del NDK r25c
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.c
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.c
  echo "Funciones de bits renombradas en bitscan.c con éxito."
fi
if [ -f "src/util/bitscan.h" ]; then
  # Sincronizamos las llamadas en las cabeceras internas del core de Mesa
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.h
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.h
  echo "Prototipos de cabeceras sincronizados en bitscan.h con éxito."
fi

echo "=== 6. Inyectando stubs del Kernel para adrenotools al final de wrapper_log.c ==="
cat << 'EOF' >> src/vulkan/wrapper/wrapper_log.c

/* Stubs de bajo nivel para compatibilidad total con el enlazador de Android */
#include <stdint.h>
#include <stddef.h>

void *adrenotools_open_libvulkan(int dlopenMode, int featureFlags, const char *tmpLibDir, const char *hookLibDir, const char *customDriverDir, const char *customDriverName, const char *fileRedirectDir, void **userMappingHandle) { return NULL; }
EOF
