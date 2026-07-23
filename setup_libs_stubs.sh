#!/bin/bash
set -e

# Creamos la carpeta de subproyectos dentro del árbol que se va a compilar
mkdir -p "$GITHUB_WORKSPACE/wrapper_src/subprojects"

# Escribimos los archivos .wrap con los hashes originales verificados de Khronos
cat << 'EOF' > "$GITHUB_WORKSPACE/wrapper_src/subprojects/spirv-tools.wrap"
[wrap-file]
directory = SPIRV-Tools-2024.1
source_url = https://github.com
source_filename = v2024.1.tar.gz
source_hash = 693a105f9c46d328c68aa2f89552b028da841029df4b0351336423a2a6b22b10
patch_directory = spirv-tools
EOF

cat << 'EOF' > "$GITHUB_WORKSPACE/wrapper_src/subprojects/spirv-headers.wrap"
[wrap-file]
directory = SPIRV-Headers-2024.1
source_url = https://github.com
source_filename = v2024.1-headers.tar.gz
source_hash = a2fb9e8b15d96200236e760bf0bfbaee49d5926c8bda32f91dfc1409f98a2872
EOF
