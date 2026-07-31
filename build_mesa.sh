#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA 24 COMPLETA CON ESTRATEGIA FALSO TURNIP ==="

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

# Inyección dinámica de variables de shaders en Mesa 24 para disolver la línea 143/144
if [ -f "src/vulkan/wrapper/meson.build" ]; then
  sed -i 's/\r$//' src/vulkan/wrapper/meson.build
  sed -i '1i\glslang_quiet = []\nglslang_depfile = []' src/vulkan/wrapper/meson.build
fi

# --- CARRIEL A: 64 BITS (EL ENGAÑO DE TURNIP PARA DESBLOQUEAR ANDROID WSI) ---
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\nglslangValidator = '/usr/bin/glslangValidator'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-lglslang', '-lclc', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_64', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-lglslang', '-lclc', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\n[host_machine]\nsystem = 'android'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" > cross64.txt

meson setup build64 --cross-file cross64.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper,freedreno -Dgallium-drivers=freedreno -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload -Dc_link_args="-L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl -lglslang -lclc" -Dcpp_link_args="-L$NDK_LIB_DIR_64 -L$SYSROOT_PATH/usr/lib/aarch64-linux-android/26 -lc -llog -landroid -ldl -lglslang -lclc"

# PARCHEADOR RECURSIVO MESA 24: Buscamos y alteramos todas las copias de wsi_common.h (tanto en src/ como en build64/ y build32/) para forzar la presencia de las variables lícitas de Android
python3 - << 'EOF'
import os
for root, dirs, files in os.walk("."):
    for file in files:
        if file == "wsi_common.h":
            filepath = os.path.join(root, file)
            with open(filepath, "r") as f:
                content = f.read()
            if "struct wsi_device {" in content and "GetAndroidHardwareBufferPropertiesANDROID" not in content:
                content = content.replace("struct wsi_device {", "typedef struct { uint32_t width; uint32_t height; uint32_t layers; uint32_t format; uint64_t usage; uint32_t stride; uint32_t rfu0; uint64_t rfu1; } AHardwareBuffer_Desc;\nstruct wsi_device {\n   void *GetAndroidHardwareBufferPropertiesANDROID;")
                content = content.replace("struct wsi_image_info {", "struct wsi_image_info {\n   AHardwareBuffer_Desc *ahardware_buffer_desc;")
                content = content.replace("struct wsi_image {", "struct wsi_image {\n   void *ahardware_buffer;")
                with open(filepath, "w") as f:
                    f.write(content)
EOF

sed -i 's|-Wl,-soname,libvulkan_wrapper.so|-Wl,-soname,libvulkan_wrapper.so -Wl,--whole-archive '"$NDK_LIB_DIR_64"'/libadrenotools.a '"$NDK_LIB_DIR_64"'/liblinkernsbypass.a -Wl,--no-whole-archive|g' build64/build.ninja
sed -i 's/vulkan_freedreno//g' build64/build.ninja
ninja -C build64 -j $NPROC_CORES

# --- CARRIEL B: 32 BITS (OPTIMIZACIÓN MALI HARD NEON) ---
export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26 -lc -llog -landroid -ldl"
printf "[binaries]\nc = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'\ncpp = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang++'\nar = '$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = '/usr/bin/pkg-config'\nglslangValidator = '/usr/bin/glslangValidator'\n[built-in options]\nc_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=hard', '-mfpu=neon']\ncpp_args = ['--sysroot=$SYSROOT_PATH', '-w', '-D_GNU_SOURCE', '-I$BASE_PWD/local_include', '-I$BASE_PWD/local_include/libdrm', '-I$BASE_PWD/spirv_source/include', '-I$BASE_PWD/glslang_source', '-I$BASE_PWD/adrenotools_source/include', '-march=armv7-a', '-mfloat-abi=hard', '-mfpu=neon']\nc_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-lglslang', '-lclc', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\ncpp_link_args = ['--sysroot=$SYSROOT_PATH', '-L$NDK_LIB_DIR_32', '-Wl,--whole-archive', '-lSPIRV-Tools-opt', '-lSPIRV-Tools', '-lglslang', '-lclc', '-Wl,--no-whole-archive', '-lc', '-llog', '-landroid', '-ldl']\n[host_machine]\nsystem = 'android'\ncpu_family = 'arm'\ncpu = 'armv7-a'\nendian = 'little'\n" > cross32.txt

sed -i "s|-L$BASE_PWD/spirv_source/build_64/source|-L$BASE_PWD/spirv_source/build_32/source|g" local_pkgconfig/SPIRV-Tools.pc
sed -i "s|-L$BASE_PWD/spirv_source/build_64/source/opt|-L$BASE_PWD/spirv_source/build_32/source/opt|g" local_pkgconfig/SPIRV-Tools-opt.pc
sed -i "s|-L$BASE_PWD/glslang_source/build_64/glslang|-L$BASE_PWD/glslang_source/build_32/glslang|g" local_pkgconfig/glslang.pc
sed -i "s|$NDK_LIB_DIR_64|$NDK_LIB_DIR_32|g" local_pkgconfig/libclc.pc

meson setup build32 --cross-file cross32.txt --buildtype=release -Doptimization=2 -Dwerror=false -Dplatforms=android -Dplatform-sdk-version=26 -Dandroid-strict=false -Dvulkan-drivers=wrapper,freedreno -Dgallium-drivers=freedreno -Dshared-glapi=enabled -Dllvm=disabled -Dvideo-codecs=[] -Db_rpath=false --wrap-mode=nodownload -Dc_link_args="-L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26" -Dcpp_link_args="-L$NDK_LIB_DIR_32 -L$SYSROOT_PATH/usr/lib/arm-linux-androideabi/26"

sed -i 's|-Wl,-soname,libvulkan_wrapper.so|-Wl,-soname,libvulkan_wrapper.so -Wl,--whole-archive '"$NDK_LIB_DIR_32"'/libadrenotools.a -Wl,--no-whole-archive|g' build32/build.ninja
sed -i 's/vulkan_freedreno//g' build32/build.ninja
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
echo "¡Tu Fat Binary unificado de factoría completa bajo tu estrategia de engaño Turnip ha sido coronado con éxito!"
