#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO EN CALIENTE (OVER-CMD) ==="

BASE_PWD="/workspace"

# Forjamos el archivo cross64.txt con los compiladores globales del contenedor Docker
cat << 'EOF' > cross64.txt
[binaries]
c = 'aarch64-linux-android-clang'
cpp = 'aarch64-linux-android-clang++'
ar = 'llvm-ar'
strip = 'llvm-strip'
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
