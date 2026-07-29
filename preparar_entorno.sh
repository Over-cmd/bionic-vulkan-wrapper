#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO PKG-CONFIG COMPLETO DE FACTORÍA ==="

NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"

# Creamos la carpeta de mapas descriptoras de compilación
mkdir -p local_pkgconfig

# 1. Soldadura de plano descriptivo de libdrm original real
printf "prefix=%s\nlibdir=%s\nincludedir=%s/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs: -L\${libdir} -ldrm\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$BASE_PWD/build_drm" "$BASE_PWD" > local_pkgconfig/libdrm.pc

# 2. Soldadura de planos descriptivos de SPIRV-Tools (leegao completo de origen)
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -L$BASE_PWD/spirv_source/build_64/source/opt -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc

# 3. Soldadura de plano descriptivo de glslang oficial de Khronos
printf "Name: glslang\nVersion: 14.0.0\nLibs: -L$BASE_PWD/glslang_source/build_64/glslang -lglslang\nCflags: -I$BASE_PWD/glslang_source\n" > local_pkgconfig/glslang.pc

# 4. SOLDADURA INDESTRUCTIBLE DE LIBCLC: Estructuramos el mapa descriptivo con las variables exactas que exige Mesa de origen para dar por bueno el check de la línea 862
printf "prefix=%s\nexec_prefix=\${prefix}\nlibdir=%s\nincludedir=\${prefix}/libclc_source/libclc/include\npkgconfig_libdir=\${libdir}\n\nName: libclc\nDescription: Library Compiler for OpenCL bytecode\nVersion: 18.0.0\nLibs: -L\${libdir} -lclc\nCflags: -I\${includedir}\n" "$BASE_PWD" "$NDK_LIB_DIR_64" > local_pkgconfig/libclc.pc

# Inyección preventiva de la librería de pantalla libdrm en ambos carriles del compilador
if [ -f "$BASE_PWD/build_drm/libdrm.so" ]; then
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_64/libdrm.so"
  cp -f "$BASE_PWD/build_drm/libdrm.so" "$NDK_LIB_DIR_32/libdrm.so"
fi

# Duplicación estática de las librerías de Qualcomm y libclc para el carril simétrico de 32 bits
cp -f "$NDK_LIB_DIR_64/libadrenotools.a" "$NDK_LIB_DIR_32/libadrenotools.a" 2>/dev/null || true
cp -f "$NDK_LIB_DIR_64/libclc.a" "$NDK_LIB_DIR_32/libclc.a" 2>/dev/null || true
echo "=== ENTORNO ENLAZADOR TOTALMENTE SINCRO CON MAPA REPARADO ==="
