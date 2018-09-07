extern (C) {
	int strcmp(scope const char* s1, scope const char* s2);
	int printf(scope const char* format, ...);
	int puts(scope const char* s);
	int putchar(int c);
}

enum VERSION = "0.8.0"; /// Program version

enum
	MAX_LEAF = 0x20, /// Maximum leaf (-o)
	MAX_ELEAF = 0x8000_0020; /// Maximum extended leaf (-o)

/*
 * Self-made vendor "IDs" for faster look-ups, LSB-based.
 * These are the first four bytes of the vendor. If even the four first bytes
 * re-appear in another vendor, get the next four bytes.
 */
enum // LSB
	VENDOR_OTHER	= 0,	// Or unknown
	VENDOR_INTEL	= 0x756e6547,	// "Genu"
	VENDOR_AMD	= 0x68747541,	// "Auth"
	VENDOR_VIA	= 0x20414956;	// "VIA "

__gshared uint VendorID; /// Vendor "ID", inits to VENDOR_OTHER

__gshared byte Raw;	/// Raw option (-r)
__gshared byte Details;	/// Detailed output option (-d)
__gshared byte Override;	/// Override max leaf option (-o)

pragma(inline, true)
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

pragma(inline, true)
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

	__CPUINFO s = void;

	if (Override) {
		s.MaximumLeaf = MAX_LEAF;
		s.MaximumExtendedLeaf = MAX_ELEAF;
	} else {
		s.MaximumLeaf = hleaf;
		s.MaximumExtendedLeaf = heleaf;
	}

	if (Raw) { // -r
		/// Print cpuid info
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

		puts(
			"| Leaf     | EAX      | EBX      | ECX      | EDX      |\n"~
			"|----------|----------|----------|----------|----------|"
		);
		uint l;
		do {
			printc(l);
		} while (++l <= s.MaximumLeaf);
		l = 0x8000_0000; // Extended
		do {
			printc(l);
		} while (++l <= s.MaximumExtendedLeaf);
		return 0;
	}

	debug printf("[L%04d] Fetching info...\n", __LINE__);

	fetchInfo(&s);

	char* cstring = cast(char*)s.cpuString;

	switch (VendorID) {
	case VENDOR_INTEL: // Common in Intel processor brand strings
		while (*cstring == ' ') ++cstring; // left trim cpu string
		break;
	default:
	}

	// -- Processor basic information --

	printf(
		"Vendor: %.12s\n" ~
		"String: %.48s\n",
		cast(char*)s.vendorString, cstring
	);

	if (Details == 0)
		printf(
			"Identifier: Family %d Model %d Stepping %d\n",
			s.Family, s.Model, s.Stepping
		);
	else
		printf(
			"Identifier: Family %Xh [%Xh:%Xh] Model %Xh [%Xh:%Xh] Stepping %Xh\n",
			s.Family, s.BaseFamily, s.ExtendedFamily,
			s.Model, s.BaseModel, s.ExtendedModel,
			s.Stepping
		);

	// -- Processor extensions --

	puts("Extensions:");
	if (s.MMX) printf("\tMMX");
	if (s.MMXExt) printf("\tExtended MMX");
	if (s._3DNow) printf("\t3DNow!");
	if (s._3DNowExt) printf("\tExtended 3DNow!");
	if (s.SSE) printf("\tSSE");
	if (s.SSE2) printf("\tSSE2");
	if (s.SSE3) printf("\tSSE3");
	if (s.SSSE3) printf("\tSSSE3");
	if (s.SSE41) printf("\tSSE4.1");
	if (s.SSE42) printf("\tSSE4.2");
	if (s.SSE4a) printf("\tSSE4a");
	if (s.LongMode)
		switch (VendorID) {
		case VENDOR_INTEL: printf("\tIntel64"); break;
		case VENDOR_AMD: printf("\tAMD64"); break;
		default: printf("\tx86-64"); break;
		}
	if (s.Virt)
		switch (VendorID) {
		case VENDOR_INTEL: printf("\tVT-x"); break; // VMX
		case VENDOR_AMD: printf("\tAMD-V"); break; // SVM
		//case VENDOR_VIA: printf("\tVIA VT"); break; <- Uncomment when ready
		default: printf("\tVMX"); break;
		}
	if (s.NX)
		switch (VendorID) {
		case VENDOR_INTEL: printf("\tIntel XD (NX)"); break;
		case VENDOR_AMD: printf("\tAMD EVP (NX)"); break;
		default: printf("\tNX"); break;
		}
	if (s.SMX) printf("\tIntel TXT (SMX)");
	if (s.AES) printf("\tAES-NI");
	if (s.AVX) printf("\tAVX");
	if (s.AVX2) printf("\tAVX2");
	if (s.AVX512F) {
		printf("\tAVX512F");
		if (s.AVX512ER) printf("\tAVX512ER");
		if (s.AVX512PF) printf("\tAVX512PF");
		if (s.AVX512CD) printf("\tAVX512CD");
		if (s.AVX512DQ) printf("\tAVX512DQ");
		if (s.AVX512BW) printf("\tAVX512BW");
		if (s.AVX512VL) printf("\tAVX512VL");
		if (s.AVX512_IFMA) printf("\tAVX512_IFMA");
		if (s.AVX512_VBMI) printf("\tAVX512_VBMI");
	}
	if (s.FMA) printf("\tFMA3");
	if (s.FMA4) printf("\tFMA4");

	// -- Other instructions --

	puts("\nOther instructions:");
	if (s.MONITOR) printf("\tMONITOR/MWAIT");
	if (s.PCLMULQDQ) printf("\tPCLMULQDQ");
	if (s.CX8) printf("\tCMPXCHG8B");
	if (s.CMPXCHG16B) printf("\tCMPXCHG16B");
	if (s.MOVBE) printf("\tMOVBE"); // Intel Atom and quite a few AMD processors.
	if (s.RDRAND) printf("\tRDRAND");
	if (s.RDSEED) printf("\tRDSEED");
	if (s.MSR) printf("\tRDMSR/WRMSR");
	if (s.SEP) printf("\tSYSENTER/SYSEXIT");
	if (s.TSC) {
		printf("\tRDTSC");
		if (s.TscDeadline)
			printf("\t+TSC-Deadline");
		if (s.TscInvariant)
			printf("\t+TSC-Invariant");
	}
	if (s.CMOV) {
		printf("\tCMOV");
		if (s.FPU) printf("\tFCOMI/FCMOV");
	}
	if (s.CLFSH) printf("\tCLFLUSH (%d bytes)", s.CLFLUSHLineSize * 8);
	if (s.PREFETCHW) printf("\tPREFETCHW");
	if (s.LZCNT) printf("\tLZCNT");
	if (s.POPCNT) printf("\tPOPCNT");
	if (s.XSAVE) printf("\tXSAVE/XRSTOR");
	if (s.OSXSAVE) printf("\tXSETBV/XGETBV");
	if (s.FXSR) printf("\tFXSAVE/FXRSTOR");
	if (s.RDPID) printf("\tRDPID");

	// -- Cache information --

	puts("\n\nCache information");

	/// Return cache type as string
	extern (C) 
	immutable(char)* _ct(ubyte t) {
		switch (t) {
		case 1: return " Data";
		case 2: return " Instructions";
		default: return ""; // MUST be "" since it's valid data
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
			char c = 'K';
			if (ca.size >= 1024) {
				ca.size /= 1024;
				c = 'M';
			}
			printf(
				"\tL%d%s, %d %cB\n",
				ca.level, _ct(ca.type), ca.size, c
			);
			++ca;
		}
	}

	// -- Vendor specific features ---

	puts("\nProcessor technologies");

	switch (VendorID) {
	case VENDOR_INTEL:
		if (s.EIST)
			puts("\tEnhanced SpeedStep(R) Technology");
		if (s.TurboBoost) {
			printf("\tTurboBoost");
			if (s.TurboBoost3)
				puts(" 3.0");
			else
				putchar('\n');
		}
		break;
	case VENDOR_AMD:
		if (s.TurboBoost)
			puts("\tCore Performance Boost");
		break;
	default:
	}

	if (Details == 0) return 0;

	// -- Processor detailed features --

	immutable(char)* _pt() { // D call for parent stack frame
		switch (s.ProcessorType) { // 2 bit value
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
		"\t16-bit conversion [F16C]: %s\n",
		s.MaximumLeaf, s.MaximumExtendedLeaf,
		_pt,
		B(s.FPU),
		B(s.F16C)
	);

	printf( // ACPI
		"\nACPI\n" ~
		"\tACPI: %s\n" ~
		"\tAPIC: %s (Initial ID: %d, Max: %d)\n" ~
		"\tx2APIC: %s\n" ~
		"\tThermal Monitor: %s\n" ~
		"\tThermal Monitor 2: %s\n",
		B(s.ACPI),
		B(s.APIC), s.InitialAPICID, s.MaxIDs,
		B(s.x2APIC),
		B(s.TM),
		B(s.TM2)
	);

	printf( // Virtualization
		"\nVirtualization\n" ~
		"\tVirtual 8086 Mode Enhancements [VME]: %s\n",
		B(s.VME)
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
		B(s.PAE),
		B(s.PSE_36),
		B(s.Page1GB),
		B(s.DCA),
		B(s.PAT),
		B(s.MTRR),
		B(s.PGE)
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
		B(s.MCA),
		B(s.MCE),
		B(s.DE),
		B(s.DS),
		B(s.DS_CPL),
		B(s.DTES64),
		B(s.PDCM),
		B(s.SDBG)
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
		"\tBit Manipulation Groups [BMI]:",
		s.BrandIndex,
		B(s.CNXT_ID),
		B(s.xTPR),
		B(s.PCID),
		B(s.PSN),
		B(s.SS),
		B(s.PBE),
		B(s.SMEP)
	);
	if (s.BMI1 || s.BMI2) {
		if (s.BMI1) printf(" BMI1");
		if (s.BMI2) printf(" BMI2");
		putchar('\n');
	} else
		puts(" None");

	return 0;
} // main

extern(C)
immutable(char)* B(uint c) pure @nogc nothrow {
	return c ? "Yes" : "No";
}

template BIT(int n) {
	enum { BIT = 1 << n }
}

/**
 * Check bit at position
 * Params:
 *   r = Register value
 *   n = bit mask (use BIT!)
 * Returns: 1 if present
 */
pragma(inline, true)
extern (C)
ubyte CHECK(int n) {
	return n ? 1 : 0;
}

struct Cache {
	/*
	 * Cache Size in Bytes
	 * (Ways + 1) * (Partitions + 1) * (Line_Size + 1) * (Sets + 1)
	 * (EBX[31:22] + 1) * (EBX[21:12] + 1) * (EBX[11:0] + 1) * (ECX + 1)
	 */
	ubyte type = void; // data=1, instructions=2, unified=3
	ubyte level = void; // L1, L2, etc.
	union {
		uint __bundle1;
		struct {
			ubyte linesize = void;
			ubyte partitions = void; // or "lines per tag" (AMD)
			ubyte ways = void; // n-way
			ubyte _amdsize; // (old AMD) Size in KB
		}
	}
	uint size = void; // Size in KB
	ushort sets = void;
	// Intel
	// -- ebxc
	// bit 0, Self Initializing cache level
	// bit 1, Fully Associative cache
	// -- edx
	// bit 2, Write-Back Invalidate/Invalidate (toggle)
	// bit 3, Cache Inclusiveness (toggle)
	// bit 4, Complex Cache Indexing (toggle)
	// AMD
	// See Intel, except Complex Cache Indexing is absent
	ubyte features = void;
}

// 6 levels should be enough (L1 x2, L2, L3, +2 futureproof/0)
__gshared Cache[6] cache; // all inits to 0

/*****************************
 * FETCH INFO
 *****************************/

extern (C)
void fetchInfo(__CPUINFO* s) {
	size_t __A = cast(size_t)&s.vendorString;
	size_t __B = cast(size_t)&s.cpuString;

	// Get processor vendor and processor brand string
	version (X86_64) {
		asm {
			mov RDI, __A;
			mov EAX, 0;
			cpuid;
			mov [RDI], EBX;
			mov [RDI+4], EDX;
			mov [RDI+8], ECX;
			mov byte ptr [RDI+12], 0;

			mov RDI, __B;
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
	} else { // version X86
		asm {
			mov EDI, __A;
			mov EAX, 0;
			cpuid;
			mov [EDI], EBX;
			mov [EDI+4], EDX;
			mov [EDI+8], ECX;
			mov byte ptr [EDI+12], 0;

			mov EDI, __B;
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
	VendorID = *cast(uint*)s.vendorString;

	uint a = void, b = void, c = void, d = void; // EAX to EDX
	//ubyte* cp = cast(ubyte*)&c;
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
		if (Details) {
			if (a & BIT!(8)) ca.features = 1;
			if (a & BIT!(9)) ca.features |= BIT!(1);
			if (d & BIT!(0)) ca.features |= BIT!(2);
			if (d & BIT!(1)) ca.features |= BIT!(3);
			if (d & BIT!(2)) ca.features |= BIT!(4);
		} else {
			ca.size = (ca.sets * ca.linesize * ca.partitions * ca.ways) / 1024;
		}

		debug printf("| %8X | %8X | %8X | %8X | %8X |\n", l, a, b, c, d);
		++l; ++ca;
		goto CACHE_INTEL;
	case VENDOR_AMD:
		ubyte _amd_ways_l2 = void; // please the compiler

		if (s.MaximumExtendedLeaf >= 0x8000_001D) goto CACHE_AMD_NEWER;

		asm { // olde way
			mov EAX, 0x8000_0005;
			cpuid;
			mov c, ECX;
			mov d, EDX;
		}
		cache[0].level = cache[1].level = 1; // L1
		cache[0].type = 1; // data
		cache[0].__bundle1 = c;
		cache[0].size = cache[0]._amdsize;
		cache[1].__bundle1 = d;
		cache[1].size = cache[1]._amdsize;
		/*cache[0].linesize = *cp;
		cache[0].partitions = *(cp + 1);
		cache[0].ways = *(cp + 2);
		cache[0].size = *(cp + 3);
		cache[1].type = 2; // instructions
		cache[1].linesize = *dp;
		cache[1].partitions = *(dp + 1);
		cache[1].ways = *(dp + 2);
		cache[1].size = *(dp + 3);*/

		if (s.MaximumExtendedLeaf < 0x8000_0006) break; // No L2/L3

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
			cache[2].linesize = cast(ubyte)c;

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
		if (Details) {
			if (a & BIT!(8)) ca.features = 1;
			if (a & BIT!(9)) ca.features |= BIT!(1);
			if (d & BIT!(0)) ca.features |= BIT!(2);
			if (d & BIT!(1)) ca.features |= BIT!(3);
		} else {
			ca.size = (ca.sets * ca.linesize * ca.partitions * ca.ways) / 1024;
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
	s.Stepping       = a & 0xF;        // EAX[3:0]
	s.BaseModel      = a >>  4 &  0xF; // EAX[7:4]
	s.BaseFamily     = a >>  8 &  0xF; // EAX[11:8]
	s.ProcessorType  = a >> 12 & 0b11; // EAX[13:12]
	s.ExtendedModel  = a >> 16 &  0xF; // EAX[19:16]
	s.ExtendedFamily = cast(ubyte)(a >> 20); // EAX[27:20]

	switch (VendorID) {
	case VENDOR_INTEL:
		if (s.BaseFamily != 0)
			s.Family = s.BaseFamily;
		else
			s.Family = cast(ubyte)(s.ExtendedFamily + s.BaseFamily);

		if (s.BaseFamily == 6 || s.BaseFamily == 0)
			s.Model = cast(ubyte)((s.ExtendedModel << 4) + s.BaseModel);
		else // DisplayModel = Model_ID;
			s.Model = s.BaseModel;

		// ECX
		s.DTES64      = CHECK(c & BIT!(2));
		s.DS_CPL      = CHECK(c & BIT!(4));
		s.Virt        = CHECK(c & BIT!(5));
		s.SMX         = CHECK(c & BIT!(6));
		s.EIST        = CHECK(c & BIT!(7));
		s.TM2         = CHECK(c & BIT!(8));
		s.CNXT_ID     = CHECK(c & BIT!(10));
		s.SDBG        = CHECK(c & BIT!(11));
		s.xTPR        = CHECK(c & BIT!(14));
		s.PDCM        = CHECK(c & BIT!(15));
		s.PCID        = CHECK(c & BIT!(17));
		s.DCA         = CHECK(c & BIT!(18));
		s.x2APIC      = CHECK(c & BIT!(21));
		s.TscDeadline = CHECK(c & BIT!(24));

		// EDX
		s.PSN  = CHECK(d & BIT!(18)); //d & BIT!(18);
		s.DS   = CHECK(d & BIT!(21));
		s.ACPI = CHECK(d & BIT!(22));
		s.SS   = CHECK(d & BIT!(27));
		s.TM   = CHECK(d & BIT!(29));
		s.PBE  = CHECK(d & BIT!(31));
		break;
	case VENDOR_AMD:
		if (s.BaseFamily < 0xF) {
			s.Family = s.BaseFamily;
			s.Model = s.BaseModel;
		} else {
			s.Family = cast(ubyte)(s.ExtendedFamily + s.BaseFamily);
			s.Model = cast(ubyte)((s.ExtendedModel << 4) + s.BaseModel);
		}
		break;
	default:
	}

	// EBX
	//s.BrandIndex      = *bp;       // EBX[ 7: 0]
	//s.CLFLUSHLineSize = *(bp + 1); // EBX[15: 8]
	//s.MaxIDs          = *(bp + 2); // EBX[23:16]
	//s.InitialAPICID   = *(bp + 3); // EBX[31:24]
	s.__bundle1 = b;

	//*(cast(uint*)BrandIndex) = b;

	// ECX
	s.SSE3       = CHECK(c & BIT!(0));
	s.PCLMULQDQ  = CHECK(c & BIT!(1));
	s.MONITOR    = CHECK(c & BIT!(3));
	s.SSSE3      = CHECK(c & BIT!(9));
	s.FMA        = CHECK(c & BIT!(12));
	s.CMPXCHG16B = CHECK(c & BIT!(13));
	s.SSE41      = CHECK(c & BIT!(15));
	s.SSE42      = CHECK(c & BIT!(20));
	s.MOVBE      = CHECK(c & BIT!(22));
	s.POPCNT     = CHECK(c & BIT!(23));
	s.AES        = CHECK(c & BIT!(25));
	s.XSAVE      = CHECK(c & BIT!(26));
	s.OSXSAVE    = CHECK(c & BIT!(27));
	s.AVX        = CHECK(c & BIT!(28));
	s.F16C       = CHECK(c & BIT!(29));
	s.RDRAND     = CHECK(c & BIT!(30));

	// EDX
	s.FPU    = CHECK(d & BIT!(0));
	s.VME    = CHECK(d & BIT!(1));
	s.DE     = CHECK(d & BIT!(2));
	s.PSE    = CHECK(d & BIT!(3));
	s.TSC    = CHECK(d & BIT!(4));
	s.MSR    = CHECK(d & BIT!(5));
	s.PAE    = CHECK(d & BIT!(6));
	s.MCE    = CHECK(d & BIT!(7));
	s.CX8    = CHECK(d & BIT!(8));
	s.APIC   = CHECK(d & BIT!(9));
	s.SEP    = CHECK(d & BIT!(11));
	s.MTRR   = CHECK(d & BIT!(12));
	s.PGE    = CHECK(d & BIT!(13));
	s.MCA    = CHECK(d & BIT!(14));
	s.CMOV   = CHECK(d & BIT!(15));
	s.PAT    = CHECK(d & BIT!(16));
	s.PSE_36 = CHECK(d & BIT!(17));
	s.CLFSH  = CHECK(d & BIT!(19));
	s.MMX    = CHECK(d & BIT!(23));
	s.FXSR   = CHECK(d & BIT!(24));
	s.SSE    = CHECK(d & BIT!(25));
	s.SSE2   = CHECK(d & BIT!(26));
	s.HTT    = CHECK(d & BIT!(28));

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
		s.TurboBoost = CHECK(a & BIT!(1));
		s.TurboBoost3 = CHECK(a & BIT!(14));
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

	switch (VendorID) {
	case VENDOR_INTEL:
		s.AVX512F     = CHECK(b & BIT!(16));
		s.AVX512ER    = CHECK(b & BIT!(27));
		s.AVX512PF    = CHECK(b & BIT!(26));
		s.AVX512CD    = CHECK(b & BIT!(28));
		s.AVX512DQ    = CHECK(b & BIT!(17));
		s.AVX512BW    = CHECK(b & BIT!(30));
		s.AVX512_IFMA = CHECK(b & BIT!(21));
		s.AVX512_VBMI = CHECK(b & BIT!(31));
		s.AVX512VL    = CHECK(c & BIT!(1));
		break;
	default:
	}

	s.BMI1   = CHECK(b & BIT!(4));
	s.AVX2   = CHECK(b & BIT!(5));
	s.SMEP   = CHECK(b & BIT!(7));
	s.BMI2   = CHECK(b & BIT!(8));
	s.RDSEED = CHECK(b & BIT!(18));
	s.RDPID  = CHECK(c & BIT!(22));
	
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
		s.Virt      = CHECK(c & BIT!(2)); // SVM
		s.SSE4a     = CHECK(c & BIT!(6));
		s.FMA4      = CHECK(c & BIT!(16));
		s.MMXExt    = CHECK(d & BIT!(22));
		s._3DNowExt = CHECK(d & BIT!(30));
		s._3DNow    = CHECK(d & BIT!(31));
		break;
	default:
	}

	s.LZCNT     = CHECK(c & BIT!(5));
	s.PREFETCHW = CHECK(c & BIT!(8));
	s.NX        = CHECK(d & BIT!(20));
	s.Page1GB   = CHECK(d & BIT!(26));
	s.LongMode  = CHECK(d & BIT!(29));

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
		s.RDSEED = CHECK(b & BIT!(28));
		break;
	case VENDOR_AMD:
		s.TM = CHECK(d & BIT!(4));
		s.TurboBoost = CHECK(d & BIT!(9));
		break;
	default:
	}

	s.TscInvariant = CHECK(d & BIT!(8));
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

struct __CPUINFO {
	// ---- Basic information ----
	char[12] vendorString = void;
	char[48] cpuString = void;

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

	ubyte MMX = void;
	ubyte MMXExt = void;
	ubyte SSE = void;
	ubyte SSE2 = void;
	ubyte SSE3 = void;
	ubyte SSSE3 = void;
	ubyte SSE41 = void;
	ubyte SSE42 = void;
	ubyte SSE4a = void;
	ubyte AES = void;
	ubyte AVX = void;
	ubyte AVX2 = void;
	ubyte AVX512F = void;
	ubyte AVX512ER = void;
	ubyte AVX512PF = void;
	ubyte AVX512CD = void;
	ubyte AVX512DQ = void;
	ubyte AVX512BW = void;
	ubyte AVX512_IFMA = void;
	ubyte AVX512_VBMI = void;
	ubyte AVX512VL = void;

	ubyte _3DNow = void;
	ubyte _3DNowExt = void;

	// ---- 01h ----
	// -- EBX --
	union {
		uint __bundle1;
		struct {
			ubyte BrandIndex = void;
			ubyte CLFLUSHLineSize = void;
			ubyte MaxIDs = void;
			ubyte InitialAPICID = void;
		}
	}

	// -- ECX --
	ubyte PCLMULQDQ = void;	// 1
	ubyte DTES64 = void;
	ubyte MONITOR = void;
	ubyte DS_CPL = void;
	ubyte Virt = void; // VMX (intel) / SVM (AMD)
	ubyte SMX = void; // intel txt/tpm
	ubyte EIST = void; // intel speedstep
	ubyte TM2 = void;
	ubyte CNXT_ID = void; // l1 context id
	ubyte SDBG = void; // IA32_DEBUG_INTERFACE silicon debug
	ubyte FMA = void;
	ubyte FMA4 = void;
	ubyte CMPXCHG16B = void;
	ubyte xTPR = void;
	ubyte PDCM = void;
	ubyte PCID = void; // Process-context identifiers
	ubyte DCA = void;
	ubyte x2APIC = void;
	ubyte MOVBE = void;
	ubyte POPCNT = void;
	ubyte TscDeadline = void;
	ubyte XSAVE = void;
	ubyte OSXSAVE = void;
	ubyte F16C = void;
	ubyte RDRAND = void;	// 30

	// -- EDX --
	ubyte FPU = void; // 0
	ubyte VME = void;
	ubyte DE = void;
	ubyte PSE = void;
	ubyte TSC = void;
	ubyte MSR = void;
	ubyte PAE = void;
	ubyte MCE = void;
	ubyte CX8 = void;
	ubyte APIC = void;
	ubyte SEP = void; // sysenter/sysexit
	ubyte MTRR = void;
	ubyte PGE = void;
	ubyte MCA = void;
	ubyte CMOV = void;
	ubyte PAT = void;
	ubyte PSE_36 = void;
	ubyte PSN = void;
	ubyte CLFSH = void;
	ubyte DS = void;
	ubyte ACPI = void;
	ubyte FXSR = void;
	ubyte SS = void; // self-snoop
	ubyte HTT = void;
	ubyte TM = void;
	ubyte PBE = void; // 31

	// ---- 06h ----
	/// eq. to AMD's Core Performance Boost
	ubyte TurboBoost = void;	// 1
	ubyte TurboBoost3 = void;	// 14

	// ---- 07h ----
	// -- EBX --
	ubyte SMEP = void;	// 7
	union {
		ushort __bundle2;
		struct {
			ubyte BMI1 = void;	// 3
			ubyte BMI2 = void;	// 8
		}
	}
	// -- ECX --
	ubyte RDPID = void;	// 22

	// ---- 8000_0001 ----
	// ECX
	/// Count the Number of Leading Zero Bits, SSE4 SIMD
	ubyte LZCNT = void;
	/// Prefetch
	ubyte PREFETCHW = void;	// 8

	/// RDSEED instruction
	ubyte RDSEED = void;
	// EDX
	ubyte NX = void;	// 20
	/// 1GB Pages
	ubyte Page1GB = void;	// 26
	/// Also known as Intel64 or AMD64.
	ubyte LongMode = void;	// 29

	// ---- 8000_0007 ----
	ubyte TscInvariant = void;	// 8
}