# ddcpuid, CPUID tool

A simple x86/x86-64 CPUID tool, works best with Intel and AMD processors.

I will gladly implement features from VIA and Zhaoxin once I get documention.

Example output:
```
D:\DOCUMENTS\D projects\ddcpuid>ddcpuid
Vendor: GenuineIntel
String: Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
Identifier: Family 6 Model 58 Stepping 9
            6h [6h:0h] 3Ah [Ah:3h] 9h
Extensions
  MMX, SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, Intel64, VT-x, Intel XD (NX), Intel TXT (SMX), AES-NI, AVX,

Processor technologies
  Enhanced SpeedStep(R) Technology
  TurboBoost
```

For more details, such as APCI features, use the `-d` switch.

## Compiling

You _MUST_ use the `-betterC` switch when compiling.

Supported compilers
- DMD
- LDC