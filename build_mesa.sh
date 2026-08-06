#!/bin/bash
set -e

# Configuración de rutas de compilación y salida
BUILD_DIR="/workspace/build"
PREFIX_DIR="/workspace/output"

echo "=== Limpiando directorios previos de compilación ==="
rm -rf "$BUILD_DIR"
rm -rf "$PREFIX_DIR"
mkdir -p "$BUILD_DIR"

echo "=== Configurando compilación de Mesa con Meson ==="

# Forzamos la plataforma Android eliminando dependencias de escritorio
# Desactivamos cutils/libbacktrace para evitar el error de dependencias del Host
meson setup "$BUILD_DIR" \
    --prefix="$PREFIX_DIR" \
    --buildtype=release \
    -Dplatforms=android \
    -Dgallium-drivers=softpipe \
    -Dvulkan-drivers= \
    -Dgles1=disabled \
    -Dgles2=disabled \
    -Degl=disabled \
    -Dgbm=disabled \
    -Dglx=disabled \
    -Dllvm=disabled \
    -Dshared-glapi=disabled \
    -Dvalgrind=disabled \
    -Dlibunwind=disabled \
    -Dbuild-tests=false \
    -Dandroid-libbacktrace=disabled \
    -Dandroid-strict=false

echo "=== Iniciando la compilación del wrapper gráfico ==="
ninja -C "$BUILD_DIR" install

echo "=== ¡Compilación finalizada con éxito! ==="
echo "Los archivos binarios (.so) del wrapper están listos en: $PREFIX_DIR"
