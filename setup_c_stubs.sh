#!/bin/bash
set -e

INC="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"

# 1. bits/pthreadtypes.h obligatorio para wsi_common.c
mkdir -p "$INC/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "$INC/bits/pthreadtypes.h"
echo -e '#ifndef ZSTD_H\n#define ZSTD_H\n#endif' > "$INC/zstd.h"
echo -e '#ifndef ZLIB_H\n#define ZLIB_H\n#endif' > "$INC/zlib.h"
echo -e '#ifndef ZCONF_H\n#define ZCONF_H\n#endif' > "$INC/zconf.h"

# 2. Esqueleto base para simular las funciones de PC locales sin tocar código de Leegao
cat << 'EOF' > /tmp/vk_pc_stubs.h
#ifndef _VK_PC_STUBS_H
#define _VK_PC_STUBS_H
#include <stdint.h>
#include <stddef.h>
int open(const char *pathname, int flags, ...);
typedef struct VkXcbSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* connection; uintptr_t window; } VkXcbSurfaceCreateInfoKHR;
typedef struct VkXlibSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* dpy; uintptr_t window; } VkXlibSurfaceCreateInfoKHR;
#endif
EOF
