#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. Localizando librerías físicas de SPIRV en Ubuntu e inyectando en el NDK ==="

# Creamos una carpeta virtual para cumplir los requisitos estofados de Meson
mkdir -p spirv_source/external/spirv-headers
touch spirv_source/CMakeLists.txt

# Buscamos los archivos estáticos reales .a que instaló apt-get en Ubuntu y los inyectamos en el NDK de 32 bits
SYSROOT_32_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
mkdir -p "$SYSROOT_32_BASE"
cp /usr/lib/x86_64-linux-gnu/libSPIRV-Tools-opt.a "$SYSROOT_32_BASE/libSPIRV-Tools-opt.a" 2>/dev/null || cp /usr/lib/libSPIRV-Tools-opt.a "$SYSROOT_32_BASE/libSPIRV-Tools-opt.a"
cp /usr/lib/x86_64-linux-gnu/libSPIRV-Tools.a "$SYSROOT_32_BASE/libSPIRV-Tools.a" 2>/dev/null || cp /usr/lib/libSPIRV-Tools.a "$SYSROOT_32_BASE/libSPIRV-Tools.a"

# Inyectamos las mismas librerías físicas dentro de las carpetas del NDK de 64 bits
SYSROOT_64_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"
mkdir -p "$SYSROOT_64_BASE"
cp /usr/lib/x86_64-linux-gnu/libSPIRV-Tools-opt.a "$SYSROOT_64_BASE/libSPIRV-Tools-opt.a" 2>/dev/null || cp /usr/lib/libSPIRV-Tools-opt.a "$SYSROOT_64_BASE/libSPIRV-Tools-opt.a"
cp /usr/lib/x86_64-linux-gnu/libSPIRV-Tools.a "$SYSROOT_64_BASE/libSPIRV-Tools.a" 2>/dev/null || cp /usr/lib/libSPIRV-Tools.a "$SYSROOT_64_BASE/libSPIRV-Tools.a"

echo "=== Inyección física de binarios estáticos completada de forma segura ==="
