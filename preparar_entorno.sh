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
# Usamos el directorio del espacio de trabajo de GitHub Actions para evitar fallos de ruta
WORKSPACE_DIR="${GITHUB_WORKSPACE:-/workspace}"
cd "$WORKSPACE_DIR"

if [ ! -d "android-ndk-r25c" ]; then
    echo "Descargando NDK desde los servidores de Google..."
    wget -q --show-progress https://google.com -O android-ndk-r25c-linux.zip
    
    echo "Extrayendo archivos del NDK..."
    unzip -q android-ndk-r25c-linux.zip
    
    echo "Limpiando archivo ZIP temporal..."
    rm android-ndk-r25c-linux.zip
    echo "¡Android NDK instalado correctamente en $WORKSPACE_DIR/android-ndk-r25c!"
else
    echo "El Android NDK ya se encuentra instalado."
fi

echo "=== Configuración del entorno completada con éxito ==="
