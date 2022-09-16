# ddcpuid, CPUID tool

ddcpuid is a x86 processor information tool and library.

```shell
$ ddcpuid # Summary is the default mode
Name:        AuthenticAMD AMD Ryzen 9 5950X 16-Core Processor            
Identifier:  Family 0x19 Model 0x21 Stepping 0x0
Cores:       16 cores, 32 threads
Max. Memory: 256 TiB physical, 256 TiB virtual
Baseline:    x86-64-v3
Techs:       htt
Extensions:  x87/fpu +f16c mmx extmmx amd64/x86-64 +lahf64 amd-v/vmx +svm=v1 aes-ni adx sha bmi1 bmi2
SSE:         sse sse2 sse3 ssse3 sse4.2 sse4a fma3
AVX:         avx avx2
AMX:        
Mitigations: ibpb ibrs ibrs_pref stibp stibp_on ssbd
Cache L1-D:   16x   32 KiB,  512 KiB total, si
Cache L1-I:   16x   32 KiB,  512 KiB total, si
Cache L2-U:   16x  512 KiB,    8 MiB total, si ci
Cache L3-U:    2x   32 MiB,   64 MiB total, si nwbv
```

- Can be used as a stand-alone tool or as a library. DUB compatible.
- Fully supports DMD, GDC, and LDC compilers.
- BetterC compatible, and used by default for the application.
- Library does not rely on external functions (e.g., C runtime, Druntime, OS).
- Surpasses CPU-Z, [Intel's Go CPUID](https://github.com/intel-go/cpuid/) module, and Druntime's `core.cpuid` module in terms of x86-related information.
- _Currently featuring 240 CPUID bits documented and counting!_

Want to better understand x86 and their technologies? There's the
[ddcpuid Manual](https://dd86k.space/docs/ddcpuid-manual.pdf) (PDF)!

Officially supports these vendors:
- `"GenuineIntel"` - Intel Corporation
- `"AuthenticAMD"` - Advanced Micro Devices Inc.
- `"KVMKVMKVM\0\0\0"` - Linux built-in Kernel Virtual Machine
- `"Microsoft Hv"` - Microsoft Hyper-V interface
- `"VBoxVBoxVBox"` - VirtualBox Hyper-V interface
- `"\0\0\0\0\0\0\0\0\0\0\0\0"` - VirtualBox minimal interface

NOTE: Features may be influenced by the virtual environment.

# 1. Usage Examples

## 1.1. In a Virtual Guest with 2 Cores Allocated

```shell
$ ddcpuid
Name:        AuthenticAMD AMD Ryzen 9 5950X 16-Core Processor            
Identifier:  Family 0x19 Model 0x21 Stepping 0x0
Cores:       1 core, 2 threads
Max. Memory: 256 TiB physical, 256 TiB virtual
Baseline:    x86-64
Techs:       htt
Extensions:  x87/fpu mmx extmmx amd64/x86-64 +lahf64 amd-v/vmx +svm=v1 aes-ni
SSE:         sse sse2 sse3 ssse3 sse4.2 sse4a
AVX:         avx avx2
AMX:         None
Mitigations:
ParaVirt.:   KVM
Cache L1-D:    1x   32 KiB,   32 KiB total, si
Cache L1-I:    1x   32 KiB,   32 KiB total, si
Cache L2-U:    1x  512 KiB,  512 KiB total, si ci
Cache L3-U:    1x   32 MiB,   32 MiB total, si nwbv
```

## 1.2. Baseline

While displayed in the default operating mode, the `--baseline` option
can be useful in compiltation scripts.

WARNING: This depends on the capabilities of the processor regardless
of the operating system. Results may vary.

WARNING: The compilation baseline for DMD and LDC is the Pentium Pro (i686).
No guaranties are given for detecting i486 and i586 family processors.

### Example

```
$ ddcpuid --baseline
x86-64-v3
```

### Values

| Machine | Values |
|---|---|
| 32-bit | `i486`, `i586`, or `i686` |
| 64-bit | `x86-64`, `x86-64-v2`, `x86-64-v3`, or `x86-64-v4` |

## 1.3. Raw CPUID Table on Host Computer

```
$ ddcpuid --raw
| Leaf     | Sub-leaf | EAX      | EBX      | ECX      | EDX      |
|----------|----------|----------|----------|----------|----------|
|        0 |        0 |       10 | 68747541 | 444d4163 | 69746e65 |
|        1 |        0 |   a20f10 | 1d200800 | 7ed8320b | 178bfbff |
|        2 |        0 |        0 |        0 |        0 |        0 |
|        3 |        0 |        0 |        0 |        0 |        0 |
|        4 |        0 |        0 |        0 |        0 |        0 |
|        5 |        0 |       40 |       40 |        3 |       11 |
|        6 |        0 |        4 |        0 |        1 |        0 |
|        7 |        0 |        0 | 219c97a9 |   40069c |       10 |
|        8 |        0 |        0 |        0 |        0 |        0 |
|        9 |        0 |        0 |        0 |        0 |        0 |
|        a |        0 |        0 |        0 |        0 |        0 |
|        b |        0 |        1 |        2 |      100 |       1d |
|        c |        0 |        0 |        0 |        0 |        0 |
|        d |        0 |      207 |      988 |      988 |        0 |
|        e |        0 |        0 |        0 |        0 |        0 |
|        f |        0 |        0 |       ff |        0 |        2 |
|       10 |        0 |        0 |        2 |        0 |        0 |
| 80000000 |        0 | 80000023 | 68747541 | 444d4163 | 69746e65 |
| 80000001 |        0 |   a20f10 | 20000000 | 75c237ff | 2fd3fbff |
| 80000002 |        0 | 20444d41 | 657a7952 | 2039206e | 30353935 |
| 80000003 |        0 | 36312058 | 726f432d | 72502065 | 7365636f |
| 80000004 |        0 | 20726f73 | 20202020 | 20202020 |   202020 |
| 80000005 |        0 | ff40ff40 | ff40ff40 | 20080140 | 20080140 |
| 80000006 |        0 | 48002200 | 68004200 |  2006140 |  2009140 |
| 80000007 |        0 |        0 |       3b |        0 |     6799 |
| 80000008 |        0 |     3030 | 111ef657 |     501f |    10000 |
| 80000009 |        0 |        0 |        0 |        0 |        0 |
| 8000000a |        0 |        1 |     8000 |        0 | 101bbcff |
| 8000000b |        0 |        0 |        0 |        0 |        0 |
| 8000000c |        0 |        0 |        0 |        0 |        0 |
| 8000000d |        0 |        0 |        0 |        0 |        0 |
| 8000000e |        0 |        0 |        0 |        0 |        0 |
| 8000000f |        0 |        0 |        0 |        0 |        0 |
| 80000010 |        0 |        0 |        0 |        0 |        0 |
| 80000011 |        0 |        0 |        0 |        0 |        0 |
| 80000012 |        0 |        0 |        0 |        0 |        0 |
| 80000013 |        0 |        0 |        0 |        0 |        0 |
| 80000014 |        0 |        0 |        0 |        0 |        0 |
| 80000015 |        0 |        0 |        0 |        0 |        0 |
| 80000016 |        0 |        0 |        0 |        0 |        0 |
| 80000017 |        0 |        0 |        0 |        0 |        0 |
| 80000018 |        0 |        0 |        0 |        0 |        0 |
| 80000019 |        0 | f040f040 | f0400000 |        0 |        0 |
| 8000001a |        0 |        6 |        0 |        0 |        0 |
| 8000001b |        0 |      3ff |        0 |        0 |        0 |
| 8000001c |        0 |        0 |        0 |        0 |        0 |
| 8000001d |        0 |     4121 |  1c0003f |       3f |        0 |
| 8000001e |        0 |       1d |      10e |        0 |        0 |
| 8000001f |        0 |    1780f |      173 |      1fd |        1 |
| 80000020 |        0 |        0 |        2 |        0 |        0 |
| 80000021 |        0 |       4d |        0 |        0 |        0 |
| 80000022 |        0 |        0 |        0 |        0 |        0 |
| 80000023 |        0 |        0 |        0 |        0 |        0 |
```

## 1.4. All Information Output

For more information in the fashion of Linux's `/proc/cpuinfo`,
use the `-a` or `--all` switches. Warning, this really outputs a lot of
information!

This mode really includes all processor information, including paravirtualization
features and Hyper-V's extremely long list of feature bits, if detected.

# 2. Compiling

The best way to compile ddcpuid is by using DUB.

Compilers supported:
- DMD >= 2.068.0 (best supported)
  - For earlier versions (tested on dmd 2.067.1), see [manual compilation](#23-manually).
- LDC >= 1.0.0 (best optimizations, see [LDC Issues](#25-ldc-issues))
  - For 0.17.1, see how to perform a [manual compilation](#23-manually).
- GDC >= 7.0.0 (good optimizations, see [GDC Issues](#24-gdc-issues))

## 2.1. DUB

Using dub(1) is rather straightforward.

Recommended builds for releases:
- DMD: `dub build -b release-nobounds --compiler=dmd`
- GDC: `dub build -b release-nobounds-gdc --compiler=gdc`
  - For GDC <=10: `dub build -b release-nobounds --compiler=gdc`
- LDC: `dub build -b release-nobounds --compiler=ldc2`

For more information how to use DUB, visit [this page](https://dub.pm/commandline.html).

## 2.2. Makefile

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

## 2.3. Manually

Since ddcpuid only consists of two source files, both being in the `src`
folder, it's still pretty simple to perform a compilation by hand.

Here's an example that works on any compiler:
```
dmd src/ddcpuid.d src/main.d -ofddcpuid
ldc2 src/ddcpuid.d src/main.d -ofddcpuid
gdc src/ddcpuid.d src/main.d -oddcpuid
```

If you want an optimized build:
```
dmd -betterC -release -O -boundscheck=off src/ddcpuid.d src/main.d -oddcpuid
ldc2 -betterC -release -O -boundscheck=off src/ddcpuid.d src/main.d -oddcpuid
gdc -fno-druntime -release -O -fbounds-check=off src/ddcpuid.d src/main.d -oddcpuid
```

You get the idea.

## 2.4. GDC Issues

### 2.4.1. GDC and betterC

Versions earlier than 11 will not compile using `-fno-druntime` due to linking
issues: `undefined reference to '__gdc_personality_v0'`.

## 2.5. LDC Issues

### 2.5.1. Legacy stdio Definitions

On Windows, LDC versions 1.13 and 1.14 do not include
`legacy_stdio_definitions.lib` when linking, making it impossible to compile
the project using `-betterC`.
