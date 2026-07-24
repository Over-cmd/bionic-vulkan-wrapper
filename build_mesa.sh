#!/bin/bash
set -e
NDK_PATH="$ANDROID_NDK_LATEST_HOME"
BASE_PWD="$PWD"
CLANG_LIB_DIR="/usr/lib/llvm-18/lib"

mkdir -p local_pkgconfig
mkdir -p local_include/libdrm
mkdir -p local_include/bits

echo "=== 1. Vaciando wsi_common_ahardware_buffer.c para evitar falta de prototipos ==="
if [ -f "src/vulkan/wsi/wsi_common_ahardware_buffer.c" ]; then
  echo "/* Stub vacio para Android compilacion cruzada */" > src/vulkan/wsi/wsi_common_ahardware_buffer.c
fi

echo "=== 2. Creando cabecera de compatibilidad bits/pthreadtypes.h ==="
touch local_include/bits/pthreadtypes.h

echo "=== 3. Inyectando cabecera xf86drm.h definitiva blindada contra redefiniciones ==="
# Incluimos ioctl.h nativo y envolvemos las macros en condicionales para evitar que Clang aborte en la linea 426
printf "#ifndef _XF86DRM_H_\n#define _XF86DRM_H_\n#include <stdint.h>\n#include <stddef.h>\n#include <sys/ioctl.h>\n#include \"../../include/drm-uapi/drm.h\"\n\n#ifndef DRM_SYNCOBJ_CREATE_SIGNALED\n#define DRM_SYNCOBJ_CREATE_SIGNALED (1 << 0)\n#endif\n#ifndef DRM_SYNCOBJ_WAIT_FLAGS_WAIT_ALL\n#define DRM_SYNCOBJ_WAIT_FLAGS_WAIT_ALL (1 << 0)\n#endif\n#ifndef DRM_SYNCOBJ_WAIT_FLAGS_WAIT_FOR_SUBMIT\n#define DRM_SYNCOBJ_WAIT_FLAGS_WAIT_FOR_SUBMIT (1 << 1)\n#endif\n#ifndef DRM_CAP_SYNCOBJ_TIMELINE\n#define DRM_CAP_SYNCOBJ_TIMELINE 0x14\n#endif\n\n#ifndef DMA_BUF_IOCTL_EXPORT_SYNC_FILE\nstruct local_drm_syncobj_handle { uint32_t handle; uint32_t flags; int32_t fd; };\n#define DMA_BUF_IOCTL_EXPORT_SYNC_FILE _IOWR('b', 2, struct local_drm_syncobj_handle)\n#endif\n\ntypedef struct _drmDevice { char **nodes; int available_nodes; int bustype; union { int pci; int usb; int platform; int oci; } businfo; union { int pci; int usb; int platform; int oci; } deviceinfo; } drmDevice, *drmDevicePtr;\n\n#ifdef __cplusplus\nextern \"C\" {\n#endif\nint drmIoctl(int fd, unsigned long request, void *arg);\nint drmGetCap(int fd, uint64_t capability, uint64_t *value);\nint drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices);\nvoid drmFreeDevices(drmDevicePtr devices[], int count);\nint drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle);\nint drmSyncobjDestroy(int fd, uint32_t handle);\nint drmSyncobjHandleToFD(int fd, uint32_t handle, int *obj_fd);\nint drmSyncobjFDToHandle(int fd, int obj_fd, uint32_t *handle);\nint drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags);\nint drmSyncobjQuery(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count);\nint drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled);\nint drmSyncobjTimelineSignal(int fd, uint32_t *handles, uint64_t *points, uint32_t handle_count);\nint drmSyncobjSignal(int fd, uint32_t *handles, uint32_t handle_count);\nint drmSyncobjReset(int fd, uint32_t *handles, uint32_t handle_count);\nint drmSyncobjExportSyncFile(int fd, uint32_t handle, int *sync_file_fd);\nint drmSyncobjImportSyncFile(int fd, uint32_t handle, int sync_file_fd);\nint drmSyncobjWait(int fd, uint32_t *handles, uint32_t handle_count, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled);\n#ifdef __cplusplus\n}\n#endif\n#endif\n" > local_include/xf86drm.h

cp local_include/xf86drm.h local_include/libdrm/xf86drm.h

echo "=== 4. Generando descriptores de control .pc ==="
printf "prefix=%s\nlibdir=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib\nincludedir=\${prefix}/local_include\n\nName: libdrm\nDescription: Userspace interface to kernel DRM services\nVersion: 2.4.120\nLibs:\nCflags: -I\${includedir} -I\${includedir}/libdrm\n" "$BASE_PWD" "$NDK_PATH" > local_pkgconfig/libdrm.pc
printf "prefix=%s/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr\nlibdir=\${prefix}/lib\nincludedir=\${prefix}/include\nlibexecdir=\${prefix}/libexec\n\nName: libclc\nDescription: OpenCL C library stub for Android\nVersion: 0.2.0\nLibs:\nCflags: -I\${includedir}\n" "$NDK_PATH" > local_pkgconfig/libclc.pc
printf "Name: SPIRV-Tools\nDescription: SPIRV Tools\nVersion: 2024.1\nLibs: -lSPIRV-Tools\nCflags:\n" > local_pkgconfig/SPIRV-Tools.pc
printf "Name: SPIRV-Tools-opt\nDescription: SPIRV Tools Opt\nVersion: 2024.1\nLibs: -lSPIRV-Tools-opt\nCflags:\n" > local_pkgconfig/SPIRV-Tools-opt.pc
printf "Name: LLVMSPIRVLib\nDescription: LLVM SPIR-V Translator Library\nVersion: 18.1.0\nLibs: -lLLVMSPIRVLib\nCflags:\n" > local_pkgconfig/LLVMSPIRVLib.pc

export PKG_CONFIG_PATH="$BASE_PWD/local_pkgconfig"
export PKG_CONFIG_LIBDIR="$BASE_PWD/local_pkgconfig"

echo "=== 5. Configurando ETAPA 1: 32 BITS ==="
printf "[binaries]\nc = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi26-clang'\ncpp = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi25-clang++'\nar = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'\npkg-config = 'pkg-config'\nllvm-config = '/usr/bin/llvm-config'\n[built-in options]\nc_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits']\ncpp_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits']\n[properties]\nlib_dirs = ['%s']\n[host_machine]\nsystem = 'android'\ncpu_family = 'arm'\ncpu = 'armv7-a'\nendian = 'little'\n" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$CLANG_LIB_DIR" > arm32_cross.txt

export LDFLAGS="-L$CLANG_LIB_DIR"
export CXXFLAGS="-I$BASE_PWD/spirv_source/include -I$BASE_PWD/local_include"
export CFLAGS="-I$BASE_PWD/local_include"

meson setup build32 --cross-file arm32_cross.txt --buildtype=release -Dplatforms=android -Dplatform-sdk-version=26 -Dvulkan-drivers=wrapper -Dgallium-drivers= --wrap-mode=nodownload
ninja -C build32

echo "=== 6. Configurando ETAPA 2: 64 BITS (Truco Pipetto) ==="
printf "[binaries]\nc = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'\ncpp = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android25-clang++'\nar = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'\nstrip = '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'\npkg-config = 'pkg-config'\nllvm-config = '/usr/bin/llvm-config'\n[built-in options]\nc_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits']\ncpp_args = ['-I%s/spirv_source/include', '-I%s/local_include', '-I%s/local_include/libdrm', '-I%s/local_include/bits']\n[properties]\nlib_dirs = ['%s']\n[host_machine]\nsystem = 'android'\ncpu_family = 'aarch64'\ncpu = 'armv8-a'\nendian = 'little'\n" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$NDK_PATH" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$BASE_PWD" "$CLANG_LIB_DIR" > arm64_cross.txt

SO_32_PATH="$BASE_PWD/build32/src/vulkan/wrapper/libvulkan_wrapper.so"
export LDFLAGS="-L$CLANG_LIB_DIR -Wl,-q -Wl,--eh-frame-hdr -Wl,--just-symbols=$SO_32_PATH"
export CXXFLAGS="-I$BASE_PWD/spirv_source/include -I$BASE_PWD/local_include"
export CFLAGS="-I$BASE_PWD/local_include"

meson setup build64 --cross-file arm64_cross.txt --buildtype=release -Dplatforms=android -Dplatform-sdk-version=26 -Dvulkan-drivers=wrapper -Dgallium-drivers= --wrap-mode=nodownload
ninja -C build64
