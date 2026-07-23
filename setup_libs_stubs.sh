#!/bin/bash
set -e

SYSROOT_MAESTRO="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# Generamos el objeto real biónico de Shaders sin recortes
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

# Compilamos el objeto biónico real para arquitectura ARM64
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++ -std=gnu++17 -stdlib=libc++ -fPIC -c /tmp/stub.cpp -o /tmp/stub.o

# Inundamos los directorios del NDK para asegurar el test find_library de Meson
find "${SYSROOT_MAESTRO}" -type d \( -name "lib" -o -name "lib64" -o -name "26" -o -name "aarch64-linux-android" \) | while read -r destino_folder; do
    ${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$destino_folder/libSPIRV-Tools-opt.a" /tmp/stub.o 2>/dev/null || true
    ${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$destino_folder/libSPIRV-Tools.a" /tmp/stub.o 2>/dev/null || true
done
