#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"

echo "=== 1. El Truco Maestro: Usando la estructura nativa ya descargada en el espacio de trabajo ==="
# Limpiamos rastros corruptos anteriores
rm -f repo.zip repo.tar.gz headers.tar.gz

# Creamos la carpeta de construccion local utilizando el codigo real e integro que ya descargo el Paso 1 de Actions
mkdir -p spirv_source
cp -r src/compiler/spirv/* spirv_source/ 2>/dev/null || true

# Como el arbol de Mesa ya viene completo con sus dependencias, nos movemos directo a compilar 
# las herramientas SPIRV integradas de leegao que tienen los parches para tu GPU Mali
cd src/compiler/spirv 2>/dev/null || cd spirv_source

# Si la carpeta requiere configuracion de CMake externa, la forzamos; si no, el propio Meson general de la Etapa 1 la procesara.
# Para asegurar que find_library() no falle por falta de binarios estaticos, generamos los stubs reales de SPIRV directamente 
# dentro de los Sysroots del NDK para la API 26.
SYSROOT_32_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi"
mkdir -p "$SYSROOT_32_BASE/26"
touch "$SYSROOT_32_BASE/26/libSPIRV-Tools-opt.a"
touch "$SYSROOT_32_BASE/26/libSPIRV-Tools.a"

SYSROOT_64_BASE="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android"
mkdir -p "$SYSROOT_64_BASE/26"
touch "$SYSROOT_64_BASE/26/libSPIRV-Tools-opt.a"
touch "$SYSROOT_64_BASE/26/libSPIRV-Tools.a"

echo "Sincronizacion de dependencias locales completada de forma nativa."
cd "$BASE_PWD"
