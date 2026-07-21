#!/bin/bash
set -e

LIB_NDK="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"

# 1. Objeto C++ simulado con todas las firmas de optimización SPIRV
cat << 'EOF' > /tmp/stub.cpp
#include <stdint.h>
#include <stddef.h>
#include <string>
#include <vector>
#include <functional>

extern "C" void* adrenotools_open_libvulkan(const char* a, const char* s) { return nullptr; }
extern "C" int drmSyncobjDestroy(int f, uint32_t h) { return 0; }

namespace spvtools {
    class SpirvTools {
    public:
        SpirvTools(int e); ~SpirvTools();
        bool Disassemble(const void* b, void* t, uint32_t o) const;
    };
    SpirvTools::SpirvTools(int e){} SpirvTools::~SpirvTools(){}
    bool SpirvTools::Disassemble(const void* b, void* t, uint32_t o) const { return false; }

    class Optimizer {
    public:
        struct PassToken { void* d; };
        Optimizer(int e); ~Optimizer();
        Optimizer& SetMessageConsumer(void* c); Optimizer& RegisterPass(PassToken&& p);
        Optimizer& RegisterPerformancePasses(); Optimizer& RegisterSizePasses();
        bool Run(const uint32_t* c, size_t s, void* o) const;
    };
    Optimizer::Optimizer(int e){} Optimizer::~Optimizer(){}
    Optimizer& Optimizer::SetMessageConsumer(void* c){ return *this; }
    Optimizer& Optimizer::RegisterPass(PassToken&& p){ return *this; }
    Optimizer& Optimizer::RegisterPerformancePasses(){ return *this; }
    Optimizer& Optimizer::RegisterSizePasses(){ return *this; }
    bool Optimizer::Run(const uint32_t* c, size_t s, void* o) const { return true; }

    Optimizer::PassToken CreateStripDebugInfoPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateAggressiveDCEPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateCompactIdsPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateRemoveClipCullDistPass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateFixMaliSpecConstantCompositePass() { Optimizer::PassToken t; return t; }
    Optimizer::PassToken CreateMaliOptimizationBarrierPass() { Optimizer::PassToken t; return t; }
}
EOF

# Compilamos el objeto estático con posicionamiento fPIC para ARM64
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++ -std=gnu++17 -stdlib=libc++ -fPIC -c /tmp/stub.cpp -o /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK/libSPIRV-Tools-opt.a" /tmp/stub.o
${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "$LIB_NDK/libSPIRV-Tools.a" /tmp/stub.o

# Interceptor fake-pkg-config
echo -e '#!/bin/bash\nif [[ "$*" == *"--modversion"* ]]; then echo "14.0.0"; else echo "-I/tmp"; fi\nexit 0' > /tmp/fake-pkg-config
chmod +x /tmp/fake-pkg-config

# ACOPLE DE TRADUCCIÓN: Añadimos obligatoriamente '-include', 'zlib.h' para resolver el tipo uInt al vuelo
cat << EOF > /tmp/cross.txt
[binaries]
c='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang'
cpp='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang++'
ar='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip='${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkg-config='/tmp/fake-pkg-config'
glslangValidator='/usr/bin/glslangValidator'
[built-in options]
c_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DHAVE_ZSTD=1', '-I${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include', '-include', 'zstd.h', '-include', 'zlib.h', '-include', 'vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
cpp_args=['-DHAVE_ANDROID_PLATFORM', '-DANDROID', '-DHAVE_ZSTD=1', '-I${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include', '-include', 'zstd.h', '-include', 'zlib.h', '-include', 'vk_pc_stubs.h', '-DO_RDONLY=0', '-DO_RDWR=2', '-DO_CLOEXEC=02000000', '-fvisibility=default']
c_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic']
cpp_link_args=['-llog', '-landroid', '-ldl', '-Wl,--export-dynamic']
[host_machine]
system='linux'
cpu_family='aarch64'
cpu='armv8-a'
endian='little'
EOF
