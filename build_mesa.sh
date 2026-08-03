#!/bin/bash
set -e
echo "=== ETAPA FINAL: COMPILACIÓN DEL INTERCEPTOR DUAL MONOLÍTICO PARA WINLATOR ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

# 1. Creamos el código fuente del Wrapper lícito de la scene (Bypass PRoot + Focal)
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
        
        // RUTA 1: Mapeo de escape a través de las compuertas de PRoot en Winlator Ludashi
        handle = dlopen("/host-rootfs/system/lib64/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        if (!handle) {
            handle = dlopen("/host-rootfs/system/lib/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        }
        if (!handle) {
            handle = dlopen("/host-rootfs/vendor/lib64/hw/vulkan.mali.so", RTLD_NOW | RTLD_GLOBAL);
        }
        if (!handle) {
            handle = dlopen("/host-rootfs/vendor/lib/hw/vulkan.mali.so", RTLD_NOW | RTLD_GLOBAL);
        }
        
        // RUTA 2: Rastreador alternativo local en el RootFS Focal Fossa
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

# 2. Compilamos el carril de 64 bits apuntando al estándar GNU que exige Focal Fossa
echo "-> Forjando el carril de 64 bits GNU para Winlator Focal..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/clang -shared -fPIC -O3 \
    -target aarch64-linux-gnu \
    src_wrapper/wrapper.c -o libvulkan_wrapper_64.so -ldl -llog 2>/dev/null || \
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang -shared -fPIC -O3 \
    src_wrapper/wrapper.c -o libvulkan_wrapper_64.so -ldl -llog

# 3. Compilamos el carril de 32 bits apuntando al estándar GNU que exige Focal Fossa
echo "-> Forjando el carril de 32 bits GNU para juegos clásicos..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/clang -shared -fPIC -O3 \
    -target arm-linux-gnueabi -march=armv7-a -mfpu=neon \
    src_wrapper/wrapper.c -o libvulkan_wrapper_32.so -ldl -llog 2>/dev/null || \
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/clang -shared -fPIC -O3 \
    -target armv7a-linux-androideabi26 \
    src_wrapper/wrapper.c -o libvulkan_wrapper_32.so -ldl -llog

# 4. Despojamos los símbolos de depuración oficiales con el motor de LLVM
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-debug libvulkan_wrapper_64.so
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-debug libvulkan_wrapper_32.so

# 5. FUNDICIÓN MONOLÍTICA UNIFICADA EN UN ÚNICO .SO MEDIANTE LLVM-AR
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

echo "-> Prensando ambas arquitecturas en un único libvulkan_wrapper.so unificado con llvm-ar..."
# Usamos llvm-ar del NDK para empaquetar de forma lícita ambos objetos ELF en un único archivo físico legible por Winlator
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar" rcs wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so libvulkan_wrapper_64.so libvulkan_wrapper_32.so

# Generamos el manifiesto ICD JSON oficial para el mapa de Winlator Ludashi
printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.json

# Empaquetamos la obra definitiva en el plano local de la Action para Artifacts
tar -cf wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 wrapper.tar -o wrapper.tzst

echo "=== ¡EL INTERCEPTOR ÚNICO MONOLÍTICO DUAL PARA GPU MALI HA SIDO CORONADO CON ÉXITO! ==="
