# ddcpuid, CPUID tool

ddcpuid is a x86 processor information tool. Currently supports Intel and AMD
processors.

- Can be used as a stand-alone tool or as a DUB library.
- BetterC compatible, and used by default.
- The library does not rely on any runtime (C, D) nor the OS.
- Surpasses CPU-Z, [Intel's Go CPUID](https://github.com/intel-go/cpuid/) module, and Druntime's `core.cpuid` module.
- _Currently featuring 240 CPUID bits documented and counting!_

Want to better understand x86? There's the
[ddcpuid Technical Manual](https://dd86k.space/docs/ddcpuid-manual.pdf) (PDF)!

# Command Output Examples

## On Host Computer

```
Vendor      : GenuineIntel
Brand       : Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
Identifier  : Family 6 (0x6) [0x6:0x0] Model 58 (0x3a) [0xa:0x3] Stepping 9
Cores       : 8 threads
Extensions  : x87/FPU +F16C MMX SSE SSE2 SSE3 SSSE3 SSE4.1 SSE4.2 Intel64/x86-64 +LAHF64 VT-x/VMX AES-NI AVX
Extra       : MONITOR+MWAIT +MIN=64 +MAX=64 PCLMULQDQ CMPXCHG8B CMPXCHG16B RDRAND RDMSR+WRMSR SYSENTER+SYSEXIT SYSCALL+SYSRET RDTSC +TSC-Deadline +TSC-Invariant RDTSCP CMOV FCOMI+FCMOV POPCNT XSAVE+XRSTOR XSETBV+XGETBV FXSAVE+FXRSTOR
Technologies: EIST TurboBoost Intel-TXT/SMX HTT
Cache       : CLFLUSH=64B SS
        L1-D: 4x   32 KiB, 8 ways, 1 parts, 64 B, 64 sets +SI
        L1-I: 4x   32 KiB, 8 ways, 1 parts, 64 B, 64 sets +SI
        L2-U: 4x  256 KiB, 8 ways, 1 parts, 64 B, 512 sets +SI
        L3-U: 1x    8 MiB, 16 ways, 1 parts, 64 B, 8192 sets +SI +CI +CCI
ACPI        : ACPI APIC x2APIC ARAT TM TM2 APIC-ID=6 MAX-ID=16
Virtual     : VME
Memory      : P-Bits=36 L-Bits=48 PAE PSE PSE-36 Intel-XD/NX PAT MTRR PGE SMEP
Debugging   : MCA MCE DE DS DS-CPL DTES64 PDCM PBE
Security    : IBRS STIBP SSBD L1D_FLUSH MD_CLEAR
Misc.       : HLeaf=0xd HVLeaf=0x0 HELeaf=0x80000008 Type=Original Index=0 xTPR PCID FSGSBASE
```

## In Virtual Environment

```
Vendor      : GenuineIntel
Brand       : Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
Identifier  : Family 6 (0x6) [0x6:0x0] Model 58 (0x3a) [0xa:0x3] Stepping 9
Cores       : 2 threads
Extensions  : x87/FPU MMX SSE SSE2 SSE3 SSSE3 SSE4.2 Intel64/x86-64 +LAHF64 AES-NI AVX
Extra       : PCLMULQDQ CMPXCHG8B CMPXCHG16B RDRAND RDMSR+WRMSR SYSENTER+SYSEXIT SYSCALL+SYSRET RDTSC +TSC-Invariant RDTSCP CMOV FCOMI+FCMOV POPCNT XSAVE+XRSTOR XSETBV+XGETBV FXSAVE+FXRSTOR
Technologies: HTT
Cache       : CLFLUSH=64B
	L1-D: 2x   32 KiB, 8 ways, 1 parts, 64 B, 64 sets +SI
	L1-I: 2x   32 KiB, 8 ways, 1 parts, 64 B, 64 sets +SI
	L2-U: 2x  256 KiB, 8 ways, 1 parts, 64 B, 512 sets +SI
	L3-U: 2x    8 MiB, 16 ways, 1 parts, 64 B, 8192 sets +SI +CI +CCI
ACPI        : APIC x2APIC APIC-ID=1 MAX-ID=2
Virtual     : VME HOST=KVMKVMKVM KVM_FEATURE_CLOCKSOURCE KVM_FEATURE_CLOCKSOURCE2 KVM_FEATURE_PV_UNHAULT KVM_FEATURE_CLOCSOURCE_STABLE_BIT
Memory      : P-Bits=36 L-Bits=48 PAE PSE PSE-36 Intel-XD/NX PAT MTRR PGE
Debugging   : MCA MCE DE
Security    : L1D_FLUSH MD_CLEAR
Misc.       : HLeaf=0xd HVLeaf=0x40000001 HELeaf=0x80000008 Type=Original Index=0 PCID FSGSBASE
```

## CPUID Table on Host Computer

```
| Leaf     | Sub-leaf | EAX      | EBX      | ECX      | EDX      |
|----------|----------|----------|----------|----------|----------|
|        0 |        0 |        d | 756e6547 | 6c65746e | 49656e69 |
|        1 |        0 |    306a9 |  3100800 | 7fbae3ff | bfebfbff |
|        2 |        0 | 76035a01 |   f0b2ff |        0 |   ca0000 |
|        3 |        0 |        0 |        0 |        0 |        0 |
|        4 |        0 | 1c004121 |  1c0003f |       3f |        0 |
|        5 |        0 |       40 |       40 |        3 |     1120 |
|        6 |        0 |       77 |        2 |        9 |        0 |
|        7 |        0 |        0 |      281 |        0 | 9c000400 |
|        8 |        0 |        0 |        0 |        0 |        0 |
|        9 |        0 |        0 |        0 |        0 |        0 |
|        a |        0 |  7300403 |        0 |        0 |      603 |
|        b |        0 |        1 |        2 |      100 |        0 |
|        c |        0 |        0 |        0 |        0 |        0 |
|        d |        0 |        7 |      340 |      340 |        0 |
| 80000000 |        0 | 80000008 |        0 |        0 |        0 |
| 80000001 |        0 |        0 |        0 |        1 | 28100800 |
| 80000002 |        0 | 20202020 | 20202020 | 65746e49 | 2952286c |
| 80000003 |        0 | 726f4320 | 4d542865 | 37692029 | 3737332d |
| 80000004 |        0 | 50432030 | 20402055 | 30342e33 |   7a4847 |
| 80000005 |        0 |        0 |        0 |        0 |        0 |
| 80000006 |        0 |        0 |        0 |  1006040 |        0 |
| 80000007 |        0 |        0 |        0 |        0 |      100 |
| 80000008 |        0 |     3024 |        0 |        0 |        0 |
```

# Compiling

The best way to compile ddcpuid is using DUB.

Compilers supported:
- DMD >= 2.068.0 (best supported)
  - For earlier versions (tested on dmd 2.067.1), see [manual compilation](#manually).
- LDC >= 1.0.0 (best optimizations, see [LDC Issues](#ldc-issues))
  - For 0.17.1, see how to perform a [manual compilation](#manually).
- GDC >= 9.0.0 (good optimizations, see [GDC Issues](#gdc-issues))

## DUB

Using dub(1) is rather straightforward.

To learn how to use DUB, visit [this page](https://dub.pm/commandline.html).

## Makefile

The Makefile relies on GNU Make (gmake/gnumake).

Available variables:
- `DC`: D compiler, defaults to `dmd`
- `PREFIX`: installation path prefix, defaults to `/usr/local`

Available actions:
- debug (default)
- release
- install
- uninstall

Examples:
- `make`: Produce a debug build
- `make release DC=ldc`: Produce a release build with LDC

## Manually

Since ddcpuid only consists of two source files, both being in the `src`
folder, it's still pretty easy to perform a compilation by hand.

Here's an example that works on any compiler:
```
dmd src/ddcpuid.d src/main.d -ofddcpuid
ldc2 src/ddcpuid.d src/main.d -ofddcpuid
gdc src/ddcpuid.d src/main.d -oddcpuid
```

You get the idea.

## GDC Issues

### Optimizations

**UPDATE**: ddcpuid 0.18.0 is now fully compatible with GDC. No longer an issue!

Compiling above O0 will yield invalid results, and that's because of my
incapability to understand the complex extended GCC inline assembler
format. Especially since D has no `volatile` type qualifier.

Tests:
- 8.4.0: Early runtime crash with -O1 and higher optimization levels.
- 9.3.0: Runtime crash + incorrect information with -O1 and higher optimization levels.
- 10.2.0: Same as 9.3.

## LDC Issues

### Legacy stdio Definitions

On Windows, LDC versions 1.13 and 1.14 do not include
`legacy_stdio_definitions.lib`, making it impossible to compile the project
using `-betterC`.
