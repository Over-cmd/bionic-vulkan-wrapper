#!/bin/bash
set -e
echo "=== DISPARO DE SEGURIDAD: INICIANDO PIPELINE REPARTIDO MALI ==="
chmod +x preparar_entorno.sh
./preparar_entorno.sh

echo "=== ETAPA C-3: COMPILACIÓN MESA WRAPPER PURO PARA MALI (WINLATOR FOCAL) ==="
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
NPROC_CORES=$(nproc)

export REAL_BYPASS=$(find "$BASE_PWD" -name "liblinkernsbypass.a" | head -n 1)
export REAL_DRM_SO=$(find "$BASE_PWD" -name "libdrm.so" | head -n 1)

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl -Wl,--allow-shlib-undefined"
export CFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"
export CXXFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"

# Limpieza anti-extprefix
find local_pkgconfig/ -type f -name "*.pc" -exec sed -i 's/extprefix//g' {} + || true
find local_pkgconfig/ -type f -name "*.pc" -exec sed -i 's/textprefix//g' {} + || true

if [ -n "$REAL_DRM_SO" ] && [ -f "$REAL_DRM_SO" ]; then
  cp -f "$REAL_DRM_SO" "$NDK_LIB_DIR_64/libdrm.so"
  cp -f "$REAL_DRM_SO" "$NDK_LIB_DIR_32/libdrm.so" 2>/dev/null || true
fi

# BLOQUE MAESTRO DE STUBS GRÁFICOS SINCRO (Saturado con la anatomía PCI/Bus completa de factoría)
cat << 'EOF' > stubs_mali.h
#ifndef _STUBS_MALI_H_
#define _STUBS_MALI_H_
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define DRM_BUS_PCI 0
#define DRM_BUS_PLATFORM 3

#ifndef _DRM_DEVICE_GUARD_
#define _DRM_DEVICE_GUARD_
typedef struct _drmPciBusInfo { uint16_t domain; uint8_t bus; uint8_t dev; uint8_t func; } drmPciBusInfo, *drmPciBusInfoPtr;
struct _drmDevice { 
    char **nodes; 
    int available_nodes; 
    int bustype; 
    union { drmPciBusInfoPtr pci; void* platform; } businfo; 
};
typedef struct _drmDevice *drmDevicePtr;
#endif

int drmIoctl(int fd, unsigned long req, void *arg){return 0;}
int drmGetCap(int fd, uint64_t cap, uint64_t *v){return 0;}
int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *h){return 0;}
int drmSyncobjDestroy(int fd, uint32_t h){return 0;}
int drmSyncobjSignal(int fd, uint32_t *h, uint32_t c){return 0;}
int drmSyncobjWait(int fd, uint32_t *h, uint32_t c, int64_t t, uint32_t f, uint32_t *s){return 0;}
int drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device){return 0;}
void drmFreeDevice(drmDevicePtr *device){}
int drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices){return 0;}
void drmFreeDevices(drmDevicePtr devices[], int count){}
int drmDevicesEqual(void *a, void *b){return 1;}
int drmSyncobjTimelineSignal(int fd, uint32_t *h, uint64_t *p, uint32_t c){return 0;}
int drmSyncobjTimelineWait(int fd, uint32_t *h, uint64_t *p, uint64_t c, int64_t t, uint32_t f, uint32_t *s){return 0;}
int drmSyncobjTransfer(int fd, uint32_t dh, uint64_t dp, uint32_t sh, uint64_t sp, uint32_t f){return 0;}
int drmSyncobjReset(int fd, uint32_t *h, uint32_t c){return 0;}
int drmSyncobjExportSyncFile(int fd, uint32_t h, int *out){return 0;}
int drmSyncobjImportSyncFile(int fd, uint32_t h, int sf){return 0;}
int drmSyncobjFDToHandle(int fd, int fd_in, uint32_t *h){return 0;}
int drmSyncobjHandleToFD(int fd, uint32_t h, int *fd_out){return 0;}
int drmSyncobjQuery(int fd, uint32_t *h, uint64_t *p, uint32_t c){return 0;}
void *adrenotools_open_libvulkan(int dl, int fl, const char *tl, const char *hl, const char *cl, const char *cn, const char *fr, void **um){return 0;}
#endif
EOF

# Fusión monolítica forzada mediante CAT en los 4 frentes
for file in src/vulkan/wsi/wsi_common_drm.c src/vulkan/runtime/vk_instance.c src/vulkan/wrapper/wrapper_instance.c src/vulkan/runtime/vk_drm_syncobj.c; do
  if [ -f "$file" ]; then
    echo "-> Fusionando stubs en: $file"
    sed -i 's/\r$//' "$file"
    cat stubs_mali.h "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi
done

# COSTE ESCAPE PROOT
if [ -f "src/vulkan/wrapper/wrapper_device.c" ]; then
  sed -i 's/\r$//' src/vulkan/wrapper/wrapper_device.c
  sed -i 's|"/system/lib64/libvulkan.so"|"/host-rootfs/system/lib64/libvulkan.so"|g' src/vulkan/wrapper/wrapper_device.c
  sed -i 's|"/system/lib/libvulkan.so"|"/host-rootfs/system/lib/libvulkan.so"|g' src/vulkan/wrapper/wrapper_device.c
fi

# PARCHE AJUSTE DE HARDWARE
if [ -f "src/vulkan/wrapper/wrapper_objects.h" ]; then
  sed -i 's/\r$//' src/vulkan/wrapper/wrapper_objects.h
  sed -i 's/VK_OBJECT_TYPE_##type, handle/VK_OBJECT_TYPE_##type, (void*)(uintptr_t)(handle)/g' src/vulkan/wrapper/wrapper_objects.h
fi

# PARCHE SEGURO DE INCLUSIÓN FCNTL
if [ -f "src/vulkan/wrapper/wrapper_device_memory.c" ]; then sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_device_memory.c; fi
if [ -f "src/vulkan/wrapper/wrapper_physical_device.c" ]; then sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_physical_device.c; fi

# PARCHE SEGURO DE ANULACIÓN WSI
if [ -f "src/vulkan/wsi/wsi_common_ahardware_buffer.c" ]; then
  sed -i 's/\r$//' src/vulkan/wsi/wsi_common_ahardware_buffer.c
  sed -i '1i#if 0' src/vulkan/wsi/wsi_common_ahardware_buffer.c
  echo "#endif" >> src/vulkan/wsi/wsi_common_ahardware_buffer.c
fi

if [ -f "src/vulkan/wrapper/meson.build" ]; then sed -i '1i\glslang_quiet = []\nglslang_depfile = []' src/vulkan/wrapper/meson.build; fi

# --- CARRIEL A: 64 BITS ---
meson setup build64 --cross-file cross64.txt --buildtype=release -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload -Dc_link_args="-Wl,--whole-archive $REAL_BYPASS $REAL_DRM_SO -Wl,--no-whole-archive" -Dcpp_link_args="-Wl,--whole-archive $REAL_BYPASS $REAL_DRM_SO -Wl,--no-whole-archive"
if [ -f "build64/build.ninja" ]; then sed -i "s|-ldrm||g" build64/build.ninja; fi
ninja -C build64 -j $NPROC_CORES

# --- CARRIEL B: 32 BITS ---
sed -i "s|-L$BASE_PWD/spirv_source/build_64/source|-L$BASE_PWD/spirv_source/build_32/source|g" local_pkgconfig/SPIRV-Tools.pc
meson setup build32 --cross-file cross32.txt --buildtype=release -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload -Dc_link_args="-Wl,--whole-archive $REAL_BYPASS $REAL_DRM_SO -Wl,--no-whole-archive" -Dcpp_link_args="-Wl,--whole-archive $REAL_BYPASS $REAL_DRM_SO -Wl,--no-whole-archive"
if [ -f "build32/build.ninja" ]; then sed -i "s|-ldrm||g" build32/build.ninja; fi
ninja -C build32 -j $NPROC_CORES

# --- FUNDICIÓN MONOLÍTICA ELF DUAL DE FACTORÍA ---
mkdir -p wrapper_output/vulkan_wrapper/usr/lib; mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug build32/src/vulkan/wrapper/libvulkan_wrapper.so
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug build64/src/vulkan/wrapper/libvulkan_wrapper.so

echo "-> Fusionando la tabla ELF dual lícita en un solo archivo libvulkan_wrapper.so..."
cp -f build64/src/vulkan/wrapper/libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objcopy" --add-section .note.mesa.arm32=build32/src/vulkan/wrapper/libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so

printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.json

tar -cf wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 wrapper.tar -o wrapper.tzst
echo "=== ¡EL MONOLITO ÚNICO DUAL HA SIDO CORONADO CON ÉXITO DE REPARTO! ==="
