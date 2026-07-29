#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA 24 COMPLETA ORIGINAL DE FACTORÍA (64 Y 32 BITS) ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
NPROC_CORES=$(nproc)

# Amarramos las rutas descriptoras de Pkg-Config que calibramos
export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

# Sincronizamos las variables globales de entorno para que Clang localice libdl.so y tus stubs de inmediato en GitHub Actions
export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl"
export CFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"
export CXXFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"

# INYECCIÓN QUIRÚRGICA: Añadimos glslang_quiet y glslang_depfile vacías al inicio de src/vulkan/wrapper/meson.build para disolver el error de Mesa 24 de origen
if [ -f "src/vulkan/wrapper/meson.build" ]; then
  echo "-> Soldando variables de control de shaders ausentes en Mesa 24..."
  sed -i 's/\r$//' src/vulkan/wrapper/meson.build
  sed -i '1i\glslang_quiet = []\nglslang_depfile = []' src/vulkan/wrapper/meson.build
fi

# ==============================================================================
# --- BYPASS DE VULKAN RUNTIME: SOLDADURA DE CABECERAS EN LA RAÍZ DE INCLUSIÓN ---
# ==============================================================================
# Creamos la carpeta local_include de forma explícita y movemos los archivos .h de libdrm a la raíz absoluta del proyecto para que <xf86drm.h> sea visible de inmediato por Clang
mkdir -p "$BASE_PWD/local_include"
if [ -d "$BASE_PWD/local_include/libdrm" ]; then
  echo "-> Moviendo cabeceras xf86drm.h al pasillo de prioridad de Clang..."
  cp -f "$BASE_PWD/local_include/libdrm/"*.h "$BASE_PWD/local_include/" 2>/dev/null || true
fi

# Liberación de permisos de los validadores que fabricamos en la Etapa A
chmod +x "$BASE_PWD/glslang_source/build_64/StandAlone/glslangValidator" || true
chmod +x "$BASE_PWD/glslang_source/build_32/StandAlone/glslangValidator" || true

# Inyección preventiva de la librería de pantalla libdrm en ambos carriles del enlazador del NDK
if [ -f "$BASE_PWD/build_drm/libdrm.so" ]; then
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_64/libdrm.so"
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_32/libdrm.so"
fi

# Duplicación estática de las librerías de Qualcomm y libclc para el carril simétrico de 32 bits
cp -f "$NDK_LIB_DIR_64/libadrenotools.a" "$NDK_LIB_DIR_32/libadrenotools.a" 2>/dev/null || true
cp -f "$NDK_LIB_DIR_64/libclc.a" "$NDK_LIB_DIR_32/libclc.a" 2>/dev/null || true

# ==============================================================================
# --- CARRIEL A: 64 BITS (TODO DE FACTORÍA ACTIVO AL 100% IDÉNTICO A PIPETTO) ---
# ==============================================================================
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\nglslangValidator = '/usr/bin/glslangValidator'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-lglslang', '-lclc', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-lglslang', '-lclc', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\n[host_machine]\nsystem = 'android'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" > cross64.txt

meson setup build64 --cross-file cross64.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload -Dc_link_args="-L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl -lglslang -lclc" -Dcpp_link_args="-L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl -lglslang -lclc"

sed -i 's|-Wl,-soname,libvulkan_wrapper.so|-Wl,-soname,libvulkan_wrapper.so -Wl,--whole-archive '"$NDK_LIB_DIR_64"'/libadrenotools.a '"$NDK_LIB_DIR_64"'/liblinkernsbypass.a -Wl,--no-whole-archive|g' build64/build.ninja
ninja -C build64 -j $NPROC_CORES

# ==============================================================================
# --- CARRIEL B: 32 BITS (OPTIMIZACIÓN HARDWARE COMPLETA PARA PROCESADOR MALI) ---
# ==============================================================================
export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26 -lc -llog -landroid -ldl"
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\nglslangValidator = '/usr/bin/glslangValidator'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=hard', '-mfpu=neon']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=hard', '-mfpu=neon']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-lglslang', '-lclc', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-lglslang', '-lclc', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\n[host_machine]\nsystem = 'android'\ncpu_family = 'arm'\ncpu = 'armv7-a'\nendian = 'little'\n" > cross32.txt

sed -i "s|-L$BASE_PWD/spirv_source/build_64/source|-L$BASE_PWD/spirv_source/build_32/source|g" local_pkgconfig/SPIRV-Tools.pc
sed -i "s|-L$BASE_PWD/spirv_source/build_64/source/opt|-L$BASE_PWD/spirv_source/build_32/source/opt|g" local_pkgconfig/SPIRV-Tools-opt.pc
sed -i "s|-L$BASE_PWD/glslang_source/build_64/glslang|-L$BASE_PWD/glslang_source/build_32/glslang|g" local_pkgconfig/glslang.pc
sed -i "s|$NDK_LIB_DIR_64|$NDK_LIB_DIR_32|g" local_pkgconfig/libclc.pc

meson setup build32 --cross-file cross32.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload -Dc_link_args="-L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26" -Dcpp_link_args="-L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26"

sed -i 's|-Wl,-soname,libvulkan_wrapper.so|-Wl,-soname,libvulkan_wrapper.so -Wl,--whole-archive '"$NDK_LIB_DIR_32"'/libadrenotools.a -Wl,--no-whole-archive|g' build32/build.ninja
ninja -C build32 -j $NPROC_CORES

# --- PACKAGING PARA EMULADORES WINLATOR ---
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
mkdir -p wrapper_output/vulkan_wrapper/usr/lib64
mkdir -p wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d

cp -L build32/src/vulkan/wrapper/libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
cp -L build64/src/vulkan/wrapper/libvulkan_wrapper.so wrapper_output/vulkan_wrapper/usr/lib64/libvulkan_wrapper.so

"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug wrapper_output/vulkan_wrapper/usr/lib64/libvulkan_wrapper.so

printf '{\n    "file_format_version": "1.0.0",\n    "ICD": {\n        "library_path": "libvulkan_wrapper.so",\n        "api_version": "1.1.0"\n    }\n}\n' > wrapper_output/vulkan_wrapper/usr/share/vulkan/icd.d/icd_wrapper.aarch64.json

tar -cf ../wrapper.tar -C wrapper_output vulkan_wrapper
zstd -19 ../wrapper.tar -o ../wrapper.tzst
echo "¡Tu Fat Binary unificado simétrico de factoría completa para GPU Mali ha sido forjado con éxito total!"
