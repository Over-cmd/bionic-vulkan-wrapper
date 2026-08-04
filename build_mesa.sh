#!/bin/bash
set -e
echo "=== ETAPA FINAL: COMPILACIÓN DEL INTERCEPTOR DUAL UNIFICADO (WINLATOR MALI) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

mkdir -p src_wrapper

# =========================================================================
# 1. GENERAMOS EL INTERCEPTOR DE 32 BITS (El "Pasajero")
# =========================================================================
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
EOF

echo "-> Compilando el núcleo puro de 32 bits..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang -shared -fPIC -O3 \
    src_wrapper/wrapper_32.c -o libvulkan_internal_32.so -ldl
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all libvulkan_internal_32.so

# Convertimos el binario de 32 bits en una matriz de bytes en C (un archivo de cabecera .h)
echo "-> Convirtiendo el binario de 32 bits a un array binario en C..."
xxd -i libvulkan_internal_32.so > src_wrapper/blob_32.h

# =========================================================================
# 2. GENERAMOS EL INTERCEPTOR MAESTRO DE 64 BITS (El "Anfitrión")
# =========================================================================
cat << 'EOF' > src_wrapper/wrapper_master.c
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/stat.h>
#include "blob_32.h" // Importamos los bytes del binario de 32 bits aquí dentro

void* (*real_vk_init_64)(void*, const char*) = NULL;
void* handle_32_runtime = NULL;
void* (*real_vk_init_32_runtime)(void*, const char*) = NULL;

__attribute__((visibility("default"))) void* vk_icdGetInstanceProcAddr(void* instance, const char* pName) {
    
    // DETECCIÓN DINÁMICA DE ARQUITECTURA EN TIEMPO DE EJECUCIÓN
    if (sizeof(void*) == 8) {
        // === RUTA DE JUEGOS DE 64 BITS ===
        if (!real_vk_init_64) {
            void* handle = dlopen("/system/lib64/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
            if (!handle) handle = dlopen("/vendor/lib64/hw/vulkan.mali.so", RTLD_NOW | RTLD_GLOBAL);
            if (!handle) handle = dlopen("/host-rootfs/system/lib64/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
            if (!handle) handle = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_GLOBAL);
            
            if (handle) real_vk_init_64 = (void* (*)(void*, const char*))dlsym(handle, "vk_icdGetInstanceProcAddr");
        }
        return real_vk_init_64 ? real_vk_init_64(instance, pName) : NULL;
    } 
    else {
        // === RUTA DE JUEGOS DE 32 BITS (Desempaquetado dinámico en memoria/disco temporal) ===
        if (!real_vk_init_32_runtime) {
            const char* temp_path = "/tmp/libvulkan_extracted_32.so";
            
            // Si el archivo no ha sido extraído todavía en esta sesión, lo escribimos en /tmp
            if (access(temp_path, F_OK) != 0) {
                FILE* f = fopen(temp_path, "wb");
                if (f) {
                    fwrite(libvulkan_internal_32_so, 1, libvulkan_internal_32_so_len, f);
                    fclose(f);
                    chmod(temp_path, 0755); // Le otorgamos permisos de ejecución
                }
            }
            
            // Cargamos dinámicamente nuestro propio binario de 32 bits extraído
            handle_32_runtime = dlopen(temp_path, RTLD_NOW | RTLD_GLOBAL);
            if (handle_32_runtime) {
                real_vk_init_32_runtime = (void* (*)(void*, const char*))dlsym(handle_32_runtime, "vk_icdGetInstanceProcAddr");
            }
        }
        return real_vk_init_32_runtime ? real_vk_init_32_runtime(instance, pName) : NULL;
    }
}
EOF

# =========================================================================
# 3. COMPILACIÓN DE LA ESTRUCTURA HÍBRIDA FINAL
# =========================================================================
echo "-> Forjando el único libvulkan_wrapper.so híbrido (Fat Wrapper)..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang -shared -fPIC -O3 \
    -Isrc_wrapper src_wrapper/wrapper_master.c -o libvulkan_wrapper.so -ldl

$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all libvulkan_wrapper.so

# =========================================================================
# 4. ARMADO DEL PAQUETE PARA WINLATOR
# =========================================================================
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

cp -f libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so

printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.json

tar -cf wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 --rm wrapper.tar -o wrapper.tzst

rm -rf libvulkan_internal_32.so src_wrapper/blob_32.h
echo "=== ¡EL INTERCEPTOR FAT ÚNICO (32/64 BITS) HA SIDO CORONADO CON ÉXITO! ==="
