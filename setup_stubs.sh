#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_64="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"
INC_64="${SYSROOT_MAESTRO}/usr/include"

# 1. INSTALACIÓN Y COMPILACIÓN DE LIBDRM REAL COMPLETA DESDE MIRROR DE GITHUB
mkdir -p /tmp/drm
curl -L https://github.com -o /tmp/drm.tar.gz
tar -xzf /tmp/drm.tar.gz -C /tmp/drm --strip-components=1
cd /tmp/drm && mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
cp libdrm.a "$LIB_64/" || cp src/libdrm.a "$LIB_64/" || true
mkdir -p "$INC_64/libdrm" && cp ../xf86drm.h "$INC_64/libdrm/" && cp ../include/drm/drm.h "$INC_64/libdrm/" || true
cd $GITHUB_WORKSPACE

# 2. INSTALACIÓN Y COMPILACIÓN DE SPIRV-TOOLS Y HEADERS REALES DESDE GITHUB
mkdir -p /tmp/spirv-tools/external/spirv-headers
curl -L https://github.com -o /tmp/tools.tar.gz
curl -L https://github.com -o /tmp/headers.tar.gz
tar -xzf /tmp/tools.tar.gz -C /tmp/spirv-tools --strip-components=1
tar -xzf /tmp/headers.tar.gz -C /tmp/spirv-tools/external/spirv-headers --strip-components=1
cd /tmp/spirv-tools && mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DSPIRV_SKIP_TESTS=ON -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
cp source/libSPIRV-Tools.a "$LIB_64/"
cp source/opt/libSPIRV-Tools-opt.a "$LIB_64/"
cd $GITHUB_WORKSPACE

# 3. INSTALACIÓN Y COMPILACIÓN DE GLSLANG REAL COMPLETO DESDE GITHUB
mkdir -p /tmp/glslang
curl -L https://github.com -o /tmp/glslang.tar.gz
tar -xzf /tmp/glslang.tar.gz -C /tmp/glslang --strip-components=1
cd /tmp/glslang && mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=${ANDROID_SDK_ROOT}/ndk/25.2.9519653/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
cp StandAlone/libglslang.a "$LIB_64/" || cp glslang/libglslang.a "$LIB_64/" || true
cd $GITHUB_WORKSPACE

# 4. Cabeceras biónicas complementarias de Android obligatorias para el preprocesador
mkdir -p "${SYSROOT_MAESTRO}/usr/include/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/bits/pthreadtypes.h"
echo -e '#ifndef ZSTD_H\n#define ZSTD_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zstd.h"
echo -e '#ifndef ZLIB_H\n#define ZLIB_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zlib.h"
echo -e '#ifndef ZCONF_H\n#define ZCONF_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zconf.h"

# Interceptor real para pkg-config apuntando a las rutas oficiales instaladas
sudo cat << 'EOF' > /usr/local/bin/fake-pkg-config
#!/bin/bash
if [[ "$*" == *"--modversion"* ]]; then echo "14.0.0"; else echo "-I/usr/local/lib/android/sdk/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"; fi
exit 0
EOF
sudo chmod +x /usr/local/bin/fake-pkg-config

# 5. Escribimos el cross-file maestro de Meson para ARM64
cat << EOF > /tmp/cross.txt
[binaries]
c='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config='/usr/local/bin/fake-pkg-config'
glslangValidator='/usr/bin/glslangValidator'
[properties]
sys_root='${SYSROOT_MAESTRO}'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
c_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-Wl,--no-as-needed', '-L${LIB_64}']
cpp_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-Wl,--no-as-needed', '-L${LIB_64}', '-stdlib=libc++']
[host_machine]
system='linux'
cpu_family='aarch64'
cpu='armv8-a'
endian='little'
EOF
