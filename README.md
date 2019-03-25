# ddcpuid, CPUID tool

ddcpuid is a simple and fast x86 processor information tool, works best with Intel and AMD processors where features are documentated.

I will gladly implement features from VIA, Zhaoxin, and others once I get documentation.

The ddcpuid User Manual is available [online](https://dd86k.space/docs/ddcpuid-manual.pdf) (PDF).

# Compiling

It is highly recommended to use the `-betterC` switch when compiling.

DMD, GDC, and LDC compilers are supported.

## GDC Notes

GDC support is still experimental. **Compiling above -O1 segfaults at run-time.**

## LDC Notes

Since LDC 1.13.0 includes lld-link on Windows platforms, the project may fail to link. Using the older linker from Microsoft will likely fail as well. No work-arounds has been found up to this date other than using LDC 1.12.x. **NOTE:** This has been fixed in 1.15.

Recent versions of LDC (tested on 1.8.0 and 1.15) may "over-optimize" the hleaf function (when compiling with -O), and while it's supposed to return the highest cpuid leaf, it may return 0. To test such situation, use the -r switch and see if the condition applies.

# Default Mode Example

```
[Vendor] GenuineIntel
[String] Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
[Identifier] Family 6 (6h) [6h:0h] Model 58 (3Ah) [Ah:3h] Stepping 9
[Extensions] x87/FPU F16C MMX SSE SSE2 SSE3 SSSE3 SSE4.1 SSE4.2 Intel64/x86-64 VT-x/VMX Intel-XD/NX
Intel-TXT/SMX AES-NI AVX
[Extra] MONITOR+MWAIT PCLMULQDQ CMPXCHG8B CMPXCHG16B RDRAND RDMSR+WRMSR SYSENTER+SYSEXIT RDTSC +TSC-Deadline +TSC-Invariant RDTSCP CMOV FCOMI+FCMOV CLFLUSH:64B POPCNT XSAVE+XRSTOR XSETBV+XGETBV FXSAVE+FXRSTOR
[Technologies] Enhanced-SpeedStep TurboBoost

[Cache information]
        L1-D: 32 KB
        L1-I: 32 KB
        L2-U: 256 KB
        L3-U: 8 MB
```

For more details about your processor, use the `-d` switch.