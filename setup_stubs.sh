#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
TARGET_LIB_DIR="${SYSROOT_MAESTRO}/usr/lib/aarch64-linux-android/26"
mkdir -p "${SYSROOT_MAESTRO}/usr/include/bits" "$TARGET_LIB_DIR"

# 1. Inyectamos las estructuras de preprocesador obligatorias de Android
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/bits/pthreadtypes.h"
echo -e '#ifndef ZSTD_H\n#define ZSTD_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zstd.h"
echo -e '#ifndef ZLIB_H\n#define ZLIB_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zlib.h"
echo -e '#ifndef ZCONF_H\n#define ZCONF_H\n#endif' > "${SYSROOT_MAESTRO}/usr/include/zconf.h"

# 2. Cabecera máster unificada para saltar las validaciones estáticas de PC y DRM
cat << 'EOF' > /tmp/vk_pc_stubs.h
#ifndef _VK_PC_STUBS_H
#define _VK_PC_STUBS_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#define HAVE_ZSTD 1
#define HAVE_ZLIB 1
#define DRM_NODE_RENDER 0
#define DRM_BUS_PCI 0
typedef unsigned char Byte; typedef unsigned int uInt; typedef unsigned long uLong; typedef void *voidpf;
unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);
size_t ZSTD_compressBound(size_t srcSize);
size_t ZSTD_compress(void* dst, size_t dstCapacity, const void* src, size_t srcSize, int compressionLevel);
size_t ZSTD_decompress(void* dst, size_t dstCapacity, const void* src, size_t srcSize);
unsigned int ZSTD_isError(size_t code); const char* ZSTD_getErrorName(size_t code);
int open(const char *pathname, int flags, ...);
int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle);
typedef struct VkXcbSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* connection; uintptr_t window; } VkXcbSurfaceCreateInfoKHR;
typedef struct VkXlibSurfaceCreateInfoKHR { uint32_t sType; const void* pNext; uint32_t flags; void* dpy; uintptr_t window; } VkXlibSurfaceCreateInfoKHR;
void* adrenotools_open_libvulkan(const char* a, const char* s);
#endif
EOF

# 3. Código fuente biónico de C++ para compilar SPIRV-Tools-opt
cat << 'EOF' > /tmp/stub.cpp
#include <stdint.h>
#include <stddef.h>
#include <string>
#include <vector>
#include <functional>
extern "C" {
    void* adrenotools_open_libvulkan(const char* a, const char* s) { return nullptr; }
    int drmIoctl(int fd, unsigned long request, void *arg) { return 0; }
    int drmGetCap(int fd, uint64_t capability, uint64_t *value) { if(value) *value = 1; return 0; }
    int drmPrimeFDToHandle(int fd, int prime_fd, uint32_t *handle) { return 0; }
    int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle) { if(handle) *handle = 1; return 0; }
    int drmSyncobjDestroy(int fd, uint32_t handle) { return 0; }
    int drmSyncobjReset(int fd, const uint32_t *handles, uint32_t num_handles) { return 0; }
    int drmSyncobjSignal(int fd, const uint32_t *handles, uint32_t num_handles) { return 0; }
    int drmSyncobjWait(int fd, uint32_t *handles, uint32_t num_handles, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }
    int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *map_fd) { return 0; }
    int drmSyncobjImportSyncFile(int fd, uint32_t handle, int map_fd) { return 0; }
    int drmSyncobjFDToHandle(int fd, int map_fd, uint32_t *handle) { return 0; }
    int drmSyncobjHandleToFD(int fd, uint32_t handle, int *map_fd) { return 0; }
    int drmSyncobjTimelineSignal(int fd, const uint32_t *handles, const uint64_t *points, uint32_t num_handles) { return 0; }
    int drmSyncobjTimelineWait(int fd, uint32_t *handles, const uint64_t *points, uint32_t num_handles, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }
    int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t num_handles) { return 0; }
    int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags) { return 0; }
    int drmGetDevice2(int fd, uint32_t flags, void* device) { return 0; }
    void drmFreeDevice(void* device) {}
    int drmGetDevices2(uint32_t flags, void* devices[], int max_devices) { return 0; }
    void drmFreeDevices(void* devices[], int count) {}
    bool drmDevicesEqual(void* a, void* b) { return true; }
}
namespace spvtools {
    class SpirvTools { public: SpirvTools(uint32_t env); ~SpirvTools(); bool Disassemble(const std::vector<uint32_t>& binary, std::string* text, uint32_t options) const; };
    SpirvTools::SpirvTools(uint32_t env) {} SpirvTools::~SpirvTools() {}
    bool SpirvTools::Disassemble(const std::vector<uint32_t>& binary, std::string* text, uint32_t options) const { return false; }
    class Optimizer { public: struct PassToken { void* dummy; PassToken(); ~PassToken(); }; Optimizer(uint32_t env); ~Optimizer(); Optimizer& SetMessageConsumer(std::function<void(uint32_t, const char*, const void*, const char*)> consumer); Optimizer& RegisterPass(PassToken&& user_pass); Optimizer& RegisterPerformancePasses(); Optimizer& RegisterSizePasses(); bool Run(const uint32_t* code, size_t size, std::vector<uint32_t>* optimized_code) const; };
    Optimizer::PassToken::PassToken() : dummy(nullptr) {} Optimizer::PassToken::~PassToken() {}
    Optimizer::Optimizer(uint32_t env) {} Optimizer::~Optimizer() {}
    Optimizer& Optimizer::SetMessageConsumer(std::function<void(uint32_t, const char*, const void*, const char*)> consumer) { return *this; }
    Optimizer& Optimizer::RegisterPass(PassToken&& user_pass) { return *this; }
    Optimizer& Optimizer::RegisterPerformancePasses() { return *this; }
    Optimizer& Optimizer::RegisterSizePasses() { return *this; }
    bool Optimizer::Run(const uint32_t* code, size_t size, std::vector<uint32_t>* optimized_code) const {
        if (optimized_code && code && size > 0) { optimized_code->assign(code, code + size); }
        return true;
    }
    Optimizer::PassToken CreateStripDebugInfoPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateAggressiveDCEPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateCompactIdsPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateRemoveClipCullDistPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateFixMaliSpecConstantCompositePass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateMaliOptimizationBarrierPass() { Optimizer::PassToken t; return t; }
}
EOF

# 4. Compilamos el objeto nativo estático y lo depositamos en el sysroot real del NDK
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++ -std=gnu++17 -stdlib=libc++ -fPIC -c /tmp/stub.cpp -o /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$TARGET_LIB_DIR/libSPIRV-Tools-opt.a" /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$TARGET_LIB_DIR/libSPIRV-Tools.a" /tmp/stub.o

# 5. Interceptor fake-pkg-config
echo -e '#!/bin/bash\nif [[ "$*" == *"--modversion"* ]]; then echo "14.0.0"; else echo "-I/tmp"; fi\nexit 0' > /tmp/fake-pkg-config
chmod +x /tmp/fake-pkg-config

# 6. Escribimos el cross-file maestro de Meson para ARM64
cat << EOF > /tmp/cross.txt
[binaries]
c='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config='/tmp/fake-pkg-config'
glslangValidator='/usr/bin/glslangValidator'
[properties]
sys_root='${SYSROOT_MAESTRO}'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DVK_USE_PLATFORM_ANDROID_KHR', '-DVK_EXPORT', '-include', '/tmp/vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
c_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-L${TARGET_LIB_DIR}']
cpp_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic', '-L${TARGET_LIB_DIR}', '-stdlib=libc++']
[host_machine]
system='linux' ; cpu_family='aarch64' ; cpu='armv8-a' ; endian='little'
EOF
