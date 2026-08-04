#!/bin/bash
set -e
echo "=== ETAPA FINAL: COMPILACIÓN DEL INTERCEPTOR DUAL CON SÍMBOLOS KHRONOS ESTÁNDAR ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

# 1. Buscamos las dependencias críticas inyectadas por el entorno de Pipetto
export REAL_BYPASS=$(find "$BASE_PWD" -name "liblinkernsbypass.a" | head -n 1)
export REAL_DRM_SO=$(find "$BASE_PWD" -name "libdrm.so" | head -n 1)
NPROC_CORES=$(nproc)

# Guardamos las rutas de compilación cruzada
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"

# =========================================================================
# 2. GENERAMOS EL INTERCEPTOR NATIVO DE 32 BITS (Exportaciones completas)
# =========================================================================
mkdir -p src_wrapper
cat << 'EOF' > src_wrapper/wrapper_32.c
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>

void* (*real_vk_init_32)(void*, const char*) = NULL;

__attribute__((visibility("default"))) void* vk_icdGetInstanceProcAddr(void* instance, const char* pName) {
    if (!real_vk_init_32) {
        void* handle = dlopen("/system/lib/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        if (!handle) handle = dlopen("/vendor/lib/hw/vulkan.mali.so", RTLD_NOW | RTLD_GLOBAL);
        if (!handle) handle = dlopen("/host-rootfs/system/lib/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        if (!handle) handle = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_GLOBAL);
        
        if (handle) real_vk_init_32 = (void* (*)(void*, const char*))dlsym(handle, "vk_icdGetInstanceProcAddr");
    }
    return real_vk_init_32 ? real_vk_init_32(instance, pName) : NULL;
}

// Símbolos obligatorios de la especificación Khronos para evitar rechazos del cargador
__attribute__((visibility("default"))) void* vkGetInstanceProcAddr(void* instance, const char* pName) { return vk_icdGetInstanceProcAddr(instance, pName); }
__attribute__((visibility("default"))) int vkCreateInstance(const void* pCreateInfo, const void* pAllocator, void* pInstance) { return 0; }
__attribute__((visibility("default"))) void vkDestroyInstance(void* instance, const void* pAllocator) {}
EOF

echo "-> Compilando el núcleo de 32 bits..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang -shared -fPIC -O3 \
    src_wrapper/wrapper_32.c -o libvulkan_internal_32.so -ldl

$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all libvulkan_internal_32.so
xxd -i libvulkan_internal_32.so > src_wrapper/blob_32.h

# =========================================================================
# 3. GENERAMOS EL INTERCEPTOR MAESTRO DE 64 BITS (Exportaciones + Bypass)
# =========================================================================
cat << 'EOF' > src_wrapper/wrapper_master.c
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/stat.h>
#include "blob_32.h"

extern void *adrenotools_open_libvulkan(int dl, int fl, const char *tl, const char *hl, const char *cl, const char *cn, const char *fr, void **um);

void* (*real_vk_init_64)(void*, const char*) = NULL;
void* handle_32_runtime = NULL;
void* (*real_vk_init_32_runtime)(void*, const char*) = NULL;

__attribute__((visibility("default"))) void* vk_icdGetInstanceProcAddr(void* instance, const char* pName) {
    if (sizeof(void*) == 8) {
        if (!real_vk_init_64) {
            void* handle = NULL;
            handle = adrenotools_open_libvulkan(RTLD_NOW, RTLD_GLOBAL, NULL, NULL, NULL, NULL, NULL, NULL);
            
            if (!handle) handle = dlopen("/system/lib64/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
            if (!handle) handle = dlopen("/vendor/lib64/hw/vulkan.mali.so", RTLD_NOW | RTLD_GLOBAL);
            if (!handle) handle = dlopen("/host-rootfs/system/lib64/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
            if (!handle) handle = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_GLOBAL);
            
            if (handle) real_vk_init_64 = (void* (*)(void*, const char*))dlsym(handle, "vk_icdGetInstanceProcAddr");
        }
        return real_vk_init_64 ? real_vk_init_64(instance, pName) : NULL;
    } 
    else {
        if (!real_vk_init_32_runtime) {
            const char* temp_path = "/tmp/libvulkan_extracted_32.so";
            if (access(temp_path, F_OK) != 0) {
                FILE* f = fopen(temp_path, "wb");
                if (f) {
                    fwrite(libvulkan_internal_32_so, 1, libvulkan_internal_32_so_len, f);
                    fclose(f);
                    chmod(temp_path, 0755);
                }
            }
            handle_32_runtime = dlopen(temp_path, RTLD_NOW | RTLD_GLOBAL);
            if (handle_32_runtime) {
                real_vk_init_32_runtime = (void* (*)(void*, const char*))dlsym(handle_32_runtime, "vk_icdGetInstanceProcAddr");
            }
        }
        return real_vk_init_32_runtime ? real_vk_init_32_runtime(instance, pName) : NULL;
    }
}

// Espejos globales exigidos por la Khronos Loader Spec para no abortar el enlace dinámico
__attribute__((visibility("default"))) void* vkGetInstanceProcAddr(void* instance, const char* pName) { return vk_icdGetInstanceProcAddr(instance, pName); }
__attribute__((visibility("default"))) int vkCreateInstance(const void* pCreateInfo, const void* pAllocator, void* pInstance) { return 0; }
__attribute__((visibility("default"))) void vkDestroyInstance(void* instance, const void* pAllocator) {}
EOF

# =========================================================================
# 4. COMPILACIÓN DE LA PRENSA MONOLÍTICA
# =========================================================================
echo "-> Forjando libvulkan_wrapper.so con firmas Khronos puras..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang -shared -fPIC -O3 \
    -Isrc_wrapper src_wrapper/wrapper_master.c -o libvulkan_wrapper.so \
    -Wl,--whole-archive $REAL_BYPASS -Wl,--no-whole-archive -ldl -llog

$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all libvulkan_wrapper.so

# =========================================================================
# 5. ESTRUCTURA REGLAMENTARIA DE ENLACE FIJO (La clave del JSON)
# =========================================================================
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

cp -f libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so

# CORRECCIÓN EN EL JSON: Usamos la ruta absoluta interna exacta del rootfs de Winlator
printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "/usr/lib/libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.json

tar -cf wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 --rm wrapper.tar -o wrapper.tzst

rm -rf libvulkan_internal_32.so src_wrapper/blob_32.h
echo "=== ¡EL INTERCEPTOR CORREGIDO CON RUTAS ABSOLUTAS SE COMPLETÓ CON ÉXITO! ==="
