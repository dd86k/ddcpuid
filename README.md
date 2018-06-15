# ddcpuid, CPUID tool

ddcpuid is a simple x86/x86-64 CPUID tool, works best with Intel and AMD processors.

I will gladly implement features from VIA, Zhaoxin, and others once I get documentation.

## Example output

```
~$ ddcpuid
Vendor: GenuineIntel
String: Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
Identifier: Family 6 Model 58 Stepping 9
Extensions: MMX, SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, Intel64, VT-x, Intel XD (NX), Intel TXT (SMX), AES-NI, AVX,

Cache
        L1 Data, 32 KB
        L1 Instructions, 32 KB
        L2, 256 KB
        L3, 8 MB

Processor technologies
        Enhanced SpeedStep(R) Technology
        TurboBoost
```

```
Vendor: AuthenticAMD
String: AMD Ryzen 5 2400G with Radeon Vega Graphics
Identifier: Family 23 Model 17 Stepping 0
Extensions: MMX, Extended MMX, SSE, SSE2, SSE3, SSSE3, SSE4.2, SSE4a, AMD64, AMD-V, AMD EVP (NX), AES-NI, AVX, AVX2,

Cache
        L1 Data, 32 KB
        L1 Instructions, 64 KB
        L2, 512 KB
        L3, 4 MB

Processor technologies
```

## Advanced mode

More information is available with the `-d` parameter.

Advanced mode is intended for developers, engineers, and the curious mind.

These include:
- Other instructions, such as RDSEED
- Advanced cache information
- High leaves
- Processor type
- Processor features, such as APCI, BMIs, Brand Index, etc.

## Erratas and inaccuracy  

ddcpuid isn't perfect. For any misleading or incorrect pieces of information, please report to this repository or via my email (on my profile). 

## Compiling

You _MUST_ use the `-betterC` switch when compiling.

Supported compilers
- DMD
- LDC