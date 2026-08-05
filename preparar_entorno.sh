#!/bin/bash
set -e
echo "=== ETAPA C-2: PREPARACIÓN DE ENTORNO EN CALIENTE NATIVO (DOCKER) ==="

# 1. Búsqueda dinámica de rutas del Toolchain de leegao dentro de Docker
REAL_CLANG_64=$(find / -name "aarch64-linux-android*-clang" -type f 2>/dev/null | head -n 1)
REAL_CLANGXX_64=$(find / -name "aarch64-linux-android*-clang++" -type f 2>/dev/null | head -n 1)
REAL_LLVM_AR=$(find / -name "llvm-ar" -type f 2>/dev/null | head -n 1)
REAL_LLVM_STRIP=$(find / -name "llvm-strip" -type f 2>/dev/null | head -n 1)

if [ -z "$REAL_CLANG_64" ]; then REAL_CLANG_64="clang"; fi
if [ -z "$REAL_CLANGXX_64" ]; then REAL_CLANGXX_64="clang++"; fi
if [ -z "$REAL_LLVM_AR" ]; then REAL_LLVM_AR="llvm-ar"; fi
if [ -z "$REAL_LLVM_STRIP" ]; then REAL_LLVM_STRIP="llvm-strip"; fi

mkdir -p local_pkgconfig local_include

# =========================================================================
# 2. STUBS DE CONFIGURACIÓN PKG-CONFIG (Mapeo absoluto para Meson)
# =========================================================================
printf "prefix=/workspace\nlibdir=\${prefix}\nincludedir=\${prefix}/local_include\n\nName: libclc\nDescription: Stub de compatibilidad OpenCL\nVersion: 18.0.0\nLibs: -L\${libdir}\nCflags: -I\${includedir}\n" > local_pkgconfig/libclc.pc
printf "prefix=/workspace\nlibdir=\${prefix}\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Stub de compatibilidad Graphics DRM para Mali Wrapper\nVersion: 2.4.120\nLibs: -L\${libdir}\nCflags: -I\${includedir}\n" > local_pkgconfig/libdrm.pc
printf "Name: SPIRV-Tools\nVersion: 2024.1\nLibs: -L/workspace/spirv_source/build_64/source -lSPIRV-Tools\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nVersion: 2024.1\nLibs: -L/workspace/spirv_source/build_64/source/opt -lSPIRV-Tools-opt\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: glslang\nVersion: 14.0.0\nLibs: -L/workspace/glslang_source/build_64/glslang -lglslang\nCflags: -I/workspace/glslang_source\n" > local_pkgconfig/glslang.pc

# =========================================================================
# 3. FORJA DEL CROSSFILE SANEADO ABSOLUTO
# =========================================================================
cat << EOF > cross64.txt
[binaries]
c = '$REAL_CLANG_64'
cpp = '$REAL_CLANGXX_64'
ar = '$REAL_LLVM_AR'
strip = '$REAL_LLVM_STRIP'
pkg-config = '/usr/bin/pkg-config'
pkg_config_libdir = '/workspace/local_pkgconfig'
pkg_config_path = '/workspace/local_pkgconfig'

[built-in options]
c_args = ['-w', '-D_GNU_SOURCE', '-I/workspace/local_include', '-I/workspace/spirv_source/include']
cpp_args = ['-w', '-D_GNU_SOURCE', '-I/workspace/local_include', '-I/workspace/spirv_source/include']
c_link_args = ['-lc', '-llog', '-landroid', '-ldl']
cpp_link_args = ['-lc', '-llog', '-landroid', '-ldl']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF

echo "=== ENTORNO REPARTIDO Y SANEADO AL 100% ==="
