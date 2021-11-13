# ddcpuid, CPUID tool

ddcpuid is a x86 processor information tool. Currently supports Intel and AMD
processors.

- Can be used as a stand-alone tool or as a DUB library.
- Fully supports DMD, GDC, and LDC.
- BetterC compatible, and used by default for the application.
- The library does not rely on any runtime (C, D) nor the OS.
- Surpasses CPU-Z, [Intel's Go CPUID](https://github.com/intel-go/cpuid/) module, and Druntime's `core.cpuid` module.
- _Currently featuring 240 CPUID bits documented and counting!_

Want to better understand x86 and their technologies? There's the
[ddcpuid Technical Manual](https://dd86k.space/docs/ddcpuid-manual.pdf) (PDF)!

Officially supports these vendors:
- `"GenuineIntel"` - Intel Corporation
- `"AuthenticAMD"` - Advanced Micro Devices Inc.
- `"KVMKVMKVM\0\0\0"` - Linux built-in Kernel Virtual Machine
- `"Microsoft Hv"` - Microsoft Hyper-V interface
- `"VBoxVBoxVBox"` - VirtualBox Hyper-V interface
- `"\0\0\0\0\0\0\0\0\0\0\0\0"` - VirtualBox minimal interface

# Command Output Examples

## On Host Computer

```
$ ddcpuid
Name:        GenuineIntel Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
Identifier:  Family 6 Model 58 Stepping 9
Cores:       4 cores 8 threads
Techs:       x86-64-v2 EIST TurboBoost Intel-TXT/SMX HTT
SSE:         SSE SSE2 SSE3 SSSE3 SSE4.1 SSE4.2
AVX:         AVX
AMX:         None
Others:      AES-NI
Mitigations: IBRS STIBP SSBD L1D_FLUSH MD_CLEAR
Cache L1-D:  4x 32KB    (128KB)
Cache L1-I:  4x 32KB    (128KB)
Cache L2-U:  4x 256KB   (1MB)
Cache L3-U:  1x 8MB     (8MB)
```

## In a Virtual Guest with 2 Cores Allocated

```
$ ddcpuid
Name:        GenuineIntel Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
Identifier:  Family 6 Model 58 Stepping 9
Cores:       2 cores 2 threads
Techs:       x86-64 HTT
SSE:         SSE SSE2 SSE3 SSSE3 SSE4.2
AVX:         AVX
AMX:         None
Others:      AES-NI
Mitigations: L1D_FLUSH MD_CLEAR
Paravirtualization: Hyper-V
Cache L1-D:  2x 32KB    (64KB)
Cache L1-I:  2x 32KB    (64KB)
Cache L2-U:  2x 256KB   (512KB)
Cache L3-U:  2x 8MB     (16MB)
```

NOTE: Yep, the total cache may be influenced by the virtual environment.

## Feature Level

```
$ ddcpuid --level
x86-64-v2
```

## CPUID Table on Host Computer

```
$ ddcpuid --table
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
- GDC >= 7.0.0 (good optimizations, see [GDC Issues](#gdc-issues))

## DUB

Using dub(1) is rather straightforward.

Once installed, navigate to the root directory of the project and to perform a
debug build, simply do: `dub build`

For a release build: `dub build -b release-nobounds`

To select a different compiler: `dub build --compiler=ldc2`

For more information, visit [this page](https://dub.pm/commandline.html).

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

## GDC Issues

### GDC and betterC

Versions earlier than 11 will not compile using `-fno-druntime` due to linking
issues: `undefined reference to '__gdc_personality_v0'`.

## LDC Issues

### Legacy stdio Definitions

On Windows, LDC versions 1.13 and 1.14 do not include
`legacy_stdio_definitions.lib` when linking, making it impossible to compile
the project using `-betterC`.
