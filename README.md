# ddcpuid, CPUID tool

ddcpuid is a simple x86/x86-64 processor information tool, works best with Intel and AMD processors where features are documentated.

I will gladly implement features from VIA, Zhaoxin, and others once I get documentation.

The ddcpuid User Manual is available [online](https://dd86k.space/pub/ddcpuid-manual.pdf) (PDF).

# Bugs

ddcpuid isn't perfect. If you find a bug, something is missing, or something is incorrect, please make an Issue on this repo or email me (email's on my profile). 

# Compiling

It is highly recommended to use the `-betterC` switch when compiling.

DMD, GDC, and LDC compilers are supported.

# Example

Normal mode. For more information about your processor, use the `-d` switch.
```
[Vendor] GenuineIntel
[String] Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
[Identifier] Family 6 Model 58 Stepping 9
[Extensions]
	MMX	SSE	SSE2	SSE3	SSSE3	SSE4.1	SSE4.2	Intel64	VT-x	Intel XD (NX)	Intel TXT (SMX)	AES-NI	AVX
[Other instructions]
	MONITOR/MWAIT	PCLMULQDQ	CMPXCHG8B	CMPXCHG16B	RDRAND	RDMSR/WRMSR	SYSENTER/SYSEXIT	RDTSC	+TSC-Deadline	+TSC-Invariant	RDTSCP	CMOV	FCOMI/FCMOV	CLFLUSH (64 bytes)	POPCNT	XSAVE/XRSTOR	XSETBV/XGETBV	FXSAVE/FXRSTOR

[Cache information]
	L1 Data, 32 KB
	L1 Instructions, 32 KB
	L2, 256 KB
	L3, 8 MB

[Processor features]
	Enhanced SpeedStep(R) Technology
	TurboBoost
```