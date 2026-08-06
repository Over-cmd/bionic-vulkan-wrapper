#!/bin/bash
set -e

# Configuración de rutas de compilación y salida
BUILD_DIR="/workspace/build"
PREFIX_DIR="/workspace/output"

echo "=== Aplicando parches dinámicos a meson.build ==="
# Modificamos cutils, hardware y sync para que pasen de largo si no están en el Host de Linux
if [ -f "meson.build" ]; then
    # Parches para cutils
    sed -i "s/dependency('cutils', required : true)/dependency('cutils', required : false)/g" meson.build
    sed -i "s/dependency('cutils')/dependency('cutils', required : false)/g" meson.build
    
    # Parches para hardware (libhardware)
    sed -i "s/dependency('hardware', required : true)/dependency('hardware', required : false)/g" meson.build
    sed -i "s/dependency('hardware')/dependency('hardware', required : false)/g" meson.build
    
    # Parches preventivos para sync (siguiente dependencia típica de Android en Mesa)
    sed -i "s/dependency('sync', required : true)/dependency('sync', required : false)/g" meson.build
    sed -i "s/dependency('sync')/dependency('sync', required : false)/g" meson.build

    echo "¡Todos los parches de librerías de Android se han aplicado con éxito!"
else
    echo "Alerta: No se encontró meson.build en el directorio raíz."
fi

echo "=== Limpiando directorios previos de compilación ==="
rm -rf "$BUILD_DIR"
rm -rf "$PREFIX_DIR"
mkdir -p "$BUILD_DIR"

echo "=== Configurando compilación de Mesa con Meson ==="

# Forzamos la plataforma Android eliminando dependencias de escritorio
# Desactivamos módulos internos que exigen binarios reales de Android en el Host
meson setup "$BUILD_DIR" \
    --prefix="$PREFIX_DIR" \
    --buildtype=release \
    -Dplatforms=android \
    -Dgallium-drivers=softpipe \
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
    -Dbuild-tests=false \
    -Dandroid-libbacktrace=disabled \
    -Dandroid-strict=false

echo "=== Iniciando la compilación del wrapper gráfico ==="
ninja -C "$BUILD_DIR" install

echo "=== ¡Compilación finalizada con éxito! ==="
echo "Los archivos binarios (.so) del wrapper están listos en: $PREFIX_DIR"
