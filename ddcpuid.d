extern (C) {
	int strcmp(scope const char* s1, scope const char* s2);
	int printf(scope const char* format, ...);
	int puts(scope const char* s);
}

enum VERSION = "0.7.1"; /// Program version

enum
	MAX_LEAF = 0x20, /// Maximum leaf (-o)
	MAX_ELEAF = 0x8000_0020; /// Maximum extended leaf (-o)

// UPDATE 2018-02-22: These were used to compare vendors, see enum below
/*enum : immutable(char)* { // Vendor strings
	VENDOR_INTEL     = "GenuineIntel", /// Intel
	VENDOR_AMD       = "AuthenticAMD", /// AMD
	VENDOR_VIA       = "VIA VIA VIA ", /// VIA
	// Unseen from my eyes
	VENDOR_CENTAUR   = "CentaurHauls", /// Centaur (VIA)
	VENDOR_TRANSMETA = "GenuineTMx86", /// Transmeta
	VENDOR_CYRIX     = "CyrixInstead", /// Cyrix
	VENDOR_NEXGEN    = "NexGenDriven", /// Nexgen
	VENDOR_UMC       = "UMC UMC UMC ", /// UMC
	VENDOR_SIS       = "SiS SiS SiS ", /// SiS
	VENDOR_NSC       = "Geode by NSC", /// Geode
	VENDOR_RISE      = "RiseRiseRise", /// Rise
	VENDOR_VORTEX    = "Vortex86 SoC", /// Vortex
	VENDOR_NS        = "Geode by NSC", /// National Semiconductor
	// Older vendor strings
	VENDOR_OLDAMD       = "AMDisbetter!", /// Early K5 AMD string
	VENDOR_OLDTRANSMETA = "TransmetaCPU", /// Old Transmeta string
	// Virtual Machines (rare)
	VENDOR_VMWARE       = "VMwareVMware", /// VMware
	VENDOR_XENHVM       = "XenVMMXenVMM", /// Xen VMM
	VENDOR_MICROSOFT_HV = "Microsoft Hv", /// Microsoft Hyper-V
	VENDOR_PARALLELS    = " lrpepyh  vr"  /// Parallels
}*/

/*
 * Self-made vendor "IDs" for faster look-ups, LSB-based.
 * These are the first four bytes of the vendor. If even the four first bytes
 * re-appear in another vendor, get the next four bytes.
 */
enum : uint { // LSB
	VENDOR_OTHER	= 0, // Or unknown
	VENDOR_INTEL	= 0x756e6547, // "Genu"
	VENDOR_AMD	= 0x68747541, // "Auth"
	VENDOR_VIA	= 0x20414956 // "VIA "
}
__gshared uint VendorID; /// Vendor "ID", inits to VENDOR_OTHER

__gshared byte Raw; /// Raw option (-r)
__gshared byte Details; /// Detailed output option (-d)
__gshared byte Override; /// Override max leaf option (-o)

extern (C) void help() {
	puts(
`CPUID information tool
  Usage: ddcpuid [OPTIONS]

OPTIONS
  -d    Show more, detailed information
  -r    Only show raw CPUID data
  -o    Override leaves, only useful with -r
        Respectively to 20h and 8000_0020h

  -v, --version   Print version information
  -h, --help      Print this help screen`
	);
}

extern (C) void _version() {
	printf(
`ddcpuid v` ~ VERSION ~ ` (` ~ __TIMESTAMP__ ~ `)
Copyright (c) dd86k 2016-2018
License: MIT License <http://opensource.org/licenses/MIT>
Project page: <https://github.com/dd86k/ddcpuid>
Compiler: ` ~ __VENDOR__ ~ " v%d\n",
		__VERSION__
	);
}

//TODO: Add AMD Fn8000_001F_EAX
//      SVM version

extern (C) int main(int argc, char** argv) {
	while (--argc >= 1) {
		if (argv[argc][1] == '-') { // Long arguments
			char* a = argv[argc] + 2;
			if (strcmp(a, "help") == 0) {
				help; return 0;
			}
			if (strcmp(a, "version") == 0) {
				_version; return 0;
			}
			printf("Unknown parameter: %s\n", a);
			return 1;
		} else if (argv[argc][0] == '-') { // Short arguments
			char* a = argv[argc];
			while (*++a != 0) {
				switch (*a) {
				case 'o': ++Override; break;
				case 'd': ++Details; break;
				case 'r': ++Raw; break;
				case 'h', '?': help; return 0;
				case 'v': _version; return 0;
				default:
					printf("Unknown parameter: %c\n", *a);
					return 1;
				} // switch
			} // while
		} // else if
	} // while arg

	if (Override) {
		MaximumLeaf = MAX_LEAF;
		MaximumExtendedLeaf = MAX_ELEAF;
	} else {
		MaximumLeaf = hleaf;
		MaximumExtendedLeaf = heleaf;
	}

	if (Raw) { // -r
		puts(
			"| Leaf     | EAX      | EBX      | ECX      | EDX      |\n"~
			"|----------|----------|----------|----------|----------|"
		);
		uint l;
		do {
			printc(l);
		} while (++l <= MaximumLeaf);
		l = 0x8000_0000; // Extended minimum
		do {
			printc(l);
		} while (++l <= MaximumExtendedLeaf);
		return 0;
	}

	debug printf("[L%04d] Fetching info...\n", __LINE__);

	fetchInfo;

	char* cstring = cast(char*)cpuString;

	switch (VendorID) {
	case VENDOR_INTEL: // Common in Intel processor brand strings
		while (*cstring == ' ') ++cstring; // left trim cpu string
		break;
	default:
	}

	// -- Processor basic information --

	printf(
		"Vendor: %s\n" ~
		"String: %s\n",
		cast(char*)vendorString, cstring
	);

	if (Details)
		printf(
			"Identifier: Family %Xh [%Xh:%Xh] Model %Xh [%Xh:%Xh] Stepping %Xh\n",
			Family, BaseFamily, ExtendedFamily,
			Model, BaseModel, ExtendedModel,
			Stepping
		);
	else
		printf(
			"Identifier: Family %d Model %d Stepping %d\n",
			Family, Model, Stepping
		);
	
	// -- Processor extensions --

	printf("Extensions: ");
	if (MMX) printf("MMX, ");
	if (MMXExt) printf("Extended MMX, ");
	if (_3DNow) printf("3DNow!, ");
	if (_3DNowExt) printf("Extended 3DNow!, ");
	if (SSE) printf("SSE, ");
	if (SSE2) printf("SSE2, ");
	if (SSE3) printf("SSE3, ");
	if (SSSE3) printf("SSSE3, ");
	if (SSE41) printf("SSE4.1, ");
	if (SSE42) printf("SSE4.2, ");
	if (SSE4a) printf("SSE4a, ");
	if (LongMode)
		switch (VendorID) {
		case VENDOR_INTEL: printf("Intel64, "); break;
		case VENDOR_AMD: printf("AMD64, "); break;
		default: printf("x86-64, "); break;
		}
	if (Virt)
		switch (VendorID) {
		case VENDOR_INTEL: printf("VT-x, "); break; // VMX
		case VENDOR_AMD: printf("AMD-V, "); break; // SVM
		case VENDOR_VIA: printf("VIA VT, "); break;
		default: printf("VMX, "); break;
		}
	if (NX)
		switch (VendorID) {
		case VENDOR_INTEL: printf("Intel XD (NX), "); break;
		case VENDOR_AMD: printf("AMD EVP (NX), "); break;
		default: printf("NX, "); break;
		}
	if (SMX) printf("Intel TXT (SMX), ");
	if (AES) printf("AES-NI, ");
	if (AVX) printf("AVX, ");
	if (AVX2) printf("AVX2, ");

	// -- Other instructions --

	if (Details) {
		printf("\nOther instructions: ");
		if (MONITOR)
			printf("MONITOR/MWAIT, ");
		if (PCLMULQDQ)
			printf("PCLMULQDQ, ");
		if (CX8)
			printf("CMPXCHG8B, ");
		if (CMPXCHG16B)
			printf("CMPXCHG16B, ");
		if (MOVBE)
			printf("MOVBE, "); // Intel Atom and quite a few AMD processors.
		if (RDRAND)
			printf("RDRAND, ");
		if (RDSEED)
			printf("RDSEED, ");
		if (MSR)
			printf("RDMSR/WRMSR, ");
		if (SEP)
			printf("SYSENTER/SYSEXIT, ");
		if (TSC) {
			printf("RDTSC");
			if (TscDeadline)
				printf(" +TSC-Deadline");
			if (TscInvariant)
				printf(" +TSC-Invariant");
			printf(", ");
		}
		if (CMOV)
			printf("CMOV, ");
		if (FPU && CMOV)
			printf("FCOMI/FCMOV, ");
		if (CLFSH)
			printf("CLFLUSH (%d bytes), ", CLFLUSHLineSize * 8);
		if (PREFETCHW)
			printf("PREFETCHW, ");
		if (LZCNT)
			printf("LZCNT, ");
		if (POPCNT)
			printf("POPCNT, ");
		if (XSAVE)
			printf("XSAVE/XRSTOR, ");
		if (OSXSAVE)
			printf("XSETBV/XGETBV, ");
		if (FXSR)
			printf("FXSAVE/FXRSTOR, ");
		if (FMA || FMA4) {
			printf("VFMADDx (FMA");
			if (FMA4) printf("4");
			printf("), ");
		}
		if (RDPID)
			printf("RDPID, ");
	}

	// -- Cache information --

	puts("\n\nCache information");

	extern (C) immutable(char)* _ct(ubyte t) {
		switch (t) {
		case 1: return " Data";
		case 2: return " Instructions";
		default: return "";
		}
	}

	Cache* ca = cast(Cache*)cache; /// Cache levels
	
	if (Details) {
		while (ca.type) {
			printf(
				"\tL%d%s, %d ways, %d partitions, %d B, %d sets\n",
				ca.level, _ct(ca.type), ca.ways, ca.partitions, ca.linesize, ca.sets
			);
			if (ca.features & BIT!(0)) puts("\t\tSelf Initializing");
			if (ca.features & BIT!(1)) puts("\t\tFully Associative");
			if (ca.features & BIT!(2)) puts("\t\tNo Write-Back Validation");
			if (ca.features & BIT!(3)) puts("\t\tCache Inclusive");
			if (ca.features & BIT!(4)) puts("\t\tComplex Cache Indexing");
			++ca;
		}
	} else {
		while (ca.type) {
			char s = 'K';
			uint cs = ca.size / 1024; // cache size
			if (cs >= 1024) {
				cs /= 1024; s = 'M';
			}
			printf(
				"\tL%d%s, %d %cB\n",
				ca.level, _ct(ca.type), cs, s
			);
			++ca;
		}
	}

	// -- Vendor specific features ---

	puts("\nProcessor technologies");

	switch (VendorID) {
	case VENDOR_INTEL:
		if (EIST)
			puts("\tEnhanced SpeedStep(R) Technology");
		if (TurboBoost) {
			printf("\tTurboBoost");
			if (TurboBoost3)
				puts(" 3.0");
			else
				printf("\n");
		}
		break;
	case VENDOR_AMD:
		if (TurboBoost)
			puts("\tCore Performance Boost");
		break;
	default:
	}

	if (Details == 0) return 0;

	// -- Processor detailed features --

	extern (C) immutable(char)* _pt() { // Forgive me
		switch (ProcessorType) { // 2 bit value
		case 0: return "Original OEM Processor";
		case 1: return "Intel OverDrive Processor";
		case 2: return "Dual processor";
		case 3: return "Intel reserved";
		default: return cast(char*)0; // impossible to reach anyway
		}
	}

	printf( // Misc. and FPU
		"\nHighest Leaf: %XH | Extended: %XH\n" ~
		"Processor type: %s\n" ~
		"\nFPU\n" ~
		"\tFloating Point Unit [FPU]: %s\n" ~
		"\t16-bit conversion [F16]: %s\n",
		MaximumLeaf, MaximumExtendedLeaf,
		_pt,
		B(FPU),
		B(F16C)
	);

	printf( // APCI
		"\nACPI\n" ~
		"\tACPI: %s\n" ~
		"\tAPIC: %s (Initial ID: %d, Max: %d)\n" ~
		"\tx2APIC: %s\n" ~
		"\tThermal Monitor: %s\n" ~
		"\tThermal Monitor 2: %s\n",
		B(APCI),
		B(APIC), InitialAPICID, MaxIDs,
		B(x2APIC),
		B(TM),
		B(TM2)
	);

	printf( // Virtualization
		"\nVirtualization\n" ~
		"\tVirtual 8086 Mode Enhancements [VME]: %s\n",
		B(VME)
	);

	printf( // Memory
		"\nMemory and Paging\n" ~
		"\tPage Size Extension [PAE]: %s\n" ~
		"\t36-Bit Page Size Extension [PSE-36]: %s\n" ~
		"\t1 GB Pages support [Page1GB]: %s\n" ~
		"\tDirect Cache Access [DCA]: %s\n" ~
		"\tPage Attribute Table [PAT]: %s\n" ~
		"\tMemory Type Range Registers [MTRR]: %s\n" ~
		"\tPage Global Bit [PGE]: %s\n",
		B(PAE),
		B(PSE_36),
		B(Page1GB),
		B(DCA),
		B(PAT),
		B(MTRR),
		B(PGE)
	);

	printf( // Debugging
		"\nDebugging\n" ~
		"\tMachine Check Architecture [MCA]: %s\n" ~
		"\tMachine Check Exception [MCE]: %s\n" ~
		"\tDebugging Extensions [DE]: %s\n" ~
		"\tDebug Store [DS]: %s\n" ~
		"\tDebug Store CPL [DS-CPL]: %s\n" ~
		"\t64-bit DS Area [DTES64]: %s\n" ~
		"\tPerfmon and Debug Capability [PDCM]: %s\n" ~
		"\tIA32_DEBUG_INTERFACE (MSR) [SDBG]: %s\n",
		B(MCA),
		B(MCE),
		B(DE),
		B(DS),
		B(DS_CPL),
		B(DTES64),
		B(PDCM),
		B(SDBG)
	);

	printf( // Other features
		"\nOther features\n" ~
		"\tBrand Index: %d\n" ~
		"\tL1 Context ID [CNXT-ID]: %s\n" ~
		"\txTPR Update Control [xTPR]: %s\n" ~
		"\tProcess-context identifiers [PCID]: %s\n" ~
		"\tProcessor Serial Number [PSN]: %s\n" ~
		"\tSelf Snoop [SS]: %s\n" ~
		"\tPending Break Enable [PBE]: %s\n" ~
		"\tSupervisor Mode Execution Protection [SMEP]: %s\n" ~
		"\tBit manipulation groups [BMI]: ",
		BrandIndex,
		B(CNXT_ID),
		B(xTPR),
		B(PCID),
		B(PSN),
		B(SS),
		B(PBE),
		B(SMEP)
	);
	if (BMI1 || BMI2) {
		if (BMI1) printf("BMI1");
		if (BMI2) printf(", BMI2");
		printf("\n");
	} else
		puts("None");

	return 0;
} // main

extern(C) immutable(char)* B(uint c) pure @nogc nothrow {
	return c ? "Yes" : "No";
}

/// Print cpuid
extern(C) void printc(uint leaf) {
	uint a = void, b = void, c = void, d = void;
	asm {
		mov EAX, leaf;
		mov ECX, 0;
		cpuid;
		mov a, EAX;
		mov b, EBX;
		mov c, ECX;
		mov d, EDX;
	}
	printf("| %8X | %8X | %8X | %8X | %8X |\n", leaf, a, b, c, d);
}

template BIT(int n) {
	enum { BIT = 1 << n }
}

struct Cache {
	/*
	 * Cache Size in Bytes
	 * (Ways + 1) * (Partitions + 1) * (Line_Size + 1) * (Sets + 1)
	 * (EBX[31:22] + 1) * (EBX[21:12] + 1) * (EBX[11:0] + 1) * (ECX + 1)
	 */
	ubyte type = void; // data=1, instructions=2, unified=3
	ubyte level = void; // L1, L2, etc.
	ubyte ways = void; // n-way
	ubyte partitions = void; // or "lines per tag" (AMD)
	ubyte linesize = void;
	ushort sets = void;
	uint size = void; // (AMD) size in KB
	// Intel
	// -- ebx
	// bit 0, Self Initializing cache level
	// bit 1, Fully Associative cache
	// -- edx
	// bit 2, Write-Back Invalidate/Invalidate (toggle)
	// bit 3, Cache Inclusiveness (toggle)
	// bit 4, Complex Cache Indexing (toggle)
	// AMD
	// See Intel, except no Complex Cache Indexing
	ubyte features = void;
}

// 6 levels should be enough (L1 x2, L2, L3, +2 futureproof/0)
__gshared Cache[6] cache;

/*****************************
 * FETCH INFO
 *****************************/

extern (C)
void fetchInfo() {
	uint a = void, b = void, c = void, d = void; // EAX to EDX

	version (Posix) {
		size_t __A = cast(size_t)&vendorString;
		size_t __B = cast(size_t)&cpuString;
	}

	// Get processor vendor and processor brand string
	version (X86_64) {
		version (Windows)
			asm { lea RDI, vendorString; }
		else
			asm { mov RDI, __A; }
		asm {
		mov EAX, 0;
		cpuid;
		mov [RDI], EBX;
		mov [RDI+4], EDX;
		mov [RDI+8], ECX;
		mov byte ptr [RDI+12], 0;
		}

		version (Windows)
			asm { lea RDI, cpuString; }
		else
			asm { mov RDI, __B; }
		asm {
		mov EAX, 0x8000_0002;
		cpuid;
		mov [RDI], EAX;
		mov [RDI+ 4], EBX;
		mov [RDI+ 8], ECX;
		mov [RDI+12], EDX;
		mov EAX, 0x8000_0003;
		cpuid;
		mov [RDI+16], EAX;
		mov [RDI+20], EBX;
		mov [RDI+24], ECX;
		mov [RDI+28], EDX;
		mov EAX, 0x8000_0004;
		cpuid;
		mov [RDI+32], EAX;
		mov [RDI+36], EBX;
		mov [RDI+40], ECX;
		mov [RDI+44], EDX;
		mov byte ptr [RDI+48], 0;
		}
	} else {
		version (Windows)
			asm { lea EDI, vendorString; }
		else
			asm { mov EDI, __A; }
		asm {
		lea EDI, vendorString;
		mov EAX, 0;
		cpuid;
		mov [EDI], EBX;
		mov [EDI+4], EDX;
		mov [EDI+8], ECX;
		mov byte ptr [EDI+12], 0;
		}

		version (Windows)
			asm { lea EDI, cpuString; }
		else
			asm { mov EDI, __B; }
		asm {
		lea EDI, cpuString;
		mov EAX, 0x8000_0002;
		cpuid;
		mov [EDI], EAX;
		mov [EDI+ 4], EBX;
		mov [EDI+ 8], ECX;
		mov [EDI+12], EDX;
		mov EAX, 0x8000_0003;
		cpuid;
		mov [EDI+16], EAX;
		mov [EDI+20], EBX;
		mov [EDI+24], ECX;
		mov [EDI+28], EDX;
		mov EAX, 0x8000_0004;
		cpuid;
		mov [EDI+32], EAX;
		mov [EDI+36], EBX;
		mov [EDI+40], ECX;
		mov [EDI+44], EDX;
		mov byte ptr [EDI+48], 0;
		}
	}

	// Why compare strings when you can just compare numbers?
	VendorID = *cast(uint*)vendorString;

	ubyte* bp = cast(ubyte*)&b;
	ubyte* cp = cast(ubyte*)&c;
	ubyte* dp = cast(ubyte*)&d;

	uint l; /// Cache level
	Cache* ca = cast(Cache*)cache;

	switch (VendorID) { // CACHE INFORMATION
	case VENDOR_INTEL:
CACHE_INTEL:
		asm {
			mov EAX, 4;
			mov ECX, l;
			cpuid;
			cmp EAX, 0; // Check ZF
			jz CACHE_DONE; // if EAX=0, get out
			mov a, EAX;
			mov b, EBX;
			mov c, ECX;
			mov d, EDX;
		}

		ca.type = (a & 0b1111);
		ca.level = cast(ubyte)((a >> 5) & 0b111);
		ca.linesize = cast(ubyte)((b & 0x7FF) + 1);
		ca.partitions = cast(ubyte)(((b >> 12) & 0x7FF) + 1);
		ca.ways = cast(ubyte)((b >> 22) + 1);
		ca.sets = cast(ushort)(c + 1);
		ca.size = ca.sets * ca.linesize * ca.partitions * ca.ways;
		if (Details) {
			if (a & BIT!(8)) ca.features = 1;
			if (a & BIT!(9)) ca.features |= BIT!(1);
			if (d & BIT!(0)) ca.features |= BIT!(2);
			if (d & BIT!(1)) ca.features |= BIT!(3);
			if (d & BIT!(2)) ca.features |= BIT!(4);
		}

		debug printf("| %8X | %8X | %8X | %8X | %8X |\n", l, a, b, c, d);
		++l; ++ca;
		goto CACHE_INTEL;
	case VENDOR_AMD:
		ubyte _amd_ways_l2 = void; // please the compiler

		if (MaximumExtendedLeaf >= 0x8000_001D) goto CACHE_AMD_NEWER;

		asm { // olde way
			mov EAX, 0x8000_0005;
			cpuid;
			mov c, ECX;
			mov d, EDX;
		}
		cache[0].level = cache[1].level = 1; // L1
		cache[0].type = 1; // data
		cache[0].linesize = *cp;
		cache[0].partitions = *(cp + 1);
		cache[0].ways = *(cp + 2);
		cache[0].size = *(cp + 3);
		cache[1].type = 2; // instructions
		cache[1].linesize = *dp;
		cache[1].partitions = *(dp + 1);
		cache[1].ways = *(dp + 2);
		cache[1].size = *(dp + 3);

		if (MaximumExtendedLeaf < 0x8000_0006) break; // No L2/L3

		// Old reference table
		// See Table E-4. L2/L3 Cache and TLB Associativity Field Encoding
		// Returns: n-ways
		extern (C) ubyte _amd_ways(ubyte w) {
			switch (w) {
			case 1, 2, 4: return w;
			case 6: return 8;
			case 8: return 16;
			case 0xA: return 32;
			case 0xB: return 48;
			case 0xC: return 64;
			case 0xD: return 96;
			case 0xE: return 128;
			case 0xF: return 129; // custom for "fully associative"
			default: return 0; // reserved
			}
		}

		asm { // olde way
			mov EAX, 0x8000_0006;
			cpuid;
			mov c, ECX;
			mov d, EDX;
		}
		_amd_ways_l2 = (c >> 12) & 7;
		if (_amd_ways_l2) {
			cache[2].level = 2; // L2
			cache[2].type = 3; // unified
			cache[2].ways = _amd_ways(_amd_ways_l2);
			cache[2].size = c >> 16;
			cache[2].sets = (c >> 8) & 7;
			cache[2].linesize = *cp;

			ubyte _amd_ways_l3 = (d >> 12) & 0b111;
			if (_amd_ways_l3) {
				cache[3].level = 3; // L2
				cache[3].type = 3; // unified
				cache[3].ways = _amd_ways(_amd_ways_l3);
				cache[3].size = ((d >> 18) + 1) * 512;
				cache[3].sets = (d >> 8) & 7;
				cache[3].linesize = *dp & 0x7F;
			}
		}

CACHE_AMD_NEWER:
		asm {
			mov EAX, 0x8000_001D;
			mov ECX, l;
			cpuid;
			cmp AL, 0; // Check ZF
			jz CACHE_DONE; // if AL=0, get out
			mov a, EAX;
			mov b, EBX;
			mov c, ECX;
			mov d, EDX;
		}

		ca.type = (a & 0b1111); // Same as Intel
		ca.level = cast(ubyte)((a >> 5) & 0b111);
		ca.linesize = cast(ubyte)((b & 0x7FF) + 1);
		ca.partitions = cast(ubyte)(((b >> 12) & 0x7FF) + 1);
		ca.ways = cast(ubyte)((b >> 22) + 1);
		ca.sets = cast(ushort)(c + 1);
		ca.size = ca.sets * ca.linesize * ca.partitions * ca.ways;
		if (Details) {
			if (a & BIT!(8)) ca.features = 1;
			if (a & BIT!(9)) ca.features |= BIT!(1);
			if (d & BIT!(0)) ca.features |= BIT!(2);
			if (d & BIT!(1)) ca.features |= BIT!(3);
		}

		debug printf("| %8X | %8X | %8X | %8X | %8X |\n", l, a, b, c, d);
		++l; ++ca;
		goto CACHE_AMD_NEWER;
	default:
	}

CACHE_DONE:
	asm {
		mov EAX, 1;
		mov ECX, 0;
		cpuid;
		mov a, EAX;
		mov b, EBX;
		mov c, ECX;
		mov d, EDX;
	} // ----- 1H

	// EAX
	Stepping       = a & 0xF;        // EAX[3:0]
	BaseModel      = a >>  4 &  0xF; // EAX[7:4]
	BaseFamily     = a >>  8 &  0xF; // EAX[11:8]
	ProcessorType  = a >> 12 & 0b11; // EAX[13:12]
	ExtendedModel  = a >> 16 &  0xF; // EAX[19:16]
	ExtendedFamily = cast(ubyte)(a >> 20); // EAX[27:20]

	switch (VendorID) {
	case VENDOR_INTEL:
		if (BaseFamily != 0)
			Family = BaseFamily;
		else
			Family = cast(ubyte)(ExtendedFamily + BaseFamily);

		if (BaseFamily == 6 || BaseFamily == 0)
			Model = cast(ubyte)((ExtendedModel << 4) + BaseModel);
		else // DisplayModel = Model_ID;
			Model = BaseModel;

		// ECX
		DTES64      = c & BIT!(2);
		DS_CPL      = c & BIT!(4);
		Virt        = c & BIT!(5);
		SMX         = c & BIT!(6);
		EIST        = c & BIT!(7);
		TM2         = c & BIT!(8);
		CNXT_ID     = c & BIT!(10);
		SDBG        = c & BIT!(11);
		xTPR        = c & BIT!(14);
		PDCM        = c & BIT!(15);
		PCID        = c & BIT!(17);
		DCA         = c & BIT!(18);
		x2APIC      = c & BIT!(21);
		TscDeadline = c & BIT!(24);

		// EDX
		PSN  = d & BIT!(18);
		DS   = d & BIT!(21);
		APCI = d & BIT!(22);
		SS   = d & BIT!(27);
		TM   = d & BIT!(29);
		PBE  = d & BIT!(31);
		break;
	case VENDOR_AMD:
		if (BaseFamily < 0xF) {
			Family = BaseFamily;
			Model = BaseModel;
		} else {
			Family = cast(ubyte)(ExtendedFamily + BaseFamily);
			Model = cast(ubyte)((ExtendedModel << 4) + BaseModel);
		}
		break;
	default:
	}

	// EBX
	BrandIndex      = *bp;       // EBX[ 7: 0]
	CLFLUSHLineSize = *(bp + 1); // EBX[15: 8]
	MaxIDs          = *(bp + 2); // EBX[23:16]
	InitialAPICID   = *(bp + 3); // EBX[31:24]

	// ECX
	SSE3       = c & BIT!(0);
	PCLMULQDQ  = c & BIT!(1);
	MONITOR    = c & BIT!(3);
	SSSE3      = c & BIT!(9);
	FMA        = c & BIT!(12);
	CMPXCHG16B = c & BIT!(13);
	SSE41      = c & BIT!(15);
	SSE42      = c & BIT!(20);
	MOVBE      = c & BIT!(22);
	POPCNT     = c & BIT!(23);
	AES        = c & BIT!(25);
	XSAVE      = c & BIT!(26);
	OSXSAVE    = c & BIT!(27);
	AVX        = c & BIT!(28);
	F16C       = c & BIT!(29);
	RDRAND     = c & BIT!(30);

	// EDX
	FPU    = d & BIT!(0);
	VME    = d & BIT!(1);
	DE     = d & BIT!(2);
	PSE    = d & BIT!(3);
	TSC    = d & BIT!(4);
	MSR    = d & BIT!(5);
	PAE    = d & BIT!(6);
	MCE    = d & BIT!(7);
	CX8    = d & BIT!(8);
	APIC   = d & BIT!(9);
	SEP    = d & BIT!(11);
	MTRR   = d & BIT!(12);
	PGE    = d & BIT!(13);
	MCA    = d & BIT!(14);
	CMOV   = d & BIT!(15);
	PAT    = d & BIT!(16);
	PSE_36 = d & BIT!(17);
	CLFSH  = d & BIT!(19);
	MMX    = d & BIT!(23);
	FXSR   = d & BIT!(24);
	SSE    = d & BIT!(25);
	SSE2   = d & BIT!(26);
	HTT    = d & BIT!(28);

	switch (VendorID) {
	case VENDOR_INTEL:
		asm {
			mov EAX, 6;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
			//mov b, EBX;
			//mov c, ECX;
			//mov d, EDX;
		} // ----- 6H, avoids calling it if not Intel, for now
		TurboBoost = a & BIT!(1);
		TurboBoost3 = a & BIT!(14);
		break;
	default:
	}

	asm {
		mov EAX, 7;
		mov ECX, 0;
		cpuid;
		//mov a, EAX;
		mov b, EBX;
		mov c, ECX;
		//mov d, EDX;
	} // ----- 7H

	BMI1   = b & BIT!(4);
	AVX2   = b & BIT!(5);
	SMEP   = b & BIT!(7);
	BMI2   = b & BIT!(8);
	RDSEED = b & BIT!(18);

	RDPID = c & BIT!(22);
	
	/*
	 * Extended CPUID leafs
	 */

	asm {
		mov EAX, 0x8000_0001;
		mov ECX, 0;
		cpuid;
		//mov a, EAX;
		mov b, EBX;
		mov c, ECX;
		mov d, EDX;
	} // EXTENDED 8000_0001H

	switch (VendorID) {
	case VENDOR_AMD:
		Virt  = c & BIT!(2); // SVM
		SSE4a = c & BIT!(6);
		FMA4  = c & BIT!(16);

		MMXExt    = d & BIT!(22);
		_3DNowExt = d & BIT!(30);
		_3DNow    = d & BIT!(31);
		break;
	default:
	}

	LZCNT     = c & BIT!(5);
	PREFETCHW = c & BIT!(8);

	NX       = d & BIT!(20);
	Page1GB  = d & BIT!(26);
	LongMode = d & BIT!(29);

	asm {
		mov EAX, 0x8000_0007;
		mov ECX, 0;
		cpuid;
		//mov a, EAX;
		mov b, EBX;
		//mov c, ECX;
		mov d, EDX;
	} // EXTENDED 8000_0007H

	switch (VendorID) {
	case VENDOR_INTEL:
		RDSEED = b & BIT!(28);
		break;
	case VENDOR_AMD:
		TM = d & BIT!(4);
		TurboBoost = d & BIT!(9);
		break;
	default:
	}

	TscInvariant = d & BIT!(8);
}

/// Get the maximum leaf.
/// Returns: Maximum leaf
extern (C) uint hleaf() {
	asm { naked;
		mov EAX, 0;
		cpuid;
		ret;
	}
}

/// Get the maximum extended leaf.
/// Returns: Maximum extended leaf
extern (C) uint heleaf() {
	asm { naked;
		mov EAX, 0x8000_0000;
		cpuid;
		ret;
	}
}

/**
 * Get the number of logical cores for an Intel processor.
 * Returns:
 *   The number of logical cores.
 * Errorcodes:
 *   -1 = Feature not supported.
 */
/*extern (C) short getCoresIntel() {
	asm { naked;
		mov EAX, 0;
		cpuid;
		cmp EAX, 0xB;
		jge INTEL_A;
		mov AX, -1;
		ret;
INTEL_A:
		mov EAX, 0xB;
		mov ECX, 1;
		cpuid;
		mov AX, BX;
		ret;
	}
}*/

/***************************
 * Features and properties
 ***************************/

extern (C):
__gshared:

// ---- Basic information ----
char[13] vendorString = void;
char[49] cpuString = void;

uint MaximumLeaf = void;
uint MaximumExtendedLeaf = void;

//ushort NumberOfCores;
//ushort NumberOfThreads;

ubyte Family = void;
ubyte BaseFamily = void;
ubyte ExtendedFamily = void;
ubyte Model = void;
ubyte BaseModel = void;
ubyte ExtendedModel = void;
ubyte Stepping = void;
ubyte ProcessorType = void;

uint MMX = void;
uint MMXExt = void;
uint SSE = void;
uint SSE2 = void;
uint SSE3 = void;
uint SSSE3 = void;
uint SSE41 = void;
uint SSE42 = void;
uint SSE4a = void;
uint AES = void;
uint AVX = void;
uint AVX2 = void;

uint _3DNow = void;
uint _3DNowExt = void;

// ---- 01h ----
// -- EBX --
ubyte BrandIndex = void;
ubyte CLFLUSHLineSize = void;
ubyte MaxIDs = void;
ubyte InitialAPICID = void;

// -- ECX --
ubyte PCLMULQDQ = void;	// 1
ubyte DTES64 = void;
ubyte MONITOR = void;
ubyte DS_CPL = void;
ubyte Virt = void; // VMX (intel) / SVM (AMD)
ubyte SMX = void; // intel txt/tpm
ubyte EIST = void; // intel speedstep
ushort TM2 = void;
ushort CNXT_ID = void; // l1 context id
ushort SDBG = void; // IA32_DEBUG_INTERFACE silicon debug
ushort FMA = void;
uint FMA4 = void;
uint CMPXCHG16B = void;
uint xTPR = void;
uint PDCM = void;
uint PCID = void; // Process-context identifiers
uint DCA = void;
uint x2APIC = void;
uint MOVBE = void;
uint POPCNT = void;
uint TscDeadline = void;
uint XSAVE = void;
uint OSXSAVE = void;
uint F16C = void;
uint RDRAND = void;	// 30

// -- EDX --
ubyte FPU = void; // 0
ubyte VME = void;
ubyte DE = void;
ubyte PSE = void;
ubyte TSC = void;
ubyte MSR = void;
ubyte PAE = void;
ubyte MCE = void;
ushort CX8 = void;
ushort APIC = void;
ushort SEP = void; // sysenter/sysexit
ushort MTRR = void;
ushort PGE = void;
ushort MCA = void;
ushort CMOV = void;
uint PAT = void;
uint PSE_36 = void;
uint PSN = void;
uint CLFSH = void;
uint DS = void;
uint APCI = void;
uint FXSR = void;
uint SS = void; // self-snoop
uint HTT = void;
uint TM = void;
uint PBE = void; // 31

// ---- 06h ----
/// eq. to AMD's Core Performance Boost
ushort TurboBoost = void;	// 1
ushort TurboBoost3 = void;	// 14

// ---- 07h ----
// -- EBX --
ubyte BMI1 = void;	// 3
ubyte SMEP = void;	// 7
ushort BMI2 = void;	// 8
// -- ECX --
uint RDPID = void;	// 22

// ---- 8000_0001 ----
// ECX
/// Advanced Bit Manipulation under AMD. LZCUNT under Intel.
ubyte LZCNT = void;
/// PREFETCHW under Intel. 3DNowPrefetch under AMD.
ushort PREFETCHW = void;	// 8

/// RDSEED instruction
uint RDSEED = void;
// EDX
uint NX = void;	// 20
/// 1GB Pages
uint Page1GB = void;	// 26
/// Also known as Intel64 or AMD64.
uint LongMode = void;	// 29

// ---- 8000_0007 ----
ushort TscInvariant = void;	// 8