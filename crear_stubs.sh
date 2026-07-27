#!/bin/bash
set -e
echo "=== ETAPA B: APLICANDO PARCHES FÍSICOS AL CÓDIGO FUENTE ==="

if [ -f "meson.build" ]; then
  sed -i "s/cc.find_library('dl'.*)/dependency('', required : false)/g" meson.build 2>/dev/null || true
  sed -i 's/cc.find_library("dl".*)/dependency("", required : false)/g' meson.build 2>/dev/null || true
  sed -i "s/cc.find_library('rt'.*)/dependency('', required : false)/g" meson.build 2>/dev/null || true
  sed -i 's/cc.find_library("rt".*)/dependency("", required : false)/g' meson.build 2>/dev/null || true
fi

if [ -f "src/util/bitscan.c" ]; then
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.c
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.c
fi
if [ -f "src/util/bitscan.h" ]; then
  sed -i 's/\bffs\b/mesa_inline_ffs/g' src/util/bitscan.h
  sed -i 's/\bffsll\b/mesa_inline_ffsll/g' src/util/bitscan.h
fi

# Inyección de cabeceras estándar C para evitar errores de funciones implícitas time/open
sed -i "1i #include <time.h>\n#include <fcntl.h>\n#include <unistd.h>" src/vulkan/wrapper/wrapper_log.c 2>/dev/null || true
sed -i "1i #include <fcntl.h>\n#include <unistd.h>" src/vulkan/wrapper/wrapper_physical_device.c 2>/dev/null || true
sed -i '1i #include <unordered_map>' src/vulkan/wrapper/spirv_patcher.cpp 2>/dev/null || true
echo "Código fuente del wrapper sincronizado de forma pura."
