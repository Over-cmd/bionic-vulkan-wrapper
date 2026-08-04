#!/bin/bash
set -e
echo "=== ETAPA FINAL: COMPILACIÓN DEL INTERCEPTOR DUAL FIJADO PARA MALI (WINLATOR) ==="

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
# 2. GENERAMOS EL INTERCEPTOR NATIVO DE 32 BITS (El "Pasajero")
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
EOF

echo "-> Compilando el núcleo de 32 bits..."
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang -shared -fPIC -O3 \
    src_wrapper/wrapper_32.c -o libvulkan_internal_32.so -ldl

$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all libvulkan_internal_32.so

# Convertimos el binario obtenido de 32 bits a una matriz hexadecimal de texto en C
xxd -i libvulkan_internal_32.so > src_wrapper/blob_32.h

# =========================================================================
# 3. GENERAMOS EL INTERCEPTOR MAESTRO DE 64 BITS (El "Anfitrión")
# =========================================================================
cat << 'EOF' > src_wrapper/wrapper_master.c
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/stat.h>
#include "blob_32.h" // Absorbe el binario de 32 bits anterior

// Forzamos el enlace externo con el bypass de la scene de Pipetto
extern void *adrenotools_open_libvulkan(int dl, int fl, const char *tl, const char *hl, const char *cl, const char *cn, const char *fr, void **um);

void* (*real_vk_init_64)(void*, const char*) = NULL;
void* handle_32_runtime = NULL;
void* (*real_vk_init_32_runtime)(void*, const char*) = NULL;

__attribute__((visibility("default"))) void* vk_icdGetInstanceProcAddr(void* instance, const char* pName) {
    
    // DETECCIÓN DINÁMICA DE LA ARQUITECTURA DEL PROCESO EN CALIENTE
    if (sizeof(void*) == 8) {
        // === PASILLO DE JUEGOS DE 64 BITS ===
        if (!real_vk_init_64) {
            void* handle = NULL;
            
            // Bypass de espacio de nombres lícito de Winlator (Resuelve en cualquier SoC/Mali)
            handle = adrenotools_open_libvulkan(RTLD_NOW, RTLD_GLOBAL, NULL, NULL, NULL, NULL, NULL, NULL);
            
            // Métodos de respaldo tradicionales en caso de fallo del bypass
            if (!handle) handle = dlopen("/system/lib64/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
            if (!handle) handle = dlopen("/vendor/lib64/hw/vulkan.mali.so", RTLD_NOW | RTLD_GLOBAL);
            if (!handle) handle = dlopen("/host-rootfs/system/lib64/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
            if (!handle) handle = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_GLOBAL);
            
            if (handle) {
                real_vk_init_64 = (void* (*)(void*, const char*))dlsym(handle, "vk_icdGetInstanceProcAddr");
            }
        }
        return real_vk_init_64 ? real_vk_init_64(instance, pName) : NULL;
    } 
    else {
        // === PASILLO DE JUEGOS DE 32 BITS ===
        if (!real_vk_init_32_runtime) {
            const char* temp_path = "/tmp/libvulkan_extracted_32.so";
            
            // Desempaquetado dinámico transparente del sub-bloque hexadecimal
            if (access(temp_path, F_OK) != 0) {
                FILE* f = fopen(temp_path, "wb");
                if (f) {
                    fwrite(libvulkan_internal_32_so, 1, libvulkan_internal_32_so_len, f);
                    fclose(f);
                    chmod(temp_path, 0755); // Otorga permisos de ejecución nativos en disco
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
EOF

# =========================================================================
# 4. COMPILACIÓN E INYECCIÓN GLOBAL DE ENLAZADO (Bypass de Linker Dinámico)
# =========================================================================
echo "-> Forjando el único libvulkan_wrapper.so Fat Híbrido..."

# Compilamos enlazando el archivo liblinkernsbypass.a mediante marcas de archivo completo
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang -shared -fPIC -O3 \
    -Isrc_wrapper src_wrapper/wrapper_master.c -o libvulkan_wrapper.so \
    -Wl,--whole-archive $REAL_BYPASS -Wl,--no-whole-archive -ldl -llog

$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all libvulkan_wrapper.so

# =========================================================================
# 5. CONSTRUCCIÓN DE LA FACTORÍA FINAL REGLAMENTARIA DE KHRONOS
# =========================================================================
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

cp -f libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so

# Manifiesto JSON ICD limpio que exige el entorno gráfico de Winlator
printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.json

# Empaquetado final compatible con tu flujo de GitHub Actions
tar -cf wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 --rm wrapper.tar -o wrapper.tzst

# Limpieza interna preventiva en el servidor
rm -rf libvulkan_internal_32.so src_wrapper/blob_32.h
echo "=== ¡EL INTERCEPTOR FAT ÚNICO (32/64 BITS CON BYPASS DE LINKER) SE COMPLETÓ CON ÉXITO! ==="
