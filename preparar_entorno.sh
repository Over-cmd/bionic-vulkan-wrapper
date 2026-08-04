#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO EN CALIENTE (OVER-CMD) ==="

# Buscamos de forma dinámica el path real de Clang de 64 bits dentro del contenedor Docker
REAL_CLANG_64=$(find / -name "aarch64-linux-android*-clang" -type f 2>/dev/null | head -n 1)
REAL_CLANGXX_64=$(find / -name "aarch64-linux-android*-clang++" -type f 2>/dev/null | head -n 1)
REAL_LLVM_AR=$(find / -name "llvm-ar" -type f 2>/dev/null | head -n 1)
REAL_LLVM_STRIP=$(find / -name "llvm-strip" -type f 2>/dev/null | head -n 1)

# Si por algún motivo la búsqueda dinámica falla, usamos un fallback genérico del contenedor
if [ -z "$REAL_CLANG_64" ]; then REAL_CLANG_64="clang"; fi
if [ -z "$REAL_CLANGXX_64" ]; then REAL_CLANGXX_64="clang++"; fi
if [ -z "$REAL_LLVM_AR" ]; then REAL_LLVM_AR="llvm-ar"; fi
if [ -z "$REAL_LLVM_STRIP" ]; then REAL_LLVM_STRIP="llvm-strip"; fi

echo "-> Compilador detectado en: $REAL_CLANG_64"

# Forjamos el archivo cross64.txt inyectando las rutas absolutas reales encontradas
cat << EOF > cross64.txt
[binaries]
c = '$REAL_CLANG_64'
cpp = '$REAL_CLANGXX_64'
ar = '$REAL_LLVM_AR'
strip = '$REAL_LLVM_STRIP'
pkg-config = '/usr/bin/pkg-config'
[built-in options]
c_args = ['-w', '-D_GNU_SOURCE', '-I/workspace/local_include', '-I/workspace/local_include/libdrm', '-I/workspace/spirv_source/include']
cpp_args = ['-w', '-D_GNU_SOURCE', '-I/workspace/local_include', '-I/workspace/local_include/libdrm', '-I/workspace/spirv_source/include']
c_link_args = ['-lc', '-llog', '-landroid', '-ldl']
cpp_link_args = ['-lc', '-llog', '-landroid', '-ldl']
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF

echo "=== ENTORNO INTEGRADO PARA EL CONTENEDOR AL 100% ==="
