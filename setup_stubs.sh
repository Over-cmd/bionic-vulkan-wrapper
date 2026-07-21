#!/bin/bash
set -e

LIB_NDK="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"

# 5. CÓDIGO OBJETO REAL DE ENLAZADO DINÁMICO: Toda la pila de emulación de símbolos C/C++
cat << 'EOF' > /tmp/stub.cpp
#include <stdint.h>
#include <stddef.h>
#include <string>
#include <vector>
#include <functional>

enum spv_target_env : uint32_t { DUMMY_ENV = 0 };
enum spv_message_level_t : uint32_t { DUMMY_LVL = 0 };
struct spv_position_t { size_t line; size_t column; size_t index; };

extern "C" {
    void* adrenotools_open_libvulkan(const char* a, const char* s) { return nullptr; }
    int drmIoctl(int fd, unsigned long request, void *arg) { return 0; }
    int drmGetCap(int fd, uint64_t capability, uint64_t *value) { return 0; }
    int drmPrimeFDToHandle(int fd, int prime_fd, uint32_t *handle) { return 0; }
    int drmSyncobjCreate(int fd, uint32_t flags, uint32_t *handle) { return 0; }
    int drmSyncobjDestroy(int fd, uint32_t handle) { return 0; }
    int drmSyncobjReset(int fd, const uint32_t *handles, uint32_t num_handles) { return 0; }
    int drmSyncobjSignal(int fd, const uint32_t *handles, uint32_t num_handles) { return 0; }
    int drmSyncobjWait(int fd, uint32_t *handles, uint32_t num_handles, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }
    int drmSyncobjExportSyncFile(int fd, uint32_t handle, int *map_fd) { return 0; }
    int drmSyncobjImportSyncFile(int fd, uint32_t handle, int map_fd) { return 0; }
    int drmSyncobjFDToHandle(int fd, int map_fd, uint32_t *handle) { return 0; }
    int drmSyncobjHandleToFD(int fd, uint32_t handle, int *map_fd) { return 0; }
    int drmSyncobjTimelineSignal(int fd, const uint32_t *handles, const uint64_t *points, uint32_t num_handles) { return 0; }
    int drmSyncobjTimelineWait(int fd, uint32_t *handles, uint64_t *points, uint32_t num_handles, int64_t timeout_nsec, uint32_t flags, uint32_t *first_signaled) { return 0; }
    int drmSyncobjQuery(int fd, const uint32_t *handles, uint64_t *points, uint32_t num_handles) { return 0; }
    int drmSyncobjTransfer(int fd, uint32_t dst_handle, uint64_t dst_point, uint32_t src_handle, uint64_t src_point, uint32_t flags) { return 0; }
    int drmGetDevice2(int fd, uint32_t flags, void* device) { return 0; }
    void drmFreeDevice(void* device) {}
    int drmGetDevices2(uint32_t flags, void* devices[], int max_devices) { return 0; }
    void drmFreeDevices(void* devices[], int count) {}
    bool drmDevicesEqual(void* a, void* b) { return true; }
}

namespace spvtools {
    class SpirvTools {
    public:
        SpirvTools(spv_target_env env); ~SpirvTools();
        bool Disassemble(const std::vector<uint32_t>& binary, std::string* text, uint32_t options) const;
    };
    SpirvTools::SpirvTools(spv_target_env env) {} SpirvTools::~SpirvTools() {}
    bool SpirvTools::Disassemble(const std::vector<uint32_t>& binary, std::string* text, uint32_t options) const { return false; }

    class Optimizer {
    public:
        struct PassToken { void* dummy; PassToken(); ~PassToken(); };
        Optimizer(spv_target_env env); ~Optimizer();
        Optimizer& SetMessageConsumer(std::function<void(spv_message_level_t, const char*, const spv_position_t&, const char*)> consumer);
        Optimizer& RegisterPass(PassToken&& user_pass); Optimizer& RegisterPerformancePasses(); Optimizer& RegisterSizePasses();
        bool Run(const uint32_t* code, size_t size, std::vector<uint32_t>* optimized_code) const;
    };
    Optimizer::PassToken::PassToken() : dummy(nullptr) {} Optimizer::PassToken::~PassToken() {}
    Optimizer::Optimizer(spv_target_env env) {} Optimizer::~Optimizer() {}
    Optimizer& Optimizer::SetMessageConsumer(std::function<void(spv_message_level_t, const char*, const spv_position_t&, const char*)> consumer) { return *this; }
    Optimizer& Optimizer::RegisterPass(PassToken&& user_pass) { return *this; }
    Optimizer& Optimizer::RegisterPerformancePasses() { return *this; }
    Optimizer& Optimizer::RegisterSizePasses() { return *this; }
    bool Optimizer::Run(const uint32_t* code, size_t size, std::vector<uint32_t>* optimized_code) const { return true; }

    Optimizer::PassToken CreateStripDebugInfoPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateAggressiveDCEPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateCompactIdsPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateRemoveClipCullDistPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateFixMaliSpecConstantCompositePass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateMaliOptimizationBarrierPass() { Optimizer::PassToken t; return t; }
}
EOF

# Compilación nativa con posicionamiento dinámico fPIC
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++ -std=gnu++17 -stdlib=libc++ -fPIC -c /tmp/stub.cpp -o /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK/libSPIRV-Tools-opt.a" /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK/libSPIRV-Tools.a" /tmp/stub.o

# 6. Interceptor fake de dependencias externas
cat << 'EOF' > /tmp/fake-pkg-config
#!/bin/bash
if [[ "$*" == *"--modversion"* ]]; then echo "2.4.115"; else echo "-I${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"; fi
exit 0
EOF
chmod +x /tmp/fake-pkg-config

# 7. Archivo de compilación cruzada para Meson
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
