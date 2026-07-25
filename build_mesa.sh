#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
CLANG_LIB_DIR="/usr/lib/llvm-18/lib"

mkdir -p local_pkgconfig

echo "=== 1. Generando descriptores de control .pc ==="
printf "prefix=%s\nlibdir=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs:\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$NDK_PATH" > local_pkgconfig/libdrm.pc
printf "prefix=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr\nlibdir=\${prefix}/lib\nincludedir=\${prefix}/include\nlibexecdir=\${prefix}/libexec\n\nName: libclc\nDescription: OpenCL C library stub for Android\nVersion: 0.2.0\nLibs:\nCflags: -I\${includedir}\n" "$NDK_PATH" > local_pkgconfig/libclc.pc
printf "Name: SPIRV-Tools\nDescription: SPIRV Tools\nVersion: 2024.1\nLibs: -lSPIRV-Tools\nCflags:\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nDescription: SPIRV Tools Opt\nVersion: 2024.1\nLibs: -lSPIRV-Tools-opt\nCflags:\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: LLVMSPIRVLib\nDescription: LLVM SPIR-V Translator Library\nVersion: 18.1.0\nLibs: -lLLVMSPIRVLib\nCflags:\n" > local_pkgconfig/LLVMSPIRVLib.pc

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

NDK_LIB_DIR_32="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/26"
NDK_LIB_DIR_64="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"

echo "=== 2. Creando archivo local_drm_stubs.c nativo ==="
cat << 'EOF' > local_drm_stubs.c
#include "local_include/xf86drm.h"
#include <stdint.h>
#include <stddef.h>
void* adrenotools_open_libvulkan(void* a) { return NULL; }
int drmIoctl(int fd, unsigned long request, void *arg) { return 0; }
int drmGetCap(int fd, uint64_t capability, uint64_t *value) { return 0; }
int drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device) { return 0; }
int drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices) { return 0; }
int drmDevicesEqual(drmDevicePtr a, drmDevicePtr b) { return 1; }
void drmFreeDevice(drmDevicePtr *device) {}
void drmFreeDevices(drmDevicePtr devices[], int count) {}
int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle) { return 0; }
int drmSyncobjDestroy(int fd, uint32_t handle) { return 0; }
int drmSyncobjHandleToFD(int fd, uint32_t handle, int *obj_fd) { return 0; }
int drmSyncobjFDToHandle(int fd, int obj_fd, uint32_t *handle) { return 0; }
int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags) { return 0; }
int drmSyncobjQuery(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }
int drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }
int drmSyncobjTimelineSignal(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count) { return 0; }
int drmSyncobjSignal(int fd, uint32_t *handles, uint32_t handle_count) { return 0; }
int drmSyncobjReset(int fd, uint32_t *handles, uint32_t handle_count) { return 0; }
int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *sync_file_fd) { return 0; }
int drmSyncobjImportSyncFile(int fd, uint32_t handle, int sync_file_fd) { return 0; }
int drmSyncobjWait(int fd, uint32_t *handles, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }
EOF

echo "=== 3. Configurando ETAPA 1: 32 BITS ==="
printf "[binaries]\nc = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'\ncpp = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang++'\nar = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = 'pkg-config'\nllvm-config = '/usr/bin/llvm-config'\n[built-in options]\nc_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-include', '%s/local_include/xf86drm.h', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000', '-Wno-error=format', '-Wno-format']\ncpp_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000', '-Wno-error=format', '-Wno-format']\nc_link_args = ['-L%s']\ncpp_link_args = ['-L%s']\n[properties]\nlib_dirs = ['%s', '%s']\n[host_machine]\nsystem = 'android'\ncpu_family = 'arm'\ncpu = 'armv7-a'\nendian = 'little'\n" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$NDK_LIB_DIR_32" "$NDK_LIB_DIR_32" "$CLANG_LIB_DIR" "$NDK_LIB_DIR_32" > arm32_cross.txt

# Inyectamos local_drm_stubs.c de forma física en la línea de compilación nativa de LDFLAGS para amarrar el WSI
export LDFLAGS="-L$CLANG_LIB_DIR -L$NDK_LIB_DIR_32 $BASE_PWD/local_drm_stubs.c -Wl,--no-gc-sections -Wl,--no-as-needed -Wl,--whole-archive $NDK_LIB_DIR_32/libSPIRV-Tools-opt.a $NDK_LIB_DIR_32/libSPIRV-Tools.a -Wl,--no-whole-archive -Wl,--no-fatal-warnings"
export CXXFLAGS="-I$BASE_PWD/spirv_source/include -I$BASE_PWD/local_include -Wno-format"
export CFLAGS="-I$BASE_PWD/local_include -Wno-format"

meson setup build32 --cross-file arm32_cross.txt --buildtype=release -Doptimization=3 -Dplatforms=android -Dplatform-sdk-version=26 -Dvulkan-drivers=wrapper -Dgallium-drivers= --wrap-mode=nodownload
ninja -C build32

echo "=== 4. Configurando ETAPA 2: 64 BITS ==="
printf "[binaries]\nc = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'\nar = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '/bin/true'\npkg-config = 'pkg-config'\nllvm-config = '/usr/bin/llvm-config'\n[built-in options]\nc_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-include', '%s/local_include/xf86drm.h', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000', '-Wno-error=format', '-Wno-format']\ncpp_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits', '-DO_RDWR=2', '-DO_CLOEXEC=0x80000', '-Wno-error=format', '-Wno-format']\nc_link_args = ['-L%s']\ncpp_link_args = ['-L%s']\n[properties]\nlib_dirs = ['%s', '%s']\n[host_machine]\nsystem = 'android'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$NDK_LIB_DIR_64" "$NDK_LIB_DIR_64" "$CLANG_LIB_DIR" "$NDK_LIB_DIR_64" > arm64_cross.txt

SO_32_PATH="$BASE_PWD/build32/src/vulkan/wrapper/libvulkan_wrapper.so"
export LDFLAGS="-L$CLANG_LIB_DIR -L$NDK_LIB_DIR_64 $BASE_PWD/local_drm_stubs.c -Wl,--no-gc-sections -Wl,--no-as-needed -Wl,--whole-archive $NDK_LIB_DIR_64/libSPIRV-Tools-opt.a $NDK_LIB_DIR_64/libSPIRV-Tools.a -Wl,--no-whole-archive -Wl,-q -Wl,--eh-frame-hdr -Wl,--just-symbols=$SO_32_PATH -Wl,--no-fatal-warnings"
export CXXFLAGS="-I$BASE_PWD/spirv_source/include -I$BASE_PWD/local_include -Wno-format"
export CFLAGS="-I$BASE_PWD/local_include -Wno-format"

meson setup build64 --cross-file arm64_cross.txt --buildtype=release -Doptimization=3 -Dplatforms=android -Dplatform-sdk-version=26 -Dvulkan-drivers=wrapper -Dgallium-drivers= --wrap-mode=nodownload
ninja -C build64

echo "=== 5. EMPAQUETADO BRUTO: Salvando el binario masivo original ==="
mkdir -p "$BASE_PWD/wrapper_output"
cp -L "$BASE_PWD/build64/src/vulkan/wrapper/libvulkan_wrapper.so" "$BASE_PWD/wrapper_output/libvulkan_wrapper.so"

echo "Verificando el tamaño bruto real y pesado del driver original de leegao:"
ls -lh "$BASE_PWD/wrapper_output/libvulkan_wrapper.so"

tar -cf "$BASE_PWD/wrapper.tar" -C "$BASE_PWD/wrapper_output" libvulkan_wrapper.so
zstd -19 "$BASE_PWD/wrapper.tar" -o "$BASE_PWD/wrapper.tzst"
echo "Empaquetado masivo completado con éxito de forma íntegra."
