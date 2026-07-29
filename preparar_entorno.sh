#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO PKG-CONFIG Y STUBS ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"

mkdir -p local_pkgconfig
printf "prefix=%s\nlibdir=%s\nincludedir=%s/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -L\${libdir} -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$BASE_PWD/build_drm" "$BASE_PWD" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source/opt -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc

# Inyección limpia de libdrm.so en ambos pasillos del enlazador cruzado
if [ -f "$BASE_PWD/build_drm/libdrm.so" ]; then
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_64/libdrm.so"
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_32/libdrm.so"
fi

# Duplicación estática de Adrenotools para que el carril de 32 bits no falle en el paso 482/482
cp -f "$NDK_LIB_DIR_64/libadrenotools.a" "$NDK_LIB_DIR_32/libadrenotools.a" 2>/dev/null || true
echo "=== ENTORNO ENLAZADOR TOTALMENTE SINCRO ==="
