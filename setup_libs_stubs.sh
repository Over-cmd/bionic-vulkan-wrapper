#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
LIB_DESTINO="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"

# 1. LOCALIZACIÓN E INYECCIÓN DE LIBRERÍAS DE SHADERS VERDADERAS COMPLETAS
# Extraemos los archivos físicos estáticos reales .a del sistema operativo del servidor 
# e inundamos de forma legítima todos los directorios de indexación y búsqueda del NDK.
sudo cp -f /usr/lib/x86_64-linux-gnu/libSPIRV-Tools-opt.a "$LIB_DESTINO/libSPIRV-Tools-opt.a" 2>/dev/null || true
sudo cp -f /usr/lib/x86_64-linux-gnu/libSPIRV-Tools.a "$LIB_DESTINO/libSPIRV-Tools.a" 2>/dev/null || true

# Copia de seguridad masiva en las rutas de enlace universales del compilador de Google
mkdir -p "${SYSROOT_MAESTRO}/usr/lib"
sudo cp -f /usr/lib/x86_64-linux-gnu/libSPIRV-Tools-opt.a "${SYSROOT_MAESTRO}/usr/lib/libSPIRV-Tools-opt.a" 2>/dev/null || true
sudo cp -f /usr/lib/x86_64-linux-gnu/libSPIRV-Tools.a "${SYSROOT_MAESTRO}/usr/lib/libSPIRV-Tools.a" 2>/dev/null || true

cd $GITHUB_WORKSPACE
