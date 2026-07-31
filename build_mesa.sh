#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA 24 COMPLETA ORIGINAL DE FACTORÍA (64 Y 32 BITS) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
NPROC_CORES=$(nproc)

# RASTREADOR INMUTABLE: Localizamos de forma dinamica las rutas fisicas de Pipetto en tu repositorio
REAL_ADRENO=$(find "$BASE_PWD" -name "libadrenotools.a" | head -n 1)
REAL_BYPASS=$(find "$BASE_PWD" -name "liblinkernsbypass.a" | head -n 1)

echo "-> [64 BITS] Adrenotools detectado en: $REAL_ADRENO"
echo "-> [64 BITS] LinkerBypass detectado en: $REAL_BYPASS"

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

# RESTAURACIÓN TOTAL DEL CHASIS GANADOR: Volvemos a las variables cortas originales que hacian pasar el setup limpio
export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl"
export CFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"
export CXXFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"

# INYECCIÓN ATÓMICA EN EL SYSROOT DEL SISTEMA: Copiamos libdrm.so directo al NDK
if [ -f "$BASE_PWD/build_drm/libdrm.so" ]; then
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_64/libdrm.so"
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_32/libdrm.so" 2>/dev/null || true
fi

# La purificacion de planos WSI de Meson
if [ -f "src/vulkan/wsi/meson.build" ]; then
  echo "-> Purificando planos de construccion de Meson WSI..."
  sed -i 's/\r$//' src/vulkan/wsi/meson.build
  sed -i "s/files('wsi_common_ahardware_buffer.c'),/# files('wsi_common_ahardware_buffer.c'),/g" src/vulkan/wsi/meson.build
fi

# Inyección dinámica de variables de shaders en Mesa 24 para disolver la línea 143/144
if [ -f "src/vulkan/wrapper/meson.build" ]; then
  sed -i 's/\r$//' src/vulkan/wrapper/meson.build
  sed -i '1i\glslang_quiet = []\nglslang_depfile = []' src/vulkan/wrapper/meson.build
fi

# --- CARRIEL A: 64 BITS ---
meson setup build64 --cross-file cross64.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload

echo "/* Neutralizado */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c
if [ -f "src/vulkan/wrapper/wrapper_device_memory.c" ]; then
  sed -i 's/\r$//'; sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_device_memory.c
fi
if [ -f "src/vulkan/wrapper/wrapper_physical_device.c" ]; then
  sed -i 's/\r$//'; sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_physical_device.c
fi

# LA JUGADA MAESTRA DE REPLANTACIÓN 64 BITS: Python abre el ninja generado y reescribe la linea final de enlazado soldando las librerias locales y libdrm de forma exacta sin importar espacios o comas
python3 - << 'EOF'
import os
filepath = "build64/build.ninja"
if os.path.exists(filepath):
    with open(filepath, "r") as f: content = f.read()
    # Localizamos el comando soname del wrapper y le clavamos las inyecciones fisicas locales al linker
    if "-Wl,-soname,libvulkan_wrapper.so" in content:
        adreno = os.environ.get('REAL_ADRENO', '')
        bypass = os.environ.get('REAL_BYPASS', '')
        drm_path = os.environ.get('BASE_PWD', '') + "/build_drm"
        injection = f"-Wl,-soname,libvulkan_wrapper.so -L{drm_path} -ldrm -Wl,--whole-archive {adreno} {bypass} -Wl,--no-whole-archive"
        content = content.replace("-Wl,-soname,libvulkan_wrapper.so", injection)
        with open(filepath, "w") as f: f.write(content)
        print("-> [64 BITS] ¡Soldadura de Pipetto e inyeccion DRM completada en build.ninja con éxito!")
EOF

ninja -C build64 -j $NPROC_CORES

# --- CARRIEL B: 32 BITS ---
export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26 -lc -llog -landroid -ldl"

sed -i "s|-L$BASE_PWD/spirv_source/build_64/source|-L$BASE_PWD/spirv_source/build_32/source|g" local_pkgconfig/SPIRV-Tools.pc
sed -i "s|-L$BASE_PWD/spirv_source/build_64/source/opt|-L$BASE_PWD/spirv_source/build_32/source/opt|g" local_pkgconfig/SPIRV-Tools-opt.pc
sed -i "s|-L$BASE_PWD/glslang_source/build_64/glslang|-L$BASE_PWD/glslang_source/build_32/glslang|g" local_pkgconfig/glslang.pc
sed -i "s|$NDK_LIB_DIR_64|$NDK_LIB_DIR_32|g" local_pkgconfig/libclc.pc

meson setup build32 --cross-file cross32.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload

echo "/* Neutralizado */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c

# LA JUGADA MAESTRA DE REPLANTACIÓN 32 BITS
python3 - << 'EOF'
import os
filepath = "build32/build.ninja"
if os.path.exists(filepath):
    with open(filepath, "r") as f: content = f.read()
    if "-Wl,-soname,libvulkan_wrapper.so" in content:
        adreno = os.environ.get('REAL_ADRENO', '')
        drm_path = os.environ.get('BASE_PWD', '') + "/build_drm"
        injection = f"-Wl,-soname,libvulkan_wrapper.so -L{drm_path} -ldrm -Wl,--whole-archive {adreno} -Wl,--no-whole-archive"
        content = content.replace("-Wl,-soname,libvulkan_wrapper.so", injection)
        with open(filepath, "w") as f: f.write(content)
        print("-> [32 BITS] ¡Soldadura de Pipetto e inyeccion DRM completada en build.ninja con éxito!")
EOF

ninja -C build32 -j $NPROC_CORES

# --- FUNDICIÓN MAESTRA UNIFICADA ---
mkdir -p wrapper_output/vulkan_wrapper/usr/lib; mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug build32/src/vulkan/wrapper/libvulkan_wrapper.so
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug build64/src/vulkan/wrapper/libvulkan_wrapper.so
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-lipo" -create build32/src/vulkan/wrapper/libvulkan_wrapper.so build64/src/vulkan/wrapper/libvulkan_wrapper.so -output wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.aarch64.json
tar -cf ../wrapper.tar -C wrapper_output vulkan_wrapper; zstd -19 ../wrapper.tar -o ../wrapper.tzst
echo "¡Tu Fat Binary unificado de factoría completa real ha sido coronado con éxito total!"
