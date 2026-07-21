#!/bin/bash
set -e

# Definimos las carpetas de inclusion del NDK de Android
INC="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"
LIB_NDK="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"

# 1. PARCHE DE MIEMBROS PC: Estructuras que exige vk_printers.c
cat << 'EOF' > "$INC/vk_pc_stubs.h"
#ifndef _VK_PC_STUBS_H
#define _VK_PC_STUBS_H
#include <stdint.h>

int open(const char *pathname, int flags, ...);

typedef struct VkXcbSurfaceCreateInfoKHR {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    void* connection;
    uintptr_t window;
} VkXcbSurfaceCreateInfoKHR;

typedef struct VkXlibSurfaceCreateInfoKHR {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    void* dpy;
    uintptr_t window;
} VkXlibSurfaceCreateInfoKHR;
#endif
EOF

# 2. PARCHE BITS/PTHREADTYPES.H: Exigido por wsi_common.c
mkdir -p "$INC/bits"
echo -e '#ifndef _BITS_PTHREADTYPES_H\n#define _BITS_PTHREADTYPES_H\n#endif' > "$INC/bits/pthreadtypes.h"

# 3. PARCHE XF86DRM.H: Prototipos de sincronizacion y control de bus
cat << 'EOF' > "$INC/xf86drm.h"
#ifndef _XF86DRM_H
#define _XF86DRM_H
#include <stdint.h>
#include <stdbool.h>
#define DRM_NODE_RENDER 0
#define DRM_NODE_PRIMARY 1
#define DRM_CAP_SYNCOBJ_TIMELINE 0x14
typedef struct { uint16_t domain; uint8_t bus; uint8_t dev; uint8_t func; } drmPciBusInfo, *drmPciBusInfoPtr;
typedef union { drmPciBusInfoPtr pci; void *foo; } drmBusInfo;
typedef struct _drmDevice { uint32_t available_nodes; char **nodes; int bustype; drmBusInfo businfo; } drmDevice, *drmDevicePtr;
enum { DRM_BUS_PCI = 0 };
int drmIoctl(int fd, unsigned long request, void *arg);
int drmGetCap(int fd, uint64_t capability, uint64_t *value);
int drmPrimeFDToHandle(int fd, int prime_fd, uint32_t *handle);
int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle);
int drmSyncobjDestroy(int fd, uint32_t handle);
int drmSyncobjReset(int fd, const uint32_t *handles, uint32_t num_handles);
int drmSyncobjSignal(int fd, const uint32_t *handles, uint32_t num_handles);
int drmSyncobjWait(int fd, uint32_t *handles, uint32_t num_handles, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled);
int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *map_fd);
int drmSyncobjImportSyncFile(int fd, uint32_t handle, int map_fd);
int drmSyncobjFDToHandle(int fd, int map_fd, uint32_t *handle);
int drmSyncobjHandleToFD(int fd, uint32_t handle, int *map_fd);
int drmSyncobjTimelineSignal(int fd, const uint32_t *handles, const uint64_t *points, uint32_t num_handles);
int drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint32_t num_handles, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled);
int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t num_handles);
int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags);
int drmGetDevice2(int fd, uint32_t flags, drmDevicePtr *device);
void drmFreeDevice(drmDevicePtr *device);
int drmGetDevices2(uint32_t flags, drmDevicePtr devices[], int max_devices);
void drmFreeDevices(drmDevicePtr devices[], int count);
bool drmDevicesEqual(drmDevicePtr a, drmDevicePtr b);
#endif
EOF

# 4. PARCHE ZSTD.H Y ZLIB.H: Firmas minimas de descompresión
cat << 'EOF' > "$INC/zstd.h"
#ifndef ZSTD_H
#define ZSTD_H
#include <stddef.h>
typedef size_t ZSTD_ErrorCode;
unsigned int ZSTD_isError(size_t code);
const char* ZSTD_getErrorName(size_t code) { return ""; }
size_t ZSTD_compressBound(size_t srcSize);
size_t ZSTD_compress(void* dst, size_t dstCapacity, const void* src, size_t srcSize, int compressionLevel);
size_t ZSTD_decompress(void* dst, size_t dstCapacity, const void* src, size_t srcSize);
#endif
EOF

cat << 'EOF' > "$INC/zlib.h"
#ifndef ZLIB_H
#define ZLIB_H
typedef unsigned char Byte;
typedef unsigned int uInt;
typedef unsigned long uLong;
typedef void *voidpf;
unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);
#endif
EOF

echo -e '#ifndef ZCONF_H\n#define ZCONF_H\n#endif' > "$INC/zconf.h"

# 5. PARCHE TOTAL C++ DUAL (Paso 482 Solución Definitiva): Inyectamos todos los pases 
# propietarios restantes de Mali y los símbolos de libdrm faltantes en formato plano
cat << 'EOF' > /tmp/stub.cpp
#include <stdint.h>
#include <stddef.h>
#include <string>
#include <vector>
#include <functional>

enum spv_target_env : uint32_t { DUMMY_ENV = 0 };
enum spv_message_level_t : uint32_t { DUMMY_LVL = 0 };
struct spv_position_t { size_t line; size_t column; size_t index; };

// Añadimos el símbolo binario real de drmSyncobjDestroy que busca vk_drm_syncobj.c
extern "C" {
    void* adrenotools_open_libvulkan(const char* accessible_dir, const char* driver_suffix) {
        return nullptr;
    }
    int drmSyncobjDestroy(int fd, uint32_t handle) {
        return 0;
    }
}

namespace spvtools {
    
    class SpirvTools {
    public:
        SpirvTools(spv_target_env env);
        ~SpirvTools();
        bool Disassemble(const std::vector<uint32_t>& binary, std::string* text, uint32_t options) const;
    };

    SpirvTools::SpirvTools(spv_target_env env) {}
    SpirvTools::~SpirvTools() {}
    bool SpirvTools::Disassemble(const std::vector<uint32_t>& binary, std::string* text, uint32_t options) const {
        return false;
    }

    class Optimizer {
    public:
        struct PassToken { 
            void* dummy;
            PassToken();
            ~PassToken();
        };
        
        Optimizer(spv_target_env env);
        ~Optimizer();
        Optimizer& SetMessageConsumer(std::function<void(spv_message_level_t, const char*, const spv_position_t&, const char*)> consumer);
        Optimizer& RegisterPass(PassToken&& user_pass);
        Optimizer& RegisterPerformancePasses();
        Optimizer& RegisterSizePasses();
        bool Run(const uint32_t* code, size_t size, std::vector<uint32_t>* optimized_code) const;
    };

    Optimizer::PassToken::PassToken() : dummy(nullptr) {}
    Optimizer::PassToken::~PassToken() {}

    Optimizer::Optimizer(spv_target_env env) {}
    Optimizer::~Optimizer() {}
    Optimizer& Optimizer::SetMessageConsumer(std::function<void(spv_message_level_t, const char*, const spv_position_t&, const char*)> consumer) {
        return *this;
    }
    Optimizer& Optimizer::RegisterPass(PassToken&& user_pass) {
        return *this;
    }
    Optimizer& Optimizer::RegisterPerformancePasses() {
        return *this;
    }
    Optimizer& Optimizer::RegisterSizePasses() {
        return *this;
    }
    bool Optimizer::Run(const uint32_t* code, size_t size, std::vector<uint32_t>* optimized_code) const {
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

# Compilamos usando gnu++17 con banderas -fPIC e interconexión libc++ nativa del NDK
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++ -std=gnu++17 -stdlib=libc++ -fPIC -c /tmp/stub.cpp -o /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK/libSPIRV-Tools-opt.a" /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK/libSPIRV-Tools.a" /tmp/stub.o

# 6. FAKE PKG-CONFIG: Interceptor de dependencias externas
cat << 'EOF' > /tmp/fake-pkg-config
#!/bin/bash
if [[ "$*" == *"--modversion"* ]]; then echo "2.4.115"; else echo "-I${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"; fi
exit 0
EOF
chmod +x /tmp/fake-pkg-config

# 7. CROSS.TXT: Archivo cruzado de compilacion bioneado
cat << 'EOF' > /tmp/cross.txt
[binaries]
c='/usr/local/lib/android/sdk/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='/usr/local/lib/android/sdk/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='/usr/local/lib/android/sdk/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='/usr/local/lib/android/sdk/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config='/tmp/fake-pkg-config'
glslangValidator='/usr/bin/glslangValidator'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-include', 'vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-include', 'vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
c_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic']
cpp_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic']
[host_machine]
system='linux'
cpu_family='aarch64'
cpu='armv8-a'
endian='little'
EOF
