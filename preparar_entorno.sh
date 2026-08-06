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
    
    # Intento 1: Servidor Principal de Google
    echo "Probando servidor principal de Google..."
    curl -f -L --connect-timeout 30 --retry 5 --retry-delay 5 "https://google.com" -o android-ndk-r25c-linux.zip || true
    
    # Validación del Intento 1
    if [ -f "android-ndk-r25c-linux.zip" ] && unzip -t android-ndk-r25c-linux.zip > /dev/null 2>&1; then
        echo "¡Archivo ZIP válido de Google confirmado!"
    else
        echo "El servidor principal falló o entregó un archivo incompleto. Activando servidor espejo alternativo..."
        rm -f android-ndk-r25c-linux.zip
        
        # Intento 2: Servidor Espejo de GitHub (Redirect verificado)
        curl -f -L --connect-timeout 30 --retry 5 --retry-delay 5 "https://github.com" -o android-ndk-r25c-linux.zip || true
    fi

    # Verificación Final Absoluta
    echo "Verificando integridad estructural del archivo final..."
    if unzip -t android-ndk-r25c-linux.zip > /dev/null 2>&1; then
        echo "¡Estructura de archivo ZIP correcta!"
    else
        echo "Error crítico: No se pudo obtener un archivo ZIP íntegro desde ninguna fuente."
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
