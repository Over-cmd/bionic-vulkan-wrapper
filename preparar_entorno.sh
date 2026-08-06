#!/bin/bash
set -e

echo "=== Actualizando sistema e instalando dependencias base ==="
sudo apt-get update

# Añadimos --allow-change-held-packages para saltar el bloqueo de build-essential
sudo apt-get install -y --allow-change-held-packages \
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

echo "=== Instalando librerías complementarias mínimas ==="
sudo apt-get install -y libunwind-dev || echo "libunwind opcional omitido"

echo "=== Configuración del entorno completada con éxito ==="
