#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA WRAPPER PURO PARA MALI (DOCKER) ==="

BUILD_DIR="compilacion"
NPROC_CORES=$(nproc)

# Inicializamos Meson y Ninja utilizando el crossfile saneado previamente
meson setup "$BUILD_DIR" --cross-file cross64.txt --buildtype=release -Dvulkan-drivers=wrapper
ninja -C "$BUILD_DIR" -j "$NPROC_CORES"

echo "=== CARRIEL DE 64 BITS DE MESA COMPLETADO ==="
