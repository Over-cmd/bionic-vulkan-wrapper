#!/bin/bash
set -e

# Configuración de rutas de compilación y salida
BUILD_DIR="/workspace/build"
PREFIX_DIR="/workspace/output"
NDK_DIR="/workspace/android-ndk-r25c"
CROSS_FILE="/workspace/android_cross.txt"

echo "=== Creando archivo de compilación cruzada para Android (Clang) ==="
# Generamos un cross-file dinámico para obligar a Meson a usar Clang del NDK
cat << EOF > "$CROSS_FILE"
[binaries]
c = '$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android25-clang'
cpp = '$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android25-clang++'
ar = '$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkgconfig = '/usr/bin/pkg-config'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF

echo "=== Aplicando parches dinámicos a meson.build ==="
cd /workspace
if [ -f "meson.build" ]; then
    sed -i "s/dependency('cutils', required : true)/dependency('cutils', required : false)/g" meson.build
    sed -i "s/dependency('cutils')/dependency('cutils', required : false)/g" meson.build
    sed -i "s/dependency('hardware', required : true)/dependency('hardware', required : false)/g" meson.build
    sed -i "s/dependency('hardware')/dependency('hardware', required : false)/g" meson.build
    sed -i "s/dependency('sync', required : true)/dependency('sync', required : false)/g" meson.build
    sed -i "s/dependency('sync')/dependency('sync', required : false)/g" meson.build
    echo "¡Todos los parches de librerías se han aplicado con éxito!"
else
    echo "Alerta: No se encontró meson.build en el directorio raíz."
fi

echo "=== Limpiando directorios previos de compilación ==="
rm -rf "$BUILD_DIR"
rm -rf "$PREFIX_DIR"
mkdir -p "$BUILD_DIR"

echo "=== Configurando compilación de Mesa con Meson Cruzado ==="
# Añadimos el --cross-file para cambiar GCC de PC por Clang de Android
meson setup "$BUILD_DIR" \
    --prefix="$PREFIX_DIR" \
    --cross-file "$CROSS_FILE" \
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
