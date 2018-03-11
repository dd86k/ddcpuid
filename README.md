# ddcpuid, A CPUID tool

A simple CPUID tool.

Most features from Intel and AMD are supported for x86 platforms.

Example output:
```
Vendor: GenuineIntel
String:         Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
Identifier: Family 6 Model 58 Stepping 9
Extensions:
  MMX, SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, Intel64, VT-x, Intel XD (NX), Int
el TXT (SMX), AES-NI, AVX,

Processor features
  Enhanced SpeedStep(R) Technology
  TurboBoost available
```

To get more details, use the `-d` switch.

## Compiling

You **MUST** use the `-betterC` switch.