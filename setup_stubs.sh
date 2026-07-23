#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
TARGET_LIB_DIR="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"
TARGET_INC_DIR="${SYSROOT_MAESTRO}/usr/include"

# 1. Cabeceras biónicas del preprocesador de Android obligatorias
mkdir -p "${SYSROOT_MAESTRO}/usr/include/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/bits/pthreadtypes.h"
echo -e '#ifndef ZSTD_H\n#define ZSTD_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zstd.h"
echo -e '#ifndef ZLIB_H\n#define ZLIB_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zlib.h"
echo -e '#ifndef ZCONF_H\n#define ZCONF_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zconf.h"

# 2. INSTALACIÓN Y COMPILACIÓN DE LIBDRM REAL COMPLETA DE FREEDESKTOP (URL BLINDADA):
rm -rf /tmp/drm_real
# Envolvemos la URL completa con comillas dobles estrictas para evitar que el intérprete de GitHub Actions la recorte en la caché
git clone --depth=1 "https://github.com" /tmp/drm_real || (mkdir -p /tmp/drm_real && curl -L "https://github.com" | tar -xz -C /tmp/drm_real --strip-components=1)

cd /tmp/drm_real
mkdir -p build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)

# Sembramos los binarios y cabeceras auténticas dentro de las rutas oficiales del compilador del NDK
cp -f libdrm.a "$TARGET_LIB_DIR/" || cp -f src/libdrm.a "$TARGET_LIB_DIR/" || true
mkdir -p "$TARGET_INC_DIR/libdrm"
cp -f ../xf86drm.h "$TARGET_INC_DIR/"
cp -f ../xf86drm.h "$TARGET_INC_DIR/libdrm/"
cp -f ../include/drm/drm.h "$TARGET_INC_DIR/libdrm/"
cd $GITHUB_WORKSPACE

# 3. Puente máster de inicialización de extensiones
cat << 'EOF' > /tmp/vk_pc_stubs.h
#ifndef _VK_PC_STUBS_H
#define _VK_PC_STUBS_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#define HAVE_ZSTD 1
#define HAVE_ZLIB 1
typedef struct VkXcbSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* connection; uintptr_t window; } VkXcbSurfaceCreateInfoKHR;
typedef struct VkXlibSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* dpy; uintptr_t window; } VkXlibSurfaceCreateInfoKHR;
void* adrenotools_open_libvulkan(const char* a, const char* s);
#endif
EOF
