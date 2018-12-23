# ddcpuid, CPUID tool

ddcpuid is a simple and fast x86 processor information tool, works best with Intel and AMD processors where features are documentated.

I will gladly implement features from VIA, Zhaoxin, and others once I get documentation.

The ddcpuid User Manual is available [online](https://dd86k.space/docs/ddcpuid-manual.pdf) (PDF).

# Compiling

It is highly recommended to use the `-betterC` switch when compiling.

DMD, GDC, and LDC compilers are supported.

## GDC Notes

GDC support is still experimental. **Compiling above -O1 segfaults at run-time.**

## LDC 1.13.0+ on Windows

Since LDC 1.13.0 includes lld-link on Windows platforms, the project may fail to link. Using the older linker from Microsoft will likely fail as well. No work-arounds has been found up to this date other than using LDC 1.12.x.

# Default Mode Example

For more information about your processor, use the `-d` switch.

```
[Vendor] GenuineIntel
[String] Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
[Identifier] Family 6 Model 58 Stepping 9
[Extensions]  MMX  SSE  SSE2  SSE3  SSSE3  SSE4.1  SSE4.2  Intel64  VT-x (VMX)  Intel XD (NX)  Intel TXT (SMX)  AES-NI  AVX
[+Instructions]  MONITOR/MWAIT  PCLMULQDQ  CMPXCHG8B  CMPXCHG16B  RDRAND  RDMSR/WRMSR  SYSENTER/SYSEXIT  RDTSC  +TSC-Deadline  +TSC-Invariant  RDTSCP  CMOV  FCOMI/FCMOV  CLFLUSH (64 bytes)
  POPCNT  XSAVE/XRSTOR  XSETBV/XGETBV  FXSAVE/FXRSTOR

[Cache information]
        L1 Data: 32 KB
        L1 Instructions: 32 KB
        L2: 256 KB
        L3: 8 MB

[Processor features]
        Enhanced SpeedStep(R) Technology
        TurboBoost
```