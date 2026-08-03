#!/bin/bash
set -e
echo "=== ETAPA FINAL: COMPILACIÓN DEL INTERCEPTOR DUAL CON BYPASS PROOT PARA MALI ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

# 1. Creamos el código fuente del Wrapper lícito de la scene (Puente directo con escape PRoot)
# Mapeamos las rutas cruzando el muro /host-rootfs para que Winlator vea tu chip Mali real
mkdir -p src_wrapper
cat << 'EOF' > src_wrapper/wrapper.c
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// Definimos el puntero maestro con los 2 argumentos exactos de la API de Vulkan
void* (*real_vk_init)(void*, const char*) = NULL;

__attribute__((visibility("default"))) void* vk_icdGetInstanceProcAddr(void* instance, const char* pName) {
    if (!real_vk_init) {
        void* handle = NULL;
        
        // COMPUERTA 1: Pasillo a través del mapa de montaje real de PRoot / Winlator Bionic
        handle = dlopen("/host-rootfs/system/lib64/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        if (!handle) {
            handle = dlopen("/host-rootfs/system/lib/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        }
        if (!handle) {
            handle = dlopen("/host-rootfs/vendor/lib64/hw/vulkan.mali.so", RTLD_NOW | RTLD_GLOBAL);
        }
        
        // COMPUERTA 2: Rastreador alternativo de factoría local
        if (!handle) {
            handle = dlopen("libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        }
        if (!handle) {
            handle = dlopen("/system/lib64/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        }
        if (!handle) {
            handle = dlopen("/system/lib/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        }
        
        if (handle) {
            real_vk_init = (void* (*)(void*, const char*))dlsym(handle, "vk_icdGetInstanceProcAddr");
        }
    }
    if (real_vk_init) {
        return real_vk_init(instance, pName);
    }
    return NULL;
}
EOF

# 2. Compilamos el carril de 64 bits de forma directa y limpia sin pasar por Meson
echo "-> Forjando el carril de 64 bits para Winlator..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang -shared -fPIC -O3 \
    -target aarch64-linux-android26 \
    src_wrapper/wrapper.c -o libvulkan_wrapper_64.so -ldl -llog

# 3. Compilamos el carril de 32 bits de forma directa y limpia sin pasar por Meson
echo "-> Forjando el carril de 32 bits para juegos clásicos..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/clang -shared -fPIC -O3 \
    -target armv7a-linux-androideabi26 \
    src_wrapper/wrapper.c -o libvulkan_wrapper_32.so -ldl -llog

# 4. Despojamos los símbolos de depuración oficiales con el motor de LLVM
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-debug libvulkan_wrapper_64.so
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-debug libvulkan_wrapper_32.so

# 5. FUNDICIÓN MONOLÍTICA REGLAMENTARIA (1 único archivo físico por inyección de bytes cat)
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

echo "-> Fusionando los carriles simétricos en un único libvulkan_wrapper.so monolítico..."
cat libvulkan_wrapper_64.so libvulkan_wrapper_32.so > wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so

# Generamos el manifiesto ICD JSON lícito que lee tu Winlator Ludashi Bionic
printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.aarch64.json

# Empaquetamos la obra definitiva en el plano local de la Action para Artifacts
tar -cf wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 wrapper.tar -o wrapper.tzst

echo "=== ¡EL INTERCEPTOR LÍCITO REAL DUAL PARA GPU MALI HA SIDO CORONADO CON ÉXITO! ==="
