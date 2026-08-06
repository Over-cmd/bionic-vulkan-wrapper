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
    curl \
    unzip

echo "=== Descargando e instalando Android NDK r25c ==="
WORKSPACE_DIR="${GITHUB_WORKSPACE:-/workspace}"
cd "$WORKSPACE_DIR"

if [ ! -d "android-ndk-r25c" ]; then
    echo "Iniciando descarga segura de Android NDK (531MB)..."
    # Usamos curl con parámetros de resistencia frente a microcortes de red
    curl -L --connect-timeout 30 --retry 5 --retry-delay 5 https://dl.google.com/android/repository/android-ndk-r25c-linux.zip -o android-ndk-r25c-linux.zip
    
    echo "Verificando integridad del archivo ZIP..."
    if unzip -t android-ndk-r25c-linux.zip > /dev/null; then
        echo "¡Archivo ZIP válido confirmado!"
    else
        echo "Error crítico: El archivo descargado sigue corrupto o incompleto."
        exit 1
    fi

    echo "Extrayendo archivos del NDK..."
    unzip -q android-ndk-r25c-linux.zip
    
    echo "Limpiando archivo ZIP temporal..."
    rm android-ndk-r25c-linux.zip
    echo "¡Android NDK instalado correctamente en $WORKSPACE_DIR/android-ndk-r25c!"
else
    echo "El Android NDK ya se encuentra instalado."
fi

echo "=== Configuración del entorno completada con éxito ==="
