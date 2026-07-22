#!/bin/bash
set -e

INC="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"

# 1. bits/pthreadtypes.h obligatorio para wsi_common.c
mkdir -p "$INC/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "$INC/bits/pthreadtypes.h"

# 2. Interceptor global fake-pkg-config
sudo cat << 'EOF' > /usr/local/bin/fake-pkg-config
#!/bin/bash
if [[ "$*" == *"--modversion"* ]]; then echo '"14.0.0"'; else echo "-I${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"; fi
exit 0
EOF
sudo chmod +x /usr/local/bin/fake-pkg-config

# 3. Creación del entorno cruzado forzando el peso masivo por enlazado estático total
cat << EOF > /tmp/cross_64.txt
[binaries]
c='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config='/usr/local/bin/fake-pkg-config'
glslangValidator='/usr/bin/glslangValidator'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
c_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-Wl,--whole-archive', '-lSPIRV-Tools', '-Wl,--no-whole-archive']
cpp_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-Wl,--whole-archive', '-lSPIRV-Tools', '-Wl,--no-whole-archive']
[host_machine]
system='linux'
cpu_family='aarch64'
cpu='armv8-a'
endian='little'
EOF
