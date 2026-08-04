#!/bin/bash
set -e
echo "=== ETAPA FINAL: SOLDADURA WOW64 EN CALIENTE (HOST) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BUILD_DIR="compilacion"

mkdir -p src_wrapper_winlator

# 1. Forjamos el chasis ligero de 32 bits
cat << 'EOF' > src_wrapper_winlator/wrapper_32.c
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
void* (*real_vk_init_32)(void*, const char*) = NULL;
__attribute__((visibility("default"))) void* vk_icdGetInstanceProcAddr(void* instance, const char* pName) {
    if (!real_vk_init_32) {
        void* handle = dlopen("/system/lib/libvulkan.so", RTLD_NOW | RTLD_GLOBAL);
        if (!handle) handle = dlopen("/vendor/lib/hw/vulkan.mali.so", RTLD_NOW | RTLD_GLOBAL);
        if (handle) real_vk_init_32 = (void* (*)(void*, const char*))dlsym(handle, "vk_icdGetInstanceProcAddr");
    }
    return real_vk_init_32 ? real_vk_init_32(instance, pName) : NULL;
}
__attribute__((visibility("default"))) void* vkGetInstanceProcAddr(void* instance, const char* pName) { return vk_icdGetInstanceProcAddr(instance, pName); }
__attribute__((visibility("default"))) int vulkanInit(void) { return 0; }
__attribute__((visibility("default"))) int vkCreateInstance(const void* pCreateInfo, const void* pAllocator, void* pInstance) { return 0; }
__attribute__((visibility("default"))) void vkDestroyInstance(void* instance, const void* pAllocator) {}
EOF

# 2. Compilamos e indexamos con el NDK del servidor
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang -shared -fPIC -O3 \
    src_wrapper_winlator/wrapper_32.c -o "$BUILD_DIR/libvulkan_internal_32.so" -ldl
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all "$BUILD_DIR/libvulkan_internal_32.so"

xxd -i "$BUILD_DIR/libvulkan_internal_32.so" > src_wrapper_winlator/blob_32.h

# 3. Forjamos el interceptor Fat-Binary Proxy de Winlator
cat << 'EOF' > src_wrapper_winlator/winlator_fat_bridge.c
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include "blob_32.h"

void* handle_32_extracted = NULL;
void* (*real_vk_init_32)(void*, const char*) = NULL;

__attribute__((visibility("default"))) void* vk_icdGetInstanceProcAddr(void* instance, const char* pName) {
    if (sizeof(void*) != 8) {
        const char* temp_path = "/tmp/libvulkan_extracted_32.so";
        if (access(temp_path, F_OK) != 0) {
            FILE* f = fopen(temp_path, "wb");
            if (f) {
                fwrite(compilacion_libvulkan_internal_32_so, 1, compilacion_libvulkan_internal_32_so_len, f);
                fclose(f);
                chmod(temp_path, 0755);
            }
        }
        if (!real_vk_init_32) {
            handle_32_extracted = dlopen(temp_path, RTLD_NOW | RTLD_GLOBAL);
            if (handle_32_extracted) real_vk_init_32 = dlsym(handle_32_extracted, "vk_icdGetInstanceProcAddr");
        }
        return real_vk_init_32 ? real_vk_init_32(instance, pName) : NULL;
    }
    return NULL;
}
EOF

# 4. Buscamos el binario de 64 bits resultante del Docker y fusionamos
REAL_BYPASS=$(find . -name "liblinkernsbypass.a" | head -n 1)
TARGET_SO=$(find "$BUILD_DIR" -name "libvulkan_wrapper.so" | head -n 1)

$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang -shared -fPIC -O3 \
    -Isrc_wrapper_winlator src_wrapper_winlator/winlator_fat_bridge.c "$TARGET_SO" \
    -o "$BUILD_DIR/libvulkan_wrapper_fat.so" -ldl

cp -f "$BUILD_DIR/libvulkan_wrapper_fat.so" "$BUILD_DIR/libvulkan_wrapper.so.unstripped"
mv -f "$BUILD_DIR/libvulkan_wrapper_fat.so" "$BUILD_DIR/libvulkan_wrapper.so"
$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all "$BUILD_DIR/libvulkan_wrapper.so"

# 5. Armamos el empaquetado ICD Khronos reglamentario para Pipetto
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d
cp -f "$BUILD_DIR/libvulkan_wrapper.so" wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "./libvulkan_wrapper.so",\n        "api_version": "1.3.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.json

tar -cf wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 --rm wrapper.tar -o "$BUILD_DIR/wrapper.tzst"
echo "=== ¡EL PAQUETE MONOLÍTICO HA SIDO CONSTRUIDO CON ÉXITO! ==="
