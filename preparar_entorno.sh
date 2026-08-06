#!/bin/bash
set -e

echo "=== Actualizando sistema e instalando dependencias base ==="
sudo apt-get update

sudo apt-get install -y --allow-change-held-packages \
    build-essential \
    meson \
    ninja-build \
    pkg-config \
    bison \
    flex \
    python3-pip \
    git \
    wget \
    unzip

echo "=== Descargando e instalando Android NDK r25c ==="
# Descargamos el NDK oficial en el directorio /workspace para que esté accesible
cd /workspace
if [ ! -d "android-ndk-r25c" ]; then
    wget -q https://google.com
    unzip -q android-ndk-r25c-linux.zip
    rm android-ndk-r25c-linux.zip
    echo "¡Android NDK instalado correctamente!"
else
    echo "El Android NDK ya se encuentra instalado."
fi

echo "=== Configuración del entorno completada con éxito ==="
