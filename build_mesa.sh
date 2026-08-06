#!/bin/bash
set -e

# Configuración de rutas
BUILD_DIR="/workspace/build"
PREFIX_DIR="/workspace/output"

echo "=== Limpiando directorios previos ==="
rm -rf "$BUILD_DIR"
rm -rf "$PREFIX_DIR"
mkdir -p "$BUILD_DIR"

echo "=== Configurando compilación de Mesa con Meson ==="

# Forzamos solo la plataforma Android para evitar que busque 'wayland-scanner' o X11
meson setup "$BUILD_DIR" \
    --prefix="$PREFIX_DIR" \
    --buildtype=release \
    -Dplatforms=android \
    -Dgallium-drivers=swrast \
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
    -Dbuild-tests=false

echo "=== Compilando el wrapper gráfico ==="
ninja -C "$BUILD_DIR" install

echo "=== ¡Compilación finalizada con éxito! ==="
echo "Los archivos binarios (.so) del wrapper están listos en: $PREFIX_DIR"
