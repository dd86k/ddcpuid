extern (C) {
	int strcmp(scope const char* s1, scope const char* s2);
	int printf(scope const char* format, ...);
	int puts(scope const char* s);
}

enum VERSION = "0.6.3"; /// Program version

enum
	MAX_LEAF = 0x30, /// Maximum leaf (-o)
	MAX_ELEAF = 0x8000_0030; /// Maximum extended leaf (-o)

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
	OTHER = 0, // Or unknown
	VENDOR_INTEL = 0x756e6547, // "Genu"
	VENDOR_AMD = 0x68747541, // "Auth"
	VENDOR_VIA = 0x20414956 // "VIA "
}
__gshared uint VendorID; /// Vendor "ID"

__gshared byte Raw = 0; /// Raw option (-r)
__gshared byte Details = 0; /// Detailed output option (-d)
__gshared byte Override = 0; /// Override max leaf option (-o)

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
	puts(
`ddcpuid v` ~ VERSION ~ ` (` ~ __TIMESTAMP__ ~ `)
Copyright (c) dd86k 2016-2018
License: MIT License <http://opensource.org/licenses/MIT>
Project page: <https://github.com/dd86k/ddcpuid>
Compiler: ` ~ __VENDOR__
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
			return 0;
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
					return 0;
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
		__gshared uint l;
		do {
			printc(l);
		} while (++l <= MaximumLeaf);
		l = 0x8000_0000; // Extended minimum
		do {
			printc(l);
		} while (++l <= MaximumExtendedLeaf);
		return 0;
	}

	debug printf("[L%04d] Fetching info...", __LINE__);

	fetchInfo;

	__gshared char* cstring = cast(char*)cpuString;

	switch (VendorID) {
	case VENDOR_INTEL: // Common in Intel brand strings
		while (*cstring == ' ') ++cstring; // left trim cpu string
		break;
	default:
	}

	printf(
		"Vendor: %s\n" ~
		"String: %s\n" ~
		"Identifier: Family %d Model %d Stepping %d\n" ~
		"            %Xh [%Xh:%Xh] %Xh [%Xh:%Xh] %Xh\n",
		cast(char*)vendorString, cstring,
		Family, Model, Stepping,
		Family, BaseFamily, ExtendedFamily,
		Model, BaseModel, ExtendedModel, Stepping
	);

	printf("Extensions\n  ");
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

	if (Details) {
		printf("\nInstructions: ");
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
	}

	printf(
		"\n\nProcessor technologies\n",
	);

	switch (VendorID) { // VENDOR SPECIFIC FEATURES
	case VENDOR_INTEL:
		if (EIST)
			puts("  Enhanced SpeedStep(R) Technology");
		if (TurboBoost)
			puts("  TurboBoost");
		break;
	case VENDOR_AMD:
		if (TurboBoost)
			puts("  Core Performance Boost");
		break;
	default:
	}

	if (Details == 0) return 0;

	extern (C) immutable(char)* _pt() { // Forgive me
		switch (ProcessorType) { // 2 bit value
		case 0: return "Original OEM Processor";
		case 1: return "Intel OverDrive Processor";
		case 2: return "Dual processor";
		case 3: return "Intel reserved";
		default: return cast(char*)0; // impossible to reach anyway
		}
	}

	printf( // FPU and others
		"\nHighest Leaf: %XH | Extended: %XH\n" ~
		"Processor type: %s\n" ~
		"\nFPU\n" ~
		"  Floating Point Unit [FPU]: %s\n" ~
		"  16-bit conversion [F16]: %s\n",
		MaximumLeaf, MaximumExtendedLeaf, _pt,
		B(FPU),
		B(F16C)
	);

	printf( // APCI
		"\nAPCI\n" ~
		"  APCI: %s\n" ~
		"  APIC: %s (Initial ID: %d, Max: %d)\n" ~
		"  x2APIC: %s\n" ~
		"  Thermal Monitor: %s\n" ~
		"  Thermal Monitor 2: %s\n",
		B(APCI),
		B(APIC),
		InitialAPICID, MaxIDs, B(x2APIC),
		B(TM),
		B(TM2)
	);

	printf( // Virtualization
		"\nVirtualization\n" ~
		"  Virtual 8086 Mode Enhancements [VME]: %s\n",
		B(VME)
	);

	printf( // Memory
		"\nMemory and Paging\n" ~
		"  Page Size Extension [PAE]: %s\n" ~
		"  36-Bit Page Size Extension [PSE-36]: %s\n" ~
		"  1 GB Pages support [Page1GB]: %s\n" ~
		"  Direct Cache Access [DCA]: %s\n" ~
		"  Page Attribute Table [PAT]: %s\n" ~
		"  Memory Type Range Registers [MTRR]: %s\n" ~
		"  Page Global Bit [PGE]: %s\n" ~
		"  64-bit DS Area [DTES64]: %s\n",
		B(PAE),
		B(PSE_36),
		B(Page1GB),
		B(DCA),
		B(PAT),
		B(MTRR),
		B(PGE),
		B(DTES64)
	);

	printf( // Debugging
		"\nDebugging\n" ~
		"  Machine Check Exception [MCE]: %s\n" ~
		"  Debugging Extensions [DE]: %s\n" ~
		"  Debug Store [DS]: %s\n" ~
		"  Debug Store CPL [DS-CPL]: %s\n" ~
		"  Perfmon and Debug Capability [PDCM]: %s\n" ~
		"  IA32_DEBUG_INTERFACE (MSR) [SDBG]: %s\n",
		B(MCE),
		B(DE),
		B(DS),
		B(DS_CPL),
		B(PDCM),
		B(SDBG)
	);

	printf( // Other features
		"\nOther features\n" ~
		"  Brand Index: %d\n" ~
		"  L1 Context ID [CNXT-ID]: %s\n" ~
		"  xTPR Update Control [xTPR]: %s\n" ~
		"  Process-context identifiers [PCID]: %s\n" ~
		"  Machine Check Architecture [MCA]: %s\n" ~
		"  Processor Serial Number [PSN]: %s\n" ~
		"  Self Snoop [SS]: %s\n" ~
		"  Pending Break Enable [PBE]: %s\n" ~
		"  Supervisor Mode Execution Protection [SMEP]: %s\n" ~
		"  Bit manipulation groups: ",
		BrandIndex,
		B(CNXT_ID),
		B(xTPR),
		B(PCID),
		B(MCA),
		B(PSN),
		B(SS),
		B(PBE),
		B(SMEP)
	);
	if (BMI1 || BMI2) {
		if (BMI1) printf("BMI1");
		if (BMI2) printf(", BMI2");
		puts("");
	} else
		puts("None");

	return 0;
} // main

extern(C) immutable(char)* B(uint c) pure @nogc nothrow {
	return c ? "Yes" : "No";
}

/// Print cpuid
extern(C) void printc(uint leaf) {
	__gshared uint a, b, c, d;
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

/*****************************
 * CPU INFO
 *****************************/

template BIT(int n) {
	enum { BIT = 1 << n }
}

pragma(inline, true)
extern (C)
void CPUID(uint l) {
	asm {
		mov EAX, l;
		mov ECX, 0;
		cpuid;
		mov a, EAX;
		mov b, EBX;
		mov c, ECX;
		mov d, EDX;
	} // no ret in case calling convention differs
	return;
}

__gshared uint a, b, c, d; // EAX to EDX

extern (C) void fetchInfo() {
	// Get processor vendor and processor brand string
	version (X86_64) asm {
		lea RDI, vendorString;
		mov EAX, 0;
		cpuid;
		mov [RDI], EBX;
		mov [RDI+4], EDX;
		mov [RDI+8], ECX;
		mov byte ptr [RDI+12], 0;

		lea RDI, cpuString;
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
	} else asm {
		lea EDI, vendorString;
		mov EAX, 0;
		cpuid;
		mov [EDI], EBX;
		mov [EDI+4], EDX;
		mov [EDI+8], ECX;
		mov byte ptr [EDI+12], 0;

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

	// Why compare strings when you can just compare numbers?
	VendorID = *cast(uint*)vendorString; // Should be MOVXZ

	ubyte* bp = cast(ubyte*)&b;

	CPUID(1); // ----- 1H

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
	SSE3        = c & BIT!(0);
	PCLMULQDQ   = c & BIT!(1);
	MONITOR     = c & BIT!(3);
	SSSE3       = c & BIT!(9);
	FMA         = c & BIT!(12);
	CMPXCHG16B  = c & BIT!(13);
	SSE41       = c & BIT!(15);
	SSE42       = c & BIT!(20);
	MOVBE       = c & BIT!(22);
	POPCNT      = c & BIT!(23);
	AES         = c & BIT!(25);
	XSAVE       = c & BIT!(26);
	OSXSAVE     = c & BIT!(27);
	AVX         = c & BIT!(28);
	F16C        = c & BIT!(29);
	RDRAND      = c & BIT!(30);

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
		CPUID(6); // ----- 6H, avoids calling it if not Intel, for now
		TurboBoost = a & BIT!(1);
		break;
	default:
	}

	CPUID(7); // ----- 7H

	BMI1   = b & BIT!(4);
	AVX2   = b & BIT!(5);
	SMEP   = b & BIT!(7);
	BMI2   = b & BIT!(8);
	RDSEED = b & BIT!(18);
	
	/*
	 * Extended CPUID leafs
	 */

	CPUID(0x8000_0001); // EXTENDED 1H

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

	CPUID(0x8000_0007); // EXTENDED 7H

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

__gshared:

// ---- Basic information ----
/// Processor vendor
char[13] vendorString;
/// Processor brand string
char[49] cpuString;

/// Maximum leaf supported by this processor.
uint MaximumLeaf;
/// Maximum extended leaf supported by this processor.
uint MaximumExtendedLeaf;

/// Number of physical cores.
//ushort NumberOfCores;
/// Number of logical cores.
//ushort NumberOfThreads;

/// Processor family. ID and extended ID included.
ubyte Family;
/// Base Family ID
ubyte BaseFamily;
/// Extended Family ID
ubyte ExtendedFamily;
/// Processor model. ID and extended ID included.
ubyte Model;
/// Base Model ID
ubyte BaseModel;
/// Extended Model ID
ubyte ExtendedModel;
/// Processor stepping.
ubyte Stepping;
/// Processor type.
ubyte ProcessorType;

/// MMX Technology.
uint MMX;
/// AMD MMX Extented set.
uint MMXExt;
/// Streaming SIMD Extensions.
uint SSE;
/// Streaming SIMD Extensions 2.
uint SSE2;
/// Streaming SIMD Extensions 3.
uint SSE3;
/// Supplemental Streaming SIMD Extensions 3 (SSSE3).
uint SSSE3;
/// Streaming SIMD Extensions 4.1.
uint SSE41;
/// Streaming SIMD Extensions 4.2.
uint SSE42;
/// Streaming SIMD Extensions 4a. AMD only.
uint SSE4a;
/// AES instruction extensions.
uint AES;
/// AVX instruction extensions.
uint AVX;
/// AVX2 instruction extensions.
uint AVX2;

/// 3DNow! extension. AMD only. Deprecated in 2010.
uint _3DNow;
/// 3DNow! Extension supplements. See 3DNow!
uint _3DNowExt;

// ---- 01h ----
// -- EBX --
/// Brand index. See Table 3-24. If 0, use normal BrandString.
ubyte BrandIndex;
/// The CLFLUSH line size. Multiply by 8 to get its size in bytes.
ubyte CLFLUSHLineSize;
/// Maximum number of addressable IDs for logical processors in this physical package.
ubyte MaxIDs;
/// Initial APIC ID that the process started on.
ubyte InitialAPICID;

// -- ECX --
/// PCLMULQDQ instruction.
ubyte PCLMULQDQ; // 1
/// 64-bit DS Area (64-bit layout).
ubyte DTES64;
/// MONITOR/MWAIT.
ubyte MONITOR;
/// CPL Qualified Debug Store.
ubyte DS_CPL;
/// Virtualization | Virtual Machine eXtensions (Intel) | Secure Virtual Machine (AMD) 
ubyte Virt;
/// Safer Mode Extensions. Intel TXT/TPM
ubyte SMX;
/// Enhanced Intel SpeedStep® Technology.
ubyte EIST;
/// Thermal Monitor 2.
ushort TM2;
/// L1 Context ID.
ushort CNXT_ID;
/// Indicates the processor supports IA32_DEBUG_INTERFACE MSR for silicon debug.
ushort SDBG;
/// FMA extensions using YMM state.
ushort FMA;
/// Four-operand FMA instruction support.
uint FMA4;
/// CMPXCHG16B instruction.
uint CMPXCHG16B;
/// xTPR Update Control.
uint xTPR;
/// Perfmon and Debug Capability.
uint PDCM;
/// Process-context identifiers.
uint PCID;
/// Direct Cache Access.
uint DCA;
/// x2APIC feature (Intel programmable interrupt controller).
uint x2APIC;
/// MOVBE instruction.
uint MOVBE;
/// POPCNT instruction.
uint POPCNT;
/// Indicates if the APIC timer supports one-shot operation using a TSC deadline value.
uint TscDeadline;
/// Indicates the support of the XSAVE/XRSTOR extended states feature, XSETBV/XGETBV instructions, and XCR0.
uint XSAVE;
/// Indicates if the OS has set CR4.OSXSAVE[18] to enable XSETBV/XGETBV instructions for XCR0 and XSAVE.
uint OSXSAVE;
/// 16-bit floating-point conversion instructions.
uint F16C;
/// RDRAND instruction.
uint RDRAND; // 30

// -- EDX --
/// Floating Point Unit On-Chip. The processor contains an x87 FPU.
ubyte FPU; // 0
/// Virtual 8086 Mode Enhancements.
ubyte VME;
/// Debugging Extensions.
ubyte DE;
/// Page Size Extension.
ubyte PSE;
/// Time Stamp Counter.
ubyte TSC;
/// Model Specific Registers RDMSR and WRMSR Instructions. 
ubyte MSR;
/// Physical Address Extension.
ubyte PAE;
/// Machine Check Exception.
ubyte MCE;
/// CMPXCHG8B Instruction.
ushort CX8;
/// Indicates if the processor contains an Advanced Programmable Interrupt Controller.
ushort APIC;
/// SYSENTER and SYSEXIT Instructions.
ushort SEP;
/// Memory Type Range Registers.
ushort MTRR;
/// Page Global Bit.
ushort PGE;
/// Machine Check Architecture.
ushort MCA;
/// Conditional Move Instructions.
ushort CMOV;
/// Page Attribute Table.
uint PAT;
/// 36-Bit Page Size Extension.
uint PSE_36;
/// Processor Serial Number. Only Pentium 3 used this.
uint PSN;
/// CLFLUSH Instruction.
uint CLFSH;
/// Debug Store.
uint DS;
/// Thermal Monitor and Software Controlled Clock Facilities.
uint APCI;
/// FXSAVE and FXRSTOR Instructions.
uint FXSR;
/// Self Snoop.
uint SS;
/// Max APIC IDs reserved field is Valid. 0 if only unicore.
uint HTT;
/// Thermal Monitor.
uint TM;
/// Pending Break Enable.
uint PBE; // 31

// ---- 06h ----
/// Turbo Boost Technology (Intel)
/// eq. to AMD's Core Performance Boost
ushort TurboBoost;


// ---- 07h ----
// -- EBX --
// Note: BMI1, BMI2, and SMEP were introduced in 4th Generation Core processors.
/// Bit manipulation group 1 instruction support.
ubyte BMI1; // 3
/// Supervisor Mode Execution Protection.
ubyte SMEP; // 7
/// Bit manipulation group 2 instruction support.
ushort BMI2; // 8

// ---- 8000_0001 ----
// ECX
/// Advanced Bit Manipulation under AMD. LZCUNT under Intel.
ubyte LZCNT;
/// PREFETCHW under Intel. 3DNowPrefetch under AMD.
ushort PREFETCHW; // 8

/// RDSEED instruction
uint RDSEED;
// EDX
/// Intel: Execute Disable Bit. AMD: No-execute page protection.
uint NX; // 20
/// 1GB Pages
uint Page1GB; // 26
/// Also known as Intel64 or AMD64.
uint LongMode; // 29

// ---- 8000_0007 ----
/// TSC Invariation support
ushort TscInvariant; // 8