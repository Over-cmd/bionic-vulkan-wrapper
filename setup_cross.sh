#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_64="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"

# Escritura vertical del cross-file oficial de Pipetto para compilación unificada
cat << EOF > /tmp/cross.txt
[binaries]
c='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
glslangValidator='/usr/bin/glslangValidator'
[properties]
sys_root='${SYSROOT_MAESTRO}'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default', '-D__ANDROID_VNDK__', '-D_FILE_OFFSET_BITS=64']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default', '-D__ANDROID_VNDK__', '-D_FILE_OFFSET_BITS=64']
c_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-Wl,--no-as-needed', '-Wl,--allow-shlib-undefined', '-L${LIB_64}']
cpp_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-Wl,--no-as-needed', '-Wl,--allow-shlib-undefined', '-L${LIB_64}', '-stdlib=libc++']
[host_machine]
system='linux'
cpu_family='aarch64'
cpu='armv8-a'
endian='little'
EOF
