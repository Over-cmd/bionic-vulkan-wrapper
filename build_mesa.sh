#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA 24 COMPLETA (64 Y 32 BITS) ==="
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
SYSROOT_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
NPROC_CORES=$(nproc)

REAL_ADRENO=$(find "$BASE_PWD" -name "libadrenotools.a" | head -n 1)
REAL_BYPASS=$(find "$BASE_PWD" -name "liblinkernsbypass.a" | head -n 1)
REAL_DRM_SO=$(find "$BASE_PWD" -name "libdrm.so" | head -n 1)

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"
export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_64 -lc -llog -landroid -ldl"
export CFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"
export CXXFLAGS="--sysroot=$SYSROOT_PATH -w -D_GNU_SOURCE"

# Copiar binarios al NDK
cp -f "$REAL_DRM_SO" "$NDK_LIB_DIR_64/libdrm.so"
cp -f "$REAL_DRM_SO" "$NDK_LIB_DIR_32/libdrm.so" 2>/dev/null || true

# Purificar Mesa WSI
if [ -f "src/vulkan/wsi/meson.build" ]; then
  sed -i 's/\r$//' src/vulkan/wsi/meson.build
  sed -i "s/files('wsi_common_ahardware_buffer.c'),/# files('wsi_common_ahardware_buffer.c'),/g" src/vulkan/wsi/meson.build
fi

# 64 BITS
meson setup build64 --cross-file cross64.txt --buildtype=release -Dplatforms=android -Dplatform-sdk-version=26 -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dllvm=disabled -Dc_link_args="-Wl,--whole-archive $REAL_ADRENO $REAL_BYPASS $REAL_DRM_SO -Wl,--no-whole-archive" -Dcpp_link_args="-Wl,--whole-archive $REAL_ADRENO $REAL_BYPASS $REAL_DRM_SO -Wl,--no-whole-archive"
echo "/* Neutralizado */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c
ninja -C build64 -j $NPROC_CORES

# 32 BITS
export LDFLAGS="--sysroot=$SYSROOT_PATH -L$NDK_LIB_DIR_32 -lc -llog -landroid -ldl"
sed -i "s|$NDK_LIB_DIR_64|$NDK_LIB_DIR_32|g" local_pkgconfig/libclc.pc
meson setup build32 --cross-file cross32.txt --buildtype=release -Dplatforms=android -Dplatform-sdk-version=26 -Dvulkan-drivers=wrapper -Dgallium-drivers=[] -Dllvm=disabled -Dc_link_args="-Wl,--whole-archive $REAL_ADRENO $REAL_DRM_SO -Wl,--no-whole-archive" -Dcpp_link_args="-Wl,--whole-archive $REAL_ADRENO $REAL_DRM_SO -Wl,--no-whole-archive"
echo "/* Neutralizado */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c
ninja -C build32 -j $NPROC_CORES

# Empaquetado final
mkdir -p wrapper_output/vulkan_wrapper/usr/lib
"$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-lipo" -create build32/src/vulkan/wrapper/libvulkan_wrapper.so build64/src/vulkan/wrapper/libvulkan_wrapper.so -output wrapper_output/vulkan_wrapper/usr/lib/libvulkan_wrapper.so
tar -cf ../wrapper.tar -C wrapper_output vulkan_wrapper; zstd -19 ../wrapper.tar -o ../wrapper.tzst
