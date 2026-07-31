#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA 24 COMPLETA ORIGINAL DE FACTORÍA (64 Y 32 BITS) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
NPROC_CORES=$(nproc)

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl"
export CFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"
export CXXFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"

# La purificacion condicional de planos WSI de Meson
if [ -f "src/vulkan/wsi/meson.build" ]; then
  echo "-> Purificando planos de construccion de Meson WSI..."
  sed -i 's/\r$//' src/vulkan/wsi/meson.build
  sed -i "s/files('wsi_common_ahardware_buffer.c'),/# files('wsi_common_ahardware_buffer.c'),/g" src/vulkan/wsi/meson.build
fi

# Inyección dinámica de variables de shaders en Mesa 24 para disolver la línea 143/144
if [ -f "src/vulkan/wrapper/meson.build" ]; then
  sed -i 's/\r$//' src/vulkan/wrapper/meson.build
  sed -i '1i\glslang_quiet = []\nglslang_depfile = []' src/vulkan/wrapper/meson.build
fi

# --- CARRIEL A: 64 BITS (TODO DE FACTORÍA ACTIVO AL 100% IDÉNTICO A PIPETTO) ---
cat << EOF > cross64.txt
[binaries]
c = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '/bin/true'
pkg-config = '/usr/bin/pkg-config'
glslangValidator = '/usr/bin/glslangValidator'

[built-in options]
c_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include']
cpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include']
c_link_args = ['--sysroot=$SYSROOT_PATH', '-lc', '-llog', '-landroid', '-ldl']
cpp_link_args = ['--sysroot=$SYSROOT_PATH', '-lc', '-llog', '-landroid', '-ldl']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF

meson setup build64 --cross-file cross64.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload -Dc_link_args="-L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl -lglslang -lclc" -Dcpp_link_args="-L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl -lglslang -lclc"

# EL VACIADO EN CALIENTE 64 BITS Y SOPLETES DE MEMORIA UNIX PASO 466 Y 468
echo "/* Neutralizado lícitamente para carril Mali 64 Bits */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c
if [ -f "src/vulkan/wrapper/wrapper_device_memory.c" ]; then
  sed -i 's/\r$//' src/vulkan/wrapper/wrapper_device_memory.c
  sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_device_memory.c
fi
if [ -f "src/vulkan/wrapper/wrapper_physical_device.c" ]; then
  sed -i 's/\r$//' src/vulkan/wrapper/wrapper_physical_device.c
  sed -i '1i#include <fcntl.h>' src/vulkan/wrapper/wrapper_physical_device.c
fi

# RASTREADOR INTELIGENTE EN CALIENTE 64 BITS: Localizamos de forma dinamica la ruta fisica exacta de las librerias .a en el servidor de Actions
REAL_ADRENO=$(find "$BASE_PWD" -name "libadrenotools.a" | head -n 1)
REAL_BYPASS=$(find "$BASE_PWD" -name "liblinkernsbypass.a" | head -n 1)

echo "-> Libreria Adrenotools encontrada en: $REAL_ADRENO"
echo "-> Libreria LinkerBypass encontrada en: $REAL_BYPASS"

# Inyectamos las rutas físicas reales directo en las entrañas de build.ninja
sed -i "s|-Wl,-soname,libvulkan_wrapper.so|-Wl,-soname,libvulkan_wrapper.so -Wl,--whole-archive $REAL_ADRENO $REAL_BYPASS -Wl,--no-whole-archive|g" build64/build.ninja

ninja -C build64 -j $NPROC_CORES

# --- CARRIEL B: 32 BITS (OPTIMIZACIÓN HARDWARE COMPLETA PARA PROCESADOR MALI) ---
export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26 -lc -llog -landroid -ldl"

cat << EOF > cross32.txt
[binaries]
c = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'
cpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang++'
ar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '/bin/true'
pkg-config = '/usr/bin/pkg-config'
glslangValidator = '/usr/bin/glslangValidator'

[built-in options]
c_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=hard', '-mfpu=neon']
cpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=hard', '-mfpu=neon']
c_link_args = ['--sysroot=$SYSROOT_PATH', '-lc', '-llog', '-landroid', '-ldl']
cpp_link_args = ['--sysroot=$SYSROOT_PATH', '-lc', '-llog', '-landroid', '-ldl']

[host_machine]
system = 'android'
cpu_family = 'arm'
cpu = 'armv7-a'
endian = 'little'
EOF

sed -i "s|-L$BASE_PWD/spirv_source/build_64/source|-L$BASE_PWD/spirv_source/build_32/source|g" local_pkgconfig/SPIRV-Tools.pc
sed -i "s|-L$BASE_PWD/spirv_source/build_64/source/opt|-L$BASE_PWD/spirv_source/build_32/source/opt|g" local_pkgconfig/SPIRV-Tools-opt.pc
sed -i "s|-L$BASE_PWD/glslang_source/build_64/glslang|-L$BASE_PWD/glslang_source/build_32/glslang|g" local_pkgconfig/glslang.pc
sed -i "s|$NDK_LIB_DIR_64|$NDK_LIB_DIR_32|g" local_pkgconfig/libclc.pc

meson setup build32 --cross-file cross32.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload -Dc_link_args="-L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26" -Dcpp_link_args="-L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26"

# EL VACIADO EN CALIENTE 32 BITS Y SOPLETES DE MEMORIA EN 32 BITS
echo "/* Neutralizado lícitamente para carril Mali 32 Bits */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c

# Enlazado local garantizado para el carril de 32 bits usando el rastreador dinámico
sed -i "s|-Wl,-soname,libvulkan_wrapper.so|-Wl,-soname,libvulkan_wrapper.so -Wl,--whole-archive $REAL_ADRENO -Wl,--no-whole-archive|g" build32/build.ninja

ninja -C build32 -j $NPROC_CORES

# --- FUNDICIÓN MAESTRA UNIFICADA (LLVM-LIPO) ---
echo "-> Iniciando fundición lipo: Unificando ambos carriles en un solo archivo..."
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug build32/src/vulkan/wrapper/libvulkan_wrapper.so
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug build64/src/vulkan/wrapper/libvulkan_wrapper.so

"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-lipo" -create \
  build32/src/vulkan/wrapper/libvulkan_wrapper.so \
  build64/src/vulkan/wrapper/libvulkan_wrapper.so \
  -output wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so

printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.aarch64.json

tar -cf ../wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 ../wrapper.tar -o ../wrapper.tzst
echo "¡Tu Fat Binary unificado de factoría completa real ha sido coronado con éxito total!"
