#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. PRE-COMPILANDO SPIRV-TOOLS REAL DE LEEGAO ==="
mkdir -p spirv_source/build_64
cd spirv_source/build_64
cmake .. -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release \
  -DSPIRV_SKIP_TESTS=ON \
  -DSPIRV_WERROR=OFF
ninja
cd ../..

# COPIADO EN EL SYSROOT REAL
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_SYSROOT_LIB="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android"

cp spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_64/libSPIRV-Tools-opt.a"
cp spirv_source/build_64/source/libSPIRV-Tools.a "$NDK_LIB_DIR_64/libSPIRV-Tools.a"
cp spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a "$NDK_SYSROOT_LIB/libSPIRV-Tools-opt.a"
cp spirv_source/build_64/source/libSPIRV-Tools.a "$NDK_SYSROOT_LIB/libSPIRV-Tools.a"

mkdir -p local_pkgconfig

echo "=== 2. Generando descriptores de control .pc ==="
printf "prefix=%s\nlibdir=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$NDK_PATH" > local_pkgconfig/libdrm.pc
printf "prefix=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr\nlibdir=\textprefix}/lib\nincludedir=\${prefix}/include\nlibexecdir=\${prefix}/libexec\n\nName: libclc\nDescription: OpenCL C library stub for Android\nVersion: 0.2.0\nLibs:\nCflags: -I\${includedir}\n" "$NDK_PATH" > local_pkgconfig/libclc.pc
printf "Name: SPIRV-Tools\nDescription: SPIRV Tools\nVersion: 2024.1\nLibs: -lSPIRV-Tools\nCflags:\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nDescription: SPIRV Tools Opt\nVersion: 2024.1\nLibs: -lSPIRV-Tools-opt\nCflags:\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: LLVMSPIRVLib\nDescription: LLVM SPIR-V Translator Library\nVersion: 18.1.0\nLibs: -lLLVMSPIRVLib\nCflags:\n" > local_pkgconfig/LLVMSPIRVLib.pc

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

echo "=== 3. Creando mapa de símbolos públicos obligatorios para Winlator ==="
cat << 'EOF' > exports.map
{
  global:
    vk_icdNegotiateLoaderICDInterfaceVersion;
    vkGetInstanceProcAddr;
    vkGetDeviceProcAddr;
    vk_icdGetInstanceProcAddr;
    vk_icdGetPhysicalDeviceProcAddr;
    vkEnumerateInstanceExtensionProperties;
    vkEnumerateInstanceLayerProperties;
    vkCreateInstance;
    __android_log_print;
    __android_log_vprint;
    __android_log_write;
    AHardwareBuffer_allocate;
    AHardwareBuffer_release;
    AHardwareBuffer_describe;
    AHardwareBuffer_lock;
    AHardwareBuffer_unlock;
    atrace_get_enabled_tags;
    atrace_begin_body;
    atrace_end_body;
    atrace_init;
    sync_merge;
    property_get;
    hw_get_module;
  local: *;
};
EOF

echo "=== 4. Configurando COMPILACIÓN DE MESA: EL ENCHUFE DE CONEXIÓN ==="
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# EL ENCHUFE FINAL: Inyectamos '-ldl' de forma física en c_link_args y cpp_link_args para reactivar el cargador dinámico interno del wrapper
cat << EOF > arm64_cross.txt
[binaries]
c = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '/bin/true'
pkg-config = 'pkg-config'
llvm-config = '/usr/bin/llvm-config'

[built-in options]
c_args = ['--sysroot=$SYSROOT_PATH', '-DHAVE_ANDROID_PLATFORM', '-DANDROID_API_LEVEL=26', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/local_include/bits', '-include', '$BASE_PWD/local_include/xf86drm.h', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000', '-Wno-error=format', '-Wno-format']
cpp_args = ['--sysroot=$SYSROOT_PATH', '-DHAVE_ANDROID_PLATFORM', '-DANDROID_API_LEVEL=26', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/local_include/bits', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000', '-Wno-error=format', '-Wno-format']
c_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--no-gc-sections', '-Wl,--no-as-needed', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl', '-Wl,--version-script=$BASE_PWD/exports.map']
cpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--no-gc-sections', '-Wl,--no-as-needed', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl', '-Wl,--version-script=$BASE_PWD/exports.map']

[properties]
lib_dirs = ['$NDK_LIB_DIR_64']

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF

unset LDFLAGS
unset CXXFLAGS
unset CFLAGS

meson setup build64 --cross-file arm64_cross.txt --buildtype=release -Doptimization=3 \
  -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false \
  -Dvulkan-drivers=wrapper -Dgallium-drivers= -Dgbm=disabled -Degl=disabled \
  -Dgles1=disabled -Dgles2=disabled -Dopengl=false -Dshared-glapi=disabled \
  -Dglx=disabled -Dllvm=disabled -Dvideo-codecs=[] --wrap-mode=nodownload
ninja -C build64

echo "=== 5. EMPAQUETADO BRUTO Y PURGA DE SÍMBOLOS MUERTOS ==="
mkdir -p "$BASE_PWD/wrapper_output"
cp -L "$BASE_PWD/build64/src/vulkan/wrapper/libvulkan_wrapper.so" "$BASE_PWD/wrapper_output/libvulkan_wrapper.so"

"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug "$BASE_PWD/wrapper_output/libvulkan_wrapper.so"

echo "Tamaño bruto real limpio definitivo para Winlator Steven MXZ:"
ls -lh "$BASE_PWD/wrapper_output/libvulkan_wrapper.so"

tar -cf "$BASE_PWD/wrapper.tar" -C "$BASE_PWD/wrapper_output" libvulkan_wrapper.so
zstd -19 "$BASE_PWD/wrapper.tar" -o "$BASE_PWD/wrapper.tzst"
echo "¡Driver empaquetado, conexión dlopen habilitada y Mali lista!"
