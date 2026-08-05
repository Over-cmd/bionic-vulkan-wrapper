#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA WRAPPER PURO PARA MALI (DOCKER) ==="

BUILD_DIR="build"
NPROC_CORES=$(nproc)

# Limpiamos configuraciones previas corruptas antes de compilar
rm -rf "$BUILD_DIR"

# Inicializamos Meson desactivando OpenCL (Clover) para evadir el bache de libclc de forma lícita
meson setup "$BUILD_DIR" \
  --cross-file cross64.txt \
  --buildtype=release \
  -Dvulkan-drivers=wrapper \
  -Dgallium-drivers=[] \
  -Dgallium-opencl=disabled \
  -Dmicrosoft-clc=disabled

ninja -C "$BUILD_DIR" -j "$NPROC_CORES"

echo "=== CARRIEL DE 64 BITS DE MESA COMPLETADO ==="
