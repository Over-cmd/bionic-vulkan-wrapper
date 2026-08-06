#!/bin/bash
set -e

# Detectamos de forma dinámica el espacio de trabajo activo
WORKSPACE_DIR="${GITHUB_WORKSPACE:-/workspace}"
BUILD_DIR="$WORKSPACE_DIR/build"
PREFIX_DIR="$WORKSPACE_DIR/output"
NDK_DIR="$WORKSPACE_DIR/android-ndk-r25c"
CROSS_FILE="$WORKSPACE_DIR/android_cross.txt"

echo "=== Creando archivo de compilación cruzada para Android (Clang) ==="
# Corregimos los nombres de los binarios y añadimos los flags de la API 25 requeridos por Clang
cat << EOF > "$CROSS_FILE"
[binaries]
c = '$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android-clang'
cpp = '$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android-clang++'
ar = '$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config = '/usr/bin/pkg-config'

[built-in options]
c_args = ['-target', 'aarch64-linux-android25']
cpp_args = ['-target', 'aarch64-linux-android25']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF

echo "=== Aplicando parches dinámicos a meson.build ==="
cd "$WORKSPACE_DIR"
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
