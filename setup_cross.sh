#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_64="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"

# 1. GENERACIÓN DE RECETAS .WRAP AUTÉNTICAS (Fuerza la descarga real de Shaders en subprojects/)
# Como los submódulos de Git de Leegao están caídos, Meson usará estas instrucciones para 
# descargar los archivos fuente verdaderos completos de Khronos Group de forma automática.
mkdir -p "$GITHUB_WORKSPACE/wrapper_src/subprojects"

cat << 'EOF' > "$GITHUB_WORKSPACE/wrapper_src/subprojects/spirv-tools.wrap"
[wrap-file]
directory = SPIRV-Tools-2024.1
source_url = https://github.com
source_filename = v2024.1.tar.gz
source_hash = 693a105f9c46d328c68aa2f89552b028da841029df4b0351336423a2a6b22b10
patch_directory = spirv-tools
EOF

cat << 'EOF' > "$GITHUB_WORKSPACE/wrapper_src/subprojects/spirv-headers.wrap"
[wrap-file]
directory = SPIRV-Headers-2024.1
source_url = https://github.com
source_filename = v2024.1-headers.tar.gz
source_hash = a2fb9e8b15d96200236e760bf0bfbaee49d5926c8bda32f91dfc1409f98a2872
EOF

# 2. Interceptor pkg-config plano
echo -e '#!/bin/bash\nif [[ "$*" == *"--modversion"* ]]; then echo "14.0.0"; else echo "-I/tmp"; fi\nexit 0' > /tmp/fake-pkg-config
chmod +x /tmp/fake-pkg-config

# 3. Escritura del archivo cruzado máster multiarquitectura
cat << EOF > /tmp/cross.txt
[binaries]
c='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config='/tmp/fake-pkg-config'
glslangValidator='/usr/bin/glslangValidator'
[properties]
sys_root='${SYSROOT_MAESTRO}'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default', '-D__ANDROID_VNDK__', '-D_FILE_OFFSET_BITS=64']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default', '-D__ANDROID_VNDK__', '-D_FILE_OFFSET_BITS=64']
c_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-Wl,--no-as-needed', '-L${LIB_64}']
cpp_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-Wl,--no-as-needed', '-L${LIB_64}', '-stdlib=libc++']
[host_machine]
system='linux'
cpu_family='aarch64'
cpu='armv8-a'
endian='little'
EOF
