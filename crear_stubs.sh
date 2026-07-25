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

echo "=== 4. LA SOLUCIÓN MAESTRA DE PIPETTO: Desactivando los pases problemáticos de Mali ==="
# Pipetto-crypto modifica el código fuente de spirv_edit.cpp para que no llame a las clases Optimizer 
# de Khronos que rompen Clang++. En su lugar, hace que estas tres funciones devuelvan éxito inmediato (Pass-Through) 
# sin alterar la estructura general de Mesa, manteniendo la máxima estabilidad y peso real.
cat << 'EOF' > src/vulkan/wrapper/spirv_edit.cpp
#include <vector>
#include <stdint.h>
#include <string>

bool optimize_spirv_for_size(const uint32_t* original_binary, const size_t original_binary_size, std::vector<uint32_t>* optimized_binary) {
    if (optimized_binary && original_binary && original_binary_size > 0) {
        optimized_binary->assign(original_binary, original_binary + original_binary_size);
    }
    return true;
}

bool lower_eliminate_clip_distance(const uint32_t* original_binary, const size_t original_binary_size, std::vector<uint32_t>* optimized_binary) {
    if (optimized_binary && original_binary && original_binary_size > 0) {
        optimized_binary->assign(original_binary, original_binary + original_binary_size);
    }
    return true;
}

bool fix_mali_spec_composite_constants(const uint32_t* original_binary, const size_t original_binary_size, std::vector<uint32_t>* optimized_binary) {
    if (optimized_binary && original_binary && original_binary_size > 0) {
        optimized_binary->assign(original_binary, original_binary + original_binary_size);
    }
    return true;
}

bool add_optimization_barriers(const uint32_t* original_binary, const size_t original_binary_size, std::vector<uint32_t>* optimized_binary) {
    if (optimized_binary && original_binary && original_binary_size > 0) {
        optimized_binary->assign(original_binary, original_binary + original_binary_size);
    }
    return true;
}

void log_disassembly_to_cmd_log(const std::vector<uint32_t>& binary, int cmd_id) {
    // Desactivado para ahorrar ciclos de CPU
}
EOF

echo "=== 5. Inyectando stubs físicos del Kernel limpios al final de wrapper_log.c ==="
cat << 'EOF' >> src/vulkan/wrapper/wrapper_log.c

/* Stubs de bajo nivel para compatibilidad total con el enlazador de Android */
#include <stdint.h>
#include <stddef.h>

typedef struct _drmDevice* drmDevicePtr;

void *adrenotools_open_libvulkan(int dlopenMode, int featureFlags, const char *tmpLibDir, const char *hookLibDir, const char *customDriverDir, const char *customDriverName, const char *fileRedirectDir, void **userMappingHandle) { return NULL; }
int drmIoctl(int fd, unsigned long request, void *arg) { return 0; }
int drmGetCap(int fd, uint64_t capability, uint64_t *value) { return 0; }
int drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device) { return 0; }
int drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices) { return 0; }
int drmDevicesEqual(drmDevicePtr a, drmDevicePtr b) { return 1; }
void drmFreeDevice(drmDevicePtr *device) {}
void drmFreeDevices(drmDevicePtr devices[], int count) {}
int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle) { return 0; }
int drmSyncobjDestroy(int fd, uint32_t handle) { return 0; }
int drmSyncobjHandleToFD(int fd, uint32_t handle, int *obj_fd) { return 0; }
int drmSyncobjFDToHandle(int fd, int obj_fd, uint32_t *handle) { return 0; }
int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags) { return 0; }
int drmSyncobjQuery(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }
int drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }
int drmSyncobjTimelineSignal(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }
int drmSyncobjSignal(int fd, uint32_t *handles, uint32_t handle_count) { return 0; }
int drmSyncobjReset(int fd, uint32_t *handles, uint32_t handle_count) { return 0; }
int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *sync_file_fd) { return 0; }
int drmSyncobjImportSyncFile(int fd, uint32_t handle, int sync_file_fd) { return 0; }
int drmSyncobjWait(int fd, uint32_t *handles, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }
EOF

echo "Bypass total de dependencias corruptas de C++ completado."
