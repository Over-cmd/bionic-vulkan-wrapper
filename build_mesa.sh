#!/bin/bash
set -e
echo "=== ETAPA C-3: COMPILACIÓN MESA WRAPPER PURO PARA MALI (DOCKER) ==="

BUILD_DIR="build"
NPROC_CORES=$(nproc)

# PARCHE DEFENSIVO SPIRV-Tools-opt
if [ -f "src/vulkan/wrapper/meson.build" ]; then
  echo "-> Soldando bypass de redirección para SPIRV-Tools-opt en meson.build..."
  sed -i 's/dep_spirv_tools_opt = .*/dep_spirv_tools_opt = dependency('\''SPIRV-Tools-opt'\'')/g' src/vulkan/wrapper/meson.build
  sed -i 's/cpp.find_library('\''SPIRV-Tools-opt'\''.*)/dependency('\''SPIRV-Tools-opt'\'')/g' src/vulkan/wrapper/meson.build
fi

# Limpiamos configuraciones previas corruptas si existen
rm -rf "$BUILD_DIR"

# Inicializamos Meson y Ninja
meson setup "$BUILD_DIR" \
  --cross-file cross64.txt \
  --buildtype=release \
  -Dvulkan-drivers=wrapper \
  -Dgallium-drivers=[] \
  -Dgallium-opencl=disabled \
  -Dmicrosoft-clc=disabled

ninja -C "$BUILD_DIR" -j "$NPROC_CORES"

echo "=== CARRIEL DE 64 BITS DE MESA COMPLETADO ==="
