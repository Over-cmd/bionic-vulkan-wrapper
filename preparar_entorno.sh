#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO EN CALIENTE (OVER-CMD) ==="

# Forjamos el archivo cross64.txt usando el compilador clang directo del contenedor
cat << 'EOF' > cross64.txt
[binaries]
c = 'clang'
cpp = 'clang++'
ar = 'llvm-ar'
strip = 'llvm-strip'
pkg-config = '/usr/bin/pkg-config'
[built-in options]
c_args = ['-target', 'aarch64-linux-android26', '-w', '-D_GNU_SOURCE', '-I/workspace/local_include', '-I/workspace/local_include/libdrm', '-I/workspace/spirv_source/include']
cpp_args = ['-target', 'aarch64-linux-android26', '-w', '-D_GNU_SOURCE', '-I/workspace/local_include', '-I/workspace/local_include/libdrm', '-I/workspace/spirv_source/include']
c_link_args = ['-target', 'aarch64-linux-android26', '-lc', '-llog', '-landroid', '-ldl']
cpp_link_args = ['-target', 'aarch64-linux-android26', '-lc', '-llog', '-landroid', '-ldl']
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF

echo "=== ENTORNO INTEGRADO PARA EL CONTENEDOR AL 100% ==="
