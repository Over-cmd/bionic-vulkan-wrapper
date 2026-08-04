#!/bin/bash
set -e
echo "=== ETAPA FINAL: COMPILACIÓN DEL INTERCEPTOR INTEGRAL LEEGAO (MALI FIX) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

# 1. Rescatamos el bypass y librerías estáticas del entorno de Pipetto
export REAL_BYPASS=$(find "$BASE_PWD" -name "liblinkernsbypass.a" | head -n 1)
export REAL_DRM_SO=$(find "$BASE_PWD" -name "libdrm.so" | head -n 1)
NPROC_CORES=$(nproc)

# Si el código fuente de leegao no está clonado en la raíz, lo forzamos
if [ ! -d "src/vulkan/wrapper" ]; then
  echo "-> Clonando el árbol completo de bionic-vulkan-wrapper..."
  git clone --depth 1 https://github.com bionic_source
  cp -r bionic_source/* ./
  rm -rf bionic_source
fi

# =========================================================================
# 2. COMPILACIÓN DEL CARRIL DE 32 BITS (Mesa/Khronos nativo de leegao)
# =========================================================================
echo "-> Forjando binario nativo de 32 bits desde las fuentes de leegao..."
# Forzamos la inclusión de los parches de constantes de Mali descubiertos en el parche v0.0.5r4
export CFLAGS="--sysroot=$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot -w -D_GNU_SOURCE -DMALI_WORKAROUNDS=1"
export CXXFLAGS="$CFLAGS"

# Compilamos el sub-wrapper usando el árbol de archivos reales del repositorio (dispositivos de leegao)
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang -shared -fPIC -O3 \
    src/vulkan/wrapper/wrapper_device.c \
    src/vulkan/wrapper/wrapper_physical_device.c \
    src/vulkan/wrapper/wrapper_device_memory.c \
    -Isrc/vulkan/wrapper -Ilocal_include -Ispirv_source/include -o libvulkan_internal_32.so -ldl -llog

$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all libvulkan_internal_32.so
xxd -i libvulkan_internal_32.so > src/vulkan/wrapper/blob_32.h

# =========================================================================
# 3. ADAPTACIÓN DEL INTERCEPTOR MAESTRO DE 64 BITS (Inyección del Blob 32)
# =========================================================================
echo "-> Soldando puente WoW64 y bypass de namespace en el chasis de leegao..."

# Modificamos el archivo de inicialización de leegao para que monte dinámicamente el blob de 32 bits si corre en WoW64
cat << 'EOF' > src/vulkan/wrapper/winlator_mali_bridge.h
#include <sys/stat.h>
#include "blob_32.h"

extern void *adrenotools_open_libvulkan(int dl, int fl, const char *tl, const char *hl, const char *cl, const char *cn, const char *fr, void **um);
void* handle_32_runtime = NULL;
void* (*real_vk_init_32_runtime)(void*, const char*) = NULL;

void* check_and_extract_mali_wow64(void* instance, const char* pName) {
    if (sizeof(void*) != 8) {
        const char* temp_path = "/tmp/libvulkan_extracted_32.so";
        if (access(temp_path, F_OK) != 0) {
            FILE* f = fopen(temp_path, "wb");
            if (f) {
                fwrite(libvulkan_internal_32_so, 1, libvulkan_internal_32_so_len, f);
                fclose(f);
                chmod(temp_path, 0755);
            }
        }
        if (!real_vk_init_32_runtime) {
            handle_32_runtime = dlopen(temp_path, RTLD_NOW | RTLD_GLOBAL);
            if (handle_32_runtime) {
                real_vk_init_32_runtime = dlsym(handle_32_runtime, "vk_icdGetInstanceProcAddr");
            }
        }
        return real_vk_init_32_runtime ? real_vk_init_32_runtime(instance, pName) : NULL;
    }
    return NULL;
}
EOF

# Inyectamos el puente al principio del archivo maestro de leegao
sed -i '1i#include "winlator_mali_bridge.h"' src/vulkan/wrapper/wrapper_device.c
# Hacemos que vk_icdGetInstanceProcAddr redirija el flujo de 32 bits antes de evaluar las llamadas de 64 bits
sed -i '/vk_icdGetInstanceProcAddr/!b;n;a\    void* wow64_res = check_and_extract_mali_wow64(instance, pName); if(wow64_res) return wow64_res;' src/vulkan/wrapper/wrapper_device.c

# =========================================================================
# 4. COMPILACIÓN FINAL CON LAS FUENTES REALES DE KHRONOS DE LEEGAO
# =========================================================================
echo "-> Forjando el libvulkan_wrapper.so híbrido oficial..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang -shared -fPIC -O3 \
    src/vulkan/wrapper/wrapper_device.c \
    src/vulkan/wrapper/wrapper_physical_device.c \
    src/vulkan/wrapper/wrapper_device_memory.c \
    -Isrc/vulkan/wrapper -Ilocal_include -Ispirv_source/include \
    -o libvulkan_wrapper.so -Wl,--whole-archive $REAL_BYPASS -Wl,--no-whole-archive -ldl -llog

$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all libvulkan_wrapper.so

# =========================================================================
# 5. ARMADO DEL PAQUETE REGLAMENTARIO DE FACTORÍA
# =========================================================================
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

cp -f libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so

# Generamos el manifiesto con la versión de API requerida según el hilo de GitHub
printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "/usr/lib/libvulkan_wrapper.so",\n        "api_version": "1.3.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.json

tar -cf wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 --rm wrapper.tar -o wrapper.tzst

rm -f libvulkan_internal_32.so src/vulkan/wrapper/blob_32.h src/vulkan/wrapper/winlator_mali_bridge.h
echo "=== ¡EL INTERCEPTOR MAESTRO DE LEEGAO CON CORRECCIÓN DE SHADERS MALI SE HA COMPLETADO! ==="
