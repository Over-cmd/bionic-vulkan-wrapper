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

# COPIADO QUIRÚRGICO EN EL SYSROOT REAL: Registramos las librerías estáticas originales en el pasillo biónico del NDK r25c
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_SYSROOT_LIB="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android"

cp spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a "$NDK_LIB_DIR_64/libSPIRV-Tools-opt.a"
cp spirv_source/build_64/source/libSPIRV-Tools.a "$NDK_LIB_DIR_64/libSPIRV-Tools.a"
cp spirv_source/build_64/source/opt/libSPIRV-Tools-opt.a "$NDK_SYSROOT_LIB/libSPIRV-Tools-opt.a"
cp spirv_source/build_64/source/libSPIRV-Tools.a "$NDK_SYSROOT_LIB/libSPIRV-Tools.a"

mkdir -p local_pkgconfig

echo "=== 2. Generando descriptores de control .pc ==="
printf "prefix=%s\nlibdir=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$NDK_PATH" > local_pkgconfig/libdrm.pc
printf "prefix=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr\nlibdir=\${prefix}/lib\nincludedir=\${prefix}/include\nlibexecdir=\${prefix}/libexec\n\nName: libclc\nDescription: OpenCL C library stub for Android\nVersion: 0.2.0\nLibs:\nCflags: -I\${includedir}\n" "$NDK_PATH" > local_pkgconfig/libclc.pc
printf "Name: SPIRV-Tools\nDescription: SPIRV Tools\nVersion: 2024.1\nLibs: -lSPIRV-Tools\nCflags:\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nDescription: SPIRV Tools Opt\nVersion: 2024.1\nLibs: -lSPIRV-Tools-opt\nCflags:\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: LLVMSPIRVLib\nDescription: LLVM SPIR-V Translator Library\nVersion: 18.1.0\nLibs: -lLLVMSPIRVLib\nCflags:\n" > local_pkgconfig/LLVMSPIRVLib.pc

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

echo "=== 3. Configurando COMPILACIÓN DE MESA: 64 BITS MONOLÍTICO ==="
# SOLUCIÓN CRÍTICA: Inyectamos '--sysroot' directamente en las opciones 'c_args', 'cpp_args', 'c_link_args' y 'cpp_link_args'
# Esto blinda a Clang++ dándole el mapa físico obligatorio del NDK r25c para superar la validación de la línea 4
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

printf "[binaries]\nc = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'\nar = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = 'pkg-config'\nllvm-config = '/usr/bin/llvm-config'\n[built-in options]\nc_args = ['--sysroot=%s', '-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-include', '%s/local_include/xf86drm.h', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000', '-Wno-error=format', '-Wno-format']\ncpp_args = ['--sysroot=%s', '-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000', '-Wno-error=format', '-Wno-format']\nc_link_args = ['--sysroot=%s', '-L%s', '-Wl,--no-gc-sections', '-Wl,--no-as-needed', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc']\ncpp_link_args = ['--sysroot=%s', '-L%s', '-Wl,--no-gc-sections', '-Wl,--no-as-needed', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-Wl,--no-whole-archive', '-lc']\n[properties]\nlib_dirs = ['%s', '%s']\n[host_machine]\nsystem = 'android'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$SYSROOT_PATH" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$SYSROOT_PATH" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$SYSROOT_PATH" "$NDK_LIB_DIR_64" "$SYSROOT_PATH" "$NDK_LIB_DIR_64" "$NDK_LIB_DIR_64" "$NDK_LIB_DIR_64" > arm64_cross.txt

# Limpiamos las variables globales de terminal para dejar el entorno 100% puro bajo el archivo de configuración cruzada
export LDFLAGS="-Wl,--no-fatal-warnings"
export CXXFLAGS=""
export CFLAGS=""

meson setup build64 --cross-file arm64_cross.txt --buildtype=release -Doptimization=3 -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers= --wrap-mode=nodownload
ninja -C build64

echo "=== 4. EMPAQUETADO BRUTO DIRECTO PARA STEVEN MXZ ==="
mkdir -p "$BASE_PWD/wrapper_output"
cp -L "$BASE_PWD/build64/src/vulkan/wrapper/libvulkan_wrapper.so" "$BASE_PWD/wrapper_output/libvulkan_wrapper.so"

echo "Verificando el tamaño bruto real del driver de leegao:"
ls -lh "$BASE_PWD/wrapper_output/libvulkan_wrapper.so"

tar -cf "$BASE_PWD/wrapper.tar" -C "$BASE_PWD/wrapper_output" libvulkan_wrapper.so
zstd -19 "$BASE_PWD/wrapper.tar" -o "$BASE_PWD/wrapper.tzst"
echo "Empaquetado monolítico puro finalizado con éxito."
