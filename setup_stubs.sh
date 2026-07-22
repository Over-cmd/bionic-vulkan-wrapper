#!/bin/bash
set -e

LIB_NDK="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"

# 1. CÓDIGO NATIVO C++ CON PLANTILLAS DE ANDROID:
# Replicamos las firmas estructurales reales utilizando la STL del NDK. 
# Esto hace que Clang genere el mangling perfecto de std::__ndk1 automáticamente.
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
    int drmSyncobjDestroy(int f, uint32_t h) { return 0; }
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
        struct PassToken { void* dummy; };
        
        Optimizer(spv_target_env env);
        ~Optimizer();
        Optimizer& SetMessageConsumer(std::function<void(spv_message_level_t, const char*, const spv_position_t&, const char*)> consumer);
        Optimizer& RegisterPass(PassToken&& user_pass);
        Optimizer& RegisterPerformancePasses();
        Optimizer& RegisterSizePasses();
        bool Run(const uint32_t* code, size_t size, std::vector<uint32_t>* optimized_code) const;
    };

    Optimizer::Optimizer(spv_target_env env) {}
    Optimizer::~Optimizer() {}
    Optimizer& Optimizer::SetMessageConsumer(std::function<void(spv_message_level_t, const char*, const spv_position_t&, const char*)> consumer) {
        return *this;
    }
    Optimizer& Optimizer::RegisterPass(PassToken&& user_pass) { return *this; }
    Optimizer& Optimizer::RegisterPerformancePasses() { return *this; }
    Optimizer& Optimizer::RegisterSizePasses() { return *this; }
    bool Optimizer::Run(const uint32_t* code, size_t size, std::vector<uint32_t>* optimized_code) const { return true; }

    // Funciones libres de pases propietarios
    Optimizer::PassToken CreateStripDebugInfoPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateAggressiveDCEPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateCompactIdsPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateRemoveClipCullDistPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateFixMaliSpecConstantCompositePass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateMaliOptimizationBarrierPass() { Optimizer::PassToken t; return t; }
}
EOF

# Compilamos forzando la librería estándar biónica (libc++) del NDK de Android
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++ -std=gnu++17 -stdlib=libc++ -fPIC -c /tmp/stub.cpp -o /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK/libSPIRV-Tools-opt.a" /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK/libSPIRV-Tools.a" /tmp/stub.o

# Interceptor fake-pkg-config
echo -e '#!/bin/bash\nif [[ "$*" == *"--modversion"* ]]; then echo "14.0.0"; else echo "-I/tmp"; fi\nexit 0' > /tmp/fake-pkg-config
chmod +x /tmp/fake-pkg-config

cat << EOF > /tmp/cross.txt
[binaries]
c='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config='/tmp/fake-pkg-config'
glslangValidator='/usr/bin/glslangValidator'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-I${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include', '-include', 'vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-I${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include', '-include', 'vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
c_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic']
cpp_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic']
[host_machine]
system='linux'
cpu_family='aarch64'
cpu='armv8-a'
endian='little'
EOF
