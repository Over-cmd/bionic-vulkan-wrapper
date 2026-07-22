#!/bin/bash
set -e

LIB_NDK="${ANDROID_SDK_ROOT}/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/26"

# 1. Objeto C++ simulado con el mapa de símbolos decorados exacto (Mangled Names) que pide el linker del NDK
cat << 'EOF' > /tmp/stub.cpp
#include <stdint.h>
#include <stddef.h>

extern "C" {
    // Símbolo de Adrenotools exigido
    void* adrenotools_open_libvulkan(const char* a, const char* s) { return nullptr; }
    int drmSyncobjDestroy(int f, uint32_t h) { return 0; }

    #define FAKE_STUB(name) void name() {}
    #define FAKE_STUB_RET(name, type, val) type name() { return val; }

    // Funciones esqueleto base para el desvío de optimizaciones
    FAKE_STUB(fake_spv_ctor)
    FAKE_STUB(fake_spv_dtor)
    FAKE_STUB_RET(fake_spv_disasm, bool, false)
    FAKE_STUB(fake_opt_ctor)
    FAKE_STUB(fake_opt_dtor)
    FAKE_STUB_RET(fake_opt_consumer, void*, nullptr)
    FAKE_STUB_RET(fake_opt_pass, void*, nullptr)
    FAKE_STUB_RET(fake_opt_perf, void*, nullptr)
    FAKE_STUB_RET(fake_opt_size, void*, nullptr)
    FAKE_STUB_RET(fake_opt_run, bool, true)
    FAKE_STUB(fake_pass_token)

    // Enlazamos de forma inapelable las firmas decoradas oficiales de C++ del NDK 25 usando alias de LLVM
    void _ZN8spvtools10SpirvToolsC1E14spv_target_env(void* thiz, int env) __attribute__((alias("fake_spv_ctor")));
    void _ZN8spvtools10SpirvToolsD1Ev(void* thiz) __attribute__((alias("fake_spv_dtor")));
    bool _ZNK8spvtools10SpirvTools11DisassembleERKSt6vectorIjSaIjEEPNSt3__ndk112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEEj(void* thiz, const void* b, void* t, uint32_t o) __attribute__((alias("fake_spv_disasm")));
    
    void _ZN8spvtools9OptimizerC1E14spv_target_env(void* thiz, int env) __attribute__((alias("fake_opt_ctor")));
    void _ZN8spvtools9OptimizerD1Ev(void* thiz) __attribute__((alias("fake_opt_dtor")));
    void* _ZN8spvtools9Optimizer11RegisterPassEONS0_11PassTokenE(void* thiz, void* p) __attribute__((alias("fake_opt_pass")));
    void* _ZN8spvtools9Optimizer24RegisterPerformancePassesEv(void* thiz) __attribute__((alias("fake_opt_perf")));
    void* _ZN8spvtools9Optimizer19RegisterSizePassesEv(void* thiz) __attribute__((alias("fake_opt_size")));
    void* _ZN8spvtools9Optimizer18SetMessageConsumerENSt3__ndk18functionIFv18spv_message_level_tPKcRK14spv_position_tS4_EEE(void* thiz, void* c) __attribute__((alias("fake_opt_consumer")));
    bool _ZNK8spvtools9Optimizer3RunEPKjmPSt6vectorIjSaIjEE(void* thiz, const uint32_t* c, size_t s, void* o) __attribute__((alias("fake_opt_run")));
    
    void _ZN8spvtools9Optimizer9PassTokenD1Ev(void* thiz) __attribute__((alias("fake_pass_token")));
    void _ZN8spvtools9Optimizer9PassTokenC1Ev(void* thiz) __attribute__((alias("fake_pass_token")));

    void _ZN8spvtools23CreateStripDebugInfoPassEv() __attribute__((alias("fake_pass_token")));
    void _ZN8spvtools23CreateAggressiveDCEPassEv() __attribute__((alias("fake_pass_token")));
    void _ZN8spvtools21CreateCompactIdsPassEv() __attribute__((alias("fake_pass_token")));
    void _ZN8spvtools28CreateRemoveClipCullDistPassEv() __attribute__((alias("fake_pass_token")));
    void _ZN8spvtools42CreateFixMaliSpecConstantCompositePassEv() __attribute__((alias("fake_pass_token")));
    void _ZN8spvtools35CreateMaliOptimizationBarrierPassEv() __attribute__((alias("fake_pass_token")));
}
EOF

# Compilamos el mapa plano con flags de soporte compartido -fPIC
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
