#!/bin/bash
set -e

echo "=== Actualizando sistema e instalando dependencias base ==="
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    meson \
    ninja-build \
    pkg-config \
    bison \
    flex \
    python3-pip \
    git \
    g++-multilib \
    gcc-multilib

# Evitamos que busque 'wayland-scanner' instalando solo herramientas de parsing base
echo "=== Instalando librerías complementarias mínimas ==="
sudo apt-get install -y libunwind-dev || echo "libunwind opcional omitido"

echo "=== Configuración del entorno completada con éxito ==="
