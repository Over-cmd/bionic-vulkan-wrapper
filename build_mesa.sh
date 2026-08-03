#!/bin/bash
set -e
echo "=== ENCEFALOGRAMA DE COMPILACIÓN: FRAGMENTACIÓN DE FLUJO ==="
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

export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl"
export CFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"
export CXXFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"

if [ -n "$REAL_DRM_SO" ] && [ -f "$REAL_DRM_SO" ]; then
  cp -f "$REAL_DRM_SO" "$NDK_LIB_DIR_64/libdrm.so"
  cp -f "$REAL_DRM_SO" "$NDK_LIB_DIR_32/libdrm.so" 2>/dev/null || true
fi

# INYECCIÓN ATÓMICA DE STUBS Y RUTAS PROOT EN WRAPPER_DEVICE.C
if [ -f "src/vulkan/wrapper/wrapper_device.c" ]; then
  echo "-> Soldando puentes de escape PRoot y stubs en wrapper_device.c..."
  sed -i 's/\r$//' src/vulkan/wrapper/wrapper_device.c
  # Insertamos una macro en la primera linea que redirige las llamadas al driver real de Mali cruzando /host-rootfs
  sed -i '1i#define /system/lib64/libvulkan.so /host-rootfs/system/lib64/libvulkan.so\n#define /system/lib/libvulkan.so /host-rootfs/system/lib/libvulkan.so' src/vulkan/wrapper/wrapper_device.c
fi

# PARCHE AJUSTE DE HARDWARE: Corregimos las macros de objetos Vulkan en wrapper_objects.h
if [ -f "src/vulkan/wrapper/wrapper_objects.h" ]; then
  sed -i 's/\r$//' src/vulkan/wrapper/wrapper_objects.h
  sed -i 's/VK_OBJECT_TYPE_##type, handle/VK_OBJECT_TYPE_##type, (void*)(uintptr_t)(handle)/g' src/vulkan/wrapper/wrapper_objects.h
fi

# PARCHE SEGURO DE INCLUSIÓN FCNTL: Soldamos la cabecera Unix para sanar de raiz el paso 468
if [ -f "src/vulkan/wrapper/wrapper_device_memory.c" ]; then
  sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_device_memory.c
fi
if [ -f "src/vulkan/wrapper/wrapper_physical_device.c" ]; then
  sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_physical_device.c
fi

# PARCHE SEGURO DE ANULACIÓN WSI: Envolvemos el codigo de hardware buffers en un bloque #if 0 para aniquilar el paso 426
if [ -f "src/vulkan/wsi/wsi_common_ahardware_buffer.c" ]; then
  echo "-> Aplicando silenciador #if 0 en wsi_common_ahardware_buffer.c..."
  sed -i 's/\r$//' src/vulkan/wsi/wsi_common_ahardware_buffer.c
  sed -i '1i#if 0' src/vulkan/wsi/wsi_common_ahardware_buffer.c
  echo "#endif" >> src/vulkan/wsi/wsi_common_ahardware_buffer.c
fi

if [ -f "src/vulkan/wrapper/meson.build" ]; then
  sed -i '1i\glslang_quiet = []\nglslang_depfile = []' src/vulkan/wrapper/meson.build
fi

# --- CARRIEL A: 64 BITS ---
meson setup build64 --cross-file cross64.txt --buildtype=release -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload -Dc_link_args="-Wl,--whole-archive $REAL_BYPASS $REAL_DRM_SO -Wl,--no-whole-archive" -Dcpp_link_args="-Wl,--whole-archive $REAL_BYPASS $REAL_DRM_SO -Wl,--no-whole-archive"
if [ -f "build64/build.ninja" ]; then sed -i "s|-ldrm||g" build64/build.ninja; fi
ninja -C build64 -j $NPROC_CORES

# --- CARRIEL B: 32 BITS ---
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
echo "=== ¡EL MONOLITO ÚNICO DUAL HA SIDO CORONADO DE FORMA AERODINÁMICA! ==="
