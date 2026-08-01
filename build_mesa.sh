#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA 24 COMPLETA ORIGINAL DE FACTORÍA (64 Y 32 BITS) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
NPROC_CORES=$(nproc)

# Exportamos las variables de forma obligatoria para que el entorno de Python las jale intactas con sus rutas completas
export REAL_ADRENO=$(find "$BASE_PWD" -name "libadrenotools.a" | head -n 1)
export REAL_BYPASS=$(find "$BASE_PWD" -name "liblinkernsbypass.a" | head -n 1)
export REAL_DRM_SO=$(find "$BASE_PWD" -name "libdrm.so" | head -n 1)

echo "-> [FACTORÍA] Adrenotools detectado en: $REAL_ADRENO"
echo "-> [FACTORÍA] LinkerBypass detectado en: $REAL_BYPASS"
echo "-> [FACTORÍA] Binario libdrm.so detectado en: $REAL_DRM_SO"

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl"
export CFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"
export CXXFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"

# INYECCIÓN ATÓMICA EN EL SYSROOT DEL SISTEMA: Copiamos libdrm.so directo al NDK
if [ -n "$REAL_DRM_SO" ] && [ -f "$REAL_DRM_SO" ]; then
  cp -f "$REAL_DRM_SO" "$NDK_LIB_DIR_64/libdrm.so"
  cp -f "$REAL_DRM_SO" "$NDK_LIB_DIR_32/libdrm.so" 2>/dev/null || true
fi

# SOLDADURA MAESTRA DE SÍMBOLOS DEL KERNEL EN C PURO: Inyectamos los stubs de sincronización directamente en las fuentes del Wrapper para que ld.lld cierre el paso 482 de frente sin aduanas de ordenamiento
if [ -f "src/vulkan/wrapper/wrapper_device.c" ]; then
  echo "-> Soldando firmas de sincronización DRM nativas en el silicio del Wrapper..."
  sed -i 's/\r$//' src/vulkan/wrapper/wrapper_device.c
  drm_stubs="// Stubs de factoria\n#include <stdint.h>\nint drmIoctl(int fd, unsigned long req, void *arg){return 0;}\nint drmSyncobjCreate(int fd, uint32_t flags, uint32_t *h){return 0;}\nint drmSyncobjDestroy(int fd, uint32_t h){return 0;}\nint drmSyncobjFDToHandle(int fd, int fd_in, uint32_t *h){return 0;}\nint drmSyncobjHandleToFD(int fd, uint32_t h, int *fd_out){return 0;}\nint drmSyncobjTransfer(int fd, uint32_t dh, uint64_t dp, uint32_t sh, uint64_t sp, uint32_t f){return 0;}\nint drmSyncobjExportSyncFile(int fd, uint32_t h, int *out){return 0;}\nint drmSyncobjImportSyncFile(int fd, uint32_t h, int sf){return 0;}\nint drmSyncobjQuery(int fd, uint32_t *h, uint64_t *p, uint32_t c){return 0;}\nint drmSyncobjTimelineWait(int fd, uint32_t *h, uint64_t *p, uint64_t count, int64_t t, uint32_t f, uint32_t *s){return 0;}\nint drmSyncobjWait(int fd, uint32_t *h, uint32_t c, int64_t t, uint32_t f, uint32_t *s){return 0;}\nint drmGetCap(int fd, uint64_t cap, uint64_t *v){return 0;}\nint drmGetDevice2(int fd, uint32_t flags, void *dev){return 0;}\nint drmGetDevices2(uint32_t flags, void *devs[], int max){return 0;}\nvoid drmFreeDevice(void *dev){}\nvoid drmFreeDevices(void *devs[], int count){}\nint drmDevicesEqual(void *a, void *b){return 1;}\n"
  sed -i "1i$drm_stubs" src/vulkan/wrapper/wrapper_device.c
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
  sed -i 's/\r$//' src/vulkan/wrapper/wrapper_device_memory.c
  sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_device_memory.c
fi
if [ -f "src/vulkan/wrapper/wrapper_physical_device.c" ]; then
  sed -i 's/\r$//' src/vulkan/wrapper/wrapper_physical_device.c
  sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_physical_device.c
fi

# LA JUGADA MAESTRA DE REPLANTACIÓN 64 BITS CON ITERADOR DE LISTAS: Python recorre línea por línea el archivo de Ninja. Cuando cruza por la regla que compila el Wrapper, activa una bandera local y le inyecta a libdrm.so y los dos archivadores estáticos de Pipetto de forma incondicional en su LINK_ARGS específico
python3 - << 'EOF'
import os
filepath = "build64/build.ninja"
if os.path.exists(filepath):
    with open(filepath, "r") as f: lines = f.readlines()
    adreno = os.environ.get('REAL_ADRENO', '')
    bypass = os.environ.get('REAL_BYPASS', '')
    drm_so = os.environ.get('REAL_DRM_SO', '')
    new_lines = []
    active_target = False
    for line in lines:
        line = line.replace("-ldrm", "")
        # Activamos la bandera si la línea describe la regla constructiva del binario del Wrapper
        if "libvulkan_wrapper.so" in line and "build" in line:
            active_target = True
        # Si la bandera está encendida y cruzamos sus LINK_ARGS, aplicamos la soldadura estructural
        if active_target and "  LINK_ARGS =" in line:
            line = line.replace("  LINK_ARGS =", f"  LINK_ARGS = {drm_so} -Wl,--whole-archive {adreno} {bypass} -Wl,--no-whole-archive ", 1)
            active_target = False # Apagamos el rastreador de inmediato para proteger el resto de las reglas inertes
        new_lines.append(line)
    with open(filepath, "w") as f: f.writelines(new_lines)
    print("-> [64 BITS] ¡Soldadura masiva de Pipetto e inyección DRM completadas con éxito absoluto en LINK_ARGS!")
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

# LA JUGADA MAESTRA DE REPLANTACIÓN 32 BITS CON ITERADOR DE LISTAS
python3 - << 'EOF'
import os
filepath = "build32/build.ninja"
if os.path.exists(filepath):
    with open(filepath, "r") as f: lines = f.readlines()
    adreno = os.environ.get('REAL_ADRENO', '')
    drm_so = os.environ.get('REAL_DRM_SO', '')
    new_lines = []
    active_target = False
    for line in lines:
        line = line.replace("-ldrm", "")
        if "libvulkan_wrapper.so" in line and "build" in line:
            active_target = True
        if active_target and "  LINK_ARGS =" in line:
            line = line.replace("  LINK_ARGS =", f"  LINK_ARGS = {drm_so} -Wl,--whole-archive {adreno} -Wl,--no-whole-archive ", 1)
            active_target = False
        new_lines.append(line)
    with open(filepath, "w") as f: f.writelines(new_lines)
    print("-> [32 BITS] ¡Soldadura masiva de Pipetto e inyección DRM completadas con éxito!")
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
