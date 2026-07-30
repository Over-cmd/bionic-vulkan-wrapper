#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO PKG-CONFIG Y BYPASS DE CABECERAS ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"

# 1. Creamos las carpetas de mapas de prioridad de Clang
mkdir -p local_pkgconfig local_include/libdrm local_include/bits

# 2. BLINDAJE DE ENLAZADOR: Escribimos el listado maestro de prototipos de xf86drm.h en C puro
printf '#ifndef _XF86DRM_H_\n#define _XF86DRM_H_\n#include <stdint.h>\n#include <stddef.h>\n#define DRM_CAP_SYNCOBJ_TIMELINE 0x13\n#define DRM_BUS_PCI 0\n#ifdef __cplusplus\nextern "C" {\n#endif\ntypedef struct _drmPciBusInfo { uint16_t domain; uint8_t bus; uint8_t dev; uint8_t func; } drmPciBusInfo, *drmPciBusInfoPtr;\nstruct _drmDevice { char **nodes; int available_nodes; int bustype; union { drmPciBusInfoPtr pci; int usb; int platform; } businfo; };\ntypedef struct _drmDevice *drmDevicePtr;\nint drmIoctl(int fd, unsigned long request, void *arg);\nint drmGetCap(int fd, uint64_t capability, uint64_t *value);\nint drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device);\nvoid drmFreeDevice(drmDevicePtr *device);\nint drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices);\nvoid drmFreeDevices(drmDevicePtr devices[], int count);\nint drmDevicesEqual(drmDevicePtr a, drmDevicePtr b);\nint drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle);\nint drmSyncobjDestroy(int fd, uint32_t handle);\nint drmSyncobjTimelineSignal(int fd, uint32_t *handles, uint64_t *points, uint32_t count);\nint drmSyncobjSignal(int fd, uint32_t *handles, uint32_t count);\nint drmSyncobjQuery(int fd, uint32_t *handles, uint64_t *points, uint32_t count);\nint drmSyncobjReset(int fd, uint32_t *handles, uint32_t count);\nint drmSyncobjExportSyncFile(int fd, uint32_t handle, int *fd_out);\nint drmSyncobjImportSyncFile(int fd, uint32_t handle, int sync_file);\nint drmSyncobjFDToHandle(int fd, int handle_fd, uint32_t *handle);\nint drmSyncobjHandleToFD(int fd, uint32_t handle, int *handle_fd);\nint drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags);\nint drmSyncobjWait(int fd, uint32_t *handles, uint32_t count, int64_t timeout_ns, uint32_t flags, uint32_t *first_signaled);\nint drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint32_t count, int64_t timeout_ns, uint32_t flags, uint32_t *first_signaled);\n#ifdef __cplusplus\n}\n#endif\n#endif\n' > "local_include/xf86drm.h"
cp -f local_include/xf86drm.h local_include/libdrm/xf86drm.h

# 3. BYPASS DE HILOS ANDROID NDK: Redirigimos bits/pthreadtypes.h al pthread legítimo de Google
printf '#ifndef _BITS_PTHREADTYPES_H_\n#define _BITS_PTHREADTYPES_H_\n#include <pthread.h>\n#endif\n' > "local_include/bits/pthreadtypes.h"

# 4. REESCRITURA QUIRÚRGICA COMPLETA DE ESTRUCTURAS ANDROID: Python localiza el bloque forzado y suelda las variables legítimas en todas las definiciones de wsi_common.h
if [ -f "src/vulkan/wsi/wsi_common.h" ]; then
  echo "-> Soldando propiedades de intercambio de buffers de Android de factoría..."
  sed -i 's/\r$//' src/vulkan/wsi/wsi_common.h
  python3 - << 'EOF'
import re

with open("src/vulkan/wsi/wsi_common.h", "r") as f:
    text = f.read()

# Inyectamos de forma atómica en las tres estructuras principales del archivo usando expresiones lícitas independientes
text = re.sub(r'struct wsi_device\s*\{', 'struct wsi_device {\n   PFN_vkGetAndroidHardwareBufferPropertiesANDROID GetAndroidHardwareBufferPropertiesANDROID;', text)
text = re.sub(r'struct wsi_image_info\s*\{', 'struct wsi_image_info {\n   const struct AHardwareBuffer_Desc *ahardware_buffer_desc;', text)
text = re.sub(r'struct wsi_image\s*\{', 'struct wsi_image {\n   struct AHardwareBuffer *ahardware_buffer;', text)

with open("src/vulkan/wsi/wsi_common.h", "w") as f:
    f.write(text)
EOF
fi

# 5. Planos descriptivos Pkg-Config de factoría
printf "prefix=%s\nlibdir=%s\nincludedir=%s/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -L\${libdir} -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$BASE_PWD/build_drm" "$BASE_PWD" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source/opt -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: glslang\nVersion: 14.0.0\nLibs: -L$BASE_PWD/glslang_source/build_64/glslang -lglslang\nCflags: -I$BASE_PWD/glslang_source\n" > local_pkgconfig/glslang.pc
printf "prefix=%s\nexec_prefix=\${prefix}\nlibdir=%s\nincludedir=\${prefix}/local_include\npkgconfig_libdir=\${libdir}\n\nName: libclc\nDescription: Library Compiler for OpenCL bytecode\nVersion: 18.0.0\nLibs: -L\${libdir} -lclc\nCflags: -I\${includedir}\n" "$BASE_PWD" "$NDK_LIB_DIR_64" > local_pkgconfig/libclc.pc

# 6. Inyección preventiva de la librería de pantalla libdrm
if [ -f "$BASE_PWD/build_drm/libdrm.so" ]; then
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_64/libdrm.so"
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_32/libdrm.so"
fi

# 7. Duplicación estática de las librerías de Qualcomm y libclc para el bloque de 32 bits hermano
cp -f "$NDK_LIB_DIR_64/libadrenotools.a" "$NDK_LIB_DIR_32/libadrenotools.a" 2>/dev/null || true
cp -f "$NDK_LIB_DIR_64/libclc.a" "$NDK_LIB_DIR_32/libclc.a" 2>/dev/null || true

# 8. Liberación de permisos de los validadores globales de Khronos
chmod +x "$BASE_PWD/glslang_source/build_64/StandAlone/glslangValidator" || true
chmod +x "$BASE_PWD/glslang_source/build_32/StandAlone/glslangValidator" || true

echo "=== ENTORNO ENLAZADOR TOTALMENTE SINCRO Y PARCHEADO ==="
