import core.stdc.stdio : printf, puts;
import core.stdc.stdlib : exit;
import core.stdc.string : strncmp;

enum VERSION = "0.6.2"; /// Program version

enum
	MAX_LEAF = 0x20, /// Maximum leaf (-o)
	MAX_ELEAF = 0x8000_0020; /// Maximum extended leaf (-o)

// UPDATE 2018-02-22: These were used to compare vendors, see enum below
/*enum { // Vendor strings
	/*VENDOR_INTEL     = cast(char*)"GenuineIntel", /// Intel
	VENDOR_AMD       = cast(char*)"AuthenticAMD", /// AMD
	VENDOR_VIA       = cast(char*)"VIA VIA VIA ", /// VIA
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
enum : uint {
	OTHER = 0,
	VENDOR_INTEL = 0x756e6547, // "Genu" LE
	VENDOR_AMD = 0x68747541, // "Auth" LE
	VENDOR_VIA = 0x20414956 // "VIA " LE
}
__gshared uint VendorID; /// Vendor "ID"

__gshared byte Raw = 0; /// Raw option (-r)
__gshared byte Details = 0; /// Detailed output option (-d)
__gshared byte Override = 0; /// Override max leaf option (-o)

extern(C) void sa(char* a) {
	while (*++a != 0) {
		switch (*a) {
		case 'o': ++Override; break;
		case 'd': ++Details; break;
		case 'r': ++Raw; break;
		case 'h', '?': help; return;
		case 'v': _version; return;
		default:
			printf("Unknown parameter: %c\n", *a);
			exit(0);
		}
	}
}

extern(C) void sb(char* a) {
	if (strncmp(a, "help", 4) == 0)
		help;
	if (strncmp(a, "version", 7) == 0)
		_version;
	printf("Unknown parameter: %s\n", a);
	exit(0);
}

extern(C) void help() {
	puts(
`CPUID information tool.
  Usage: ddcpuid OPTIONS

  -d    Show more, detailed information
  -r    Only show raw CPUID data
  -o    Override leaves, useful along -r
        Respectively to 20h and 8000_0020h

  -v, --version   Print version information
  -h, --help      Print this help screen`
	);
	exit(0);
}

extern(C) void _version() {
	puts(
`ddcpuid v` ~ VERSION ~ ` (` ~ __TIMESTAMP__ ~ `)
Copyright (c) dd86k 2016-2018
License: MIT License <http://opensource.org/licenses/MIT>
Project page: <https://github.com/dd86k/ddcpuid>
Compiler: ` ~ __VENDOR__
	);
	exit(0);
}

//TODO: Add AMD Fn8000_001F_EAX
//      SVM version

extern(C) int main(int argc, char** argv) {
	while (--argc >= 1) {
		if (argv[argc][1] == '-') {
			sb(argv[argc] + 2); continue;
		} else if (argv[argc][0] == '-') {
			sa(argv[argc]); continue;
		}
	}

	if (Override) {
		MaximumLeaf = MAX_LEAF;
		MaximumExtendedLeaf = MAX_ELEAF;
	} else {
		MaximumLeaf = getHighestLeaf;
		MaximumExtendedLeaf = getHighestExtendedLeaf;
	}

	if (Raw) { // -r
		puts(
`| Leaf     | EAX      | EBX      | ECX      | EDX      |
|----------|----------|----------|----------|----------|`
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

	printf(
`Vendor: %s
String: %s
Identifier: Family %d Model %d Stepping %d
            %Xh [%Xh:%Xh] %Xh [%Xh:%Xh] %Xh
`,
		cast(char*)vendorString, cast(char*)cpuString,
		Family, Model, Stepping,
		Family, BaseFamily, ExtendedFamily,
		Model, BaseModel, ExtendedModel, Stepping
	);

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

	extern (C) immutable(char)* _pt() { // Forgive me
		switch (ProcessorType) { // 2 bit value
		case 0: return "Original OEM Processor";
		case 1: return "Intel OverDrive Processor";
		case 2: return "Dual processor";
		case 3: return "Intel reserved";
		default: return "ERROR";
		}
	}

	printf(
`

Highest Leaf: %02Xh | Extended: %08Xh
Processor type: %s
  
Processor technologies
`,
		MaximumLeaf, MaximumExtendedLeaf, _pt
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

	if (Details) {
		printf( // FPU
`
FPU
  Floating Point Unit [FPU]: %s
  16-bit conversion [F16]: %s
`,
			B(FPU),
			B(F16C)
		);

		printf( // APCI
`
APCI
  APCI: %s
  APIC: %s (Initial ID: %d, Max: %d)
  x2APIC: %s
  Thermal Monitor: %s
  Thermal Monitor 2: %s
`,
			B(APCI),
			B(APIC),
			InitialAPICID, MaxIDs, B(x2APIC),
			B(TM),
			B(TM2)
		);

		printf( // Virtualization
`
Virtualization
  Virtual 8086 Mode Enhancements [VME]: %s
`,
			B(VME)
		);

		printf( // Memory
`
Memory and Paging
  Page Size Extension [PAE]: %s
  36-Bit Page Size Extension [PSE-36]: %s
  1 GB Pages support [Page1GB]: %s
  Direct Cache Access [DCA]: %s
  Page Attribute Table [PAT]: %s
  Memory Type Range Registers [MTRR]: %s
  Page Global Bit [PGE]: %s, 
  64-bit DS Area [DTES64]: %s
`,
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
`
Debugging
  Machine Check Exception [MCE]: %s
  Debugging Extensions [DE]: %s
  Debug Store [DS]: %s
  Debug Store CPL [DS-CPL]: %s
  Perfmon and Debug Capability [PDCM]: %s
  IA32_DEBUG_INTERFACE (MSR) [SDBG]: %s
`,
			B(MCE),
			B(DE),
			B(DS),
			B(DS_CPL),
			B(PDCM),
			B(SDBG)
		);

		printf( // Other features
`
Other features
  Brand Index: %d
  L1 Context ID [CNXT-ID]: %s
  xTPR Update Control [xTPR]: %s
  Process-context identifiers [PCID]: %s
  Machine Check Architecture [MCA]: %s
  Processor Serial Number [PSN]: %s
  Self Snoop [SS]: %s
  Pending Break Enable [PBE]: %s
  Supervisor Mode Execution Protection [SMEP]: %s
  Bit manipulation groups: `,
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
	} // if (det)

	return 0;
} // main

extern(C) immutable(char)* B(uint c) pure {
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

extern(C) void fetchInfo() {
	// Get Processor Vendor
	version (X86_64) asm {
		lea RDI, vendorString;
		mov EAX, 0;
		cpuid;
		mov [RDI], EBX;
		mov [RDI+4], EDX;
		mov [RDI+8], ECX;
	} else asm {
		lea EDI, vendorString;
		mov EAX, 0;
		cpuid;
		mov [EDI], EBX;
		mov [EDI+4], EDX;
		mov [EDI+8], ECX;
	}

	// Get Processor Brand String
	version (X86_64) asm {
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
	} else asm @nogc {
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
	}

	// Why compare strings when you can just compare numbers?
	VendorID = *cast(uint*)vendorString;

	__gshared uint a, b, c, d; // EAX to EDX
	ubyte* bp = cast(ubyte*)&b;

	__gshared uint l = 1; // CPUID.0 already been processed
	do {
		asm {
			mov EAX, l;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
			mov b, EBX;
			mov c, ECX;
			mov d, EDX;
		}

		switch (l) {
		case 1:
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
				DTES64  = c & 4;
				DS_CPL  = c & 0x10;
				Virt    = c & 0x20;
				SMX     = c & 0x40;
				EIST    = c & 0x80;
				TM2     = c & 0x100;
				CNXT_ID = c & 0x400;
				SDBG    = c & 0x800;
				xTPR    = c & 0x4000;
				PDCM    = c & 0x8000;
				PCID    = c & 0x2_0000;
				DCA     = c & 0x4_0000;
				x2APIC  = c & 0x20_0000;

				// EDX
				PSN     = d & 0x4_0000;
				DS      = d & 0x20_0000;
				APCI    = d & 0x40_0000;
				TscDeadline = c & 0x100_0000;
				SS      = d & 0x800_0000;
				TM      = d & 0x2000_0000;
				PBE     = d & 0x8000_0000;
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
			SSE3        = c & 1;
			PCLMULQDQ   = c & 2;
			MONITOR     = c & 8;
			SSSE3       = c & 0x200;
			FMA         = c & 0x1000;
			CMPXCHG16B  = c & 0x2000;
			SSE41       = c & 0x8_0000;
			SSE42       = c & 0x10_0000;
			MOVBE       = c & 0x40_0000;
			POPCNT      = c & 0x80_0000;
			AES         = c & 0x200_0000;
			XSAVE       = c & 0x400_0000;
			OSXSAVE     = c & 0x800_0000;
			AVX         = c & 0x1000_0000;
			F16C        = c & 0x2000_0000;
			RDRAND      = c & 0x4000_0000;
			// EDX
			FPU    = d & 1;
			VME    = d & 2;
			DE     = d & 4;
			PSE    = d & 8;
			TSC    = d & 0x10;
			MSR    = d & 0x20;
			PAE    = d & 0x40;
			MCE    = d & 0x80;
			CX8    = d & 0x100;
			APIC   = d & 0x200;
			SEP    = d & 0x800;
			MTRR   = d & 0x1000;
			PGE    = d & 0x2000;
			MCA    = d & 0x4000;
			CMOV   = d & 0x8000;
			PAT    = d & 0x1_0000;
			PSE_36 = d & 0x2_0000;
			CLFSH  = d & 0x8_0000;
			MMX    = d & 0x80_0000;
			FXSR   = d & 0x100_0000;
			SSE    = d & 0x200_0000;
			SSE2   = d & 0x400_0000;
			HTT    = d & 0x1000_0000;
			break;

		case 6:
			switch (VendorID) {
			case VENDOR_INTEL:
				TurboBoost = a & 2;
				break;
			default:
			}
			break;

		case 7:
			BMI1 = b & 8;
			AVX2 = b & 0x20;
			SMEP = b & 0x80;
			BMI2 = b & 0x100;
			RDSEED = b & 0x4_0000;
			break;

			default:
		}
	} while (++l <= MaximumLeaf);
	
	/*
	 * Extended CPUID leafs
	 */

	l = 0x8000_0000;
	do {
		asm @nogc {
			mov EAX, l;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
			mov b, EBX;
			mov c, ECX;
			mov d, EDX;
		}

		switch (l) {
		case 0x8000_0001:
			switch (VendorID) {
			case VENDOR_AMD:
				Virt  = c & 4; // SVM
				SSE4a = c & 0x40;
				FMA4  = c & 0x1_0000;

				MMXExt    = d & 0x40_0000;
				_3DNowExt = d & 0x4000_0000;
				_3DNow    = d & 0x8000_0000;
				break;
			default:
			}

			LZCNT     = c & 0x20;
			PREFETCHW = c & 0x100;

			NX       = d & 0x10_0000;
			Page1GB  = d & 0x400_0000;
			LongMode = d & 0x2000_0000;
			break;

		case 0x8000_0007:
			switch (VendorID) {
			case VENDOR_INTEL:
				RDSEED = b & 0x4_0000;
				break;
			case VENDOR_AMD:
				TM = d & 0x10;
				TurboBoost = d & 0x200;
				break;
			default:
			}

			TscInvariant = d & 0x100;
			break;
		default:
		}
	} while (++l <= MaximumExtendedLeaf);
}

/***************************
 * Properties
 ***************************/

// ---- Basic information ----
/// Processor vendor.
__gshared char[13] vendorString; // null-padded
/// Processor brand string.
__gshared char[49] cpuString; // ditto

/// Maximum leaf supported by this processor.
__gshared uint MaximumLeaf;
/// Maximum extended leaf supported by this processor.
__gshared uint MaximumExtendedLeaf;

/// Number of physical cores.
//__gshared ushort NumberOfCores;
/// Number of logical cores.
//__gshared ushort NumberOfThreads;

/// Processor family. ID and extended ID included.
__gshared ubyte Family;
/// Base Family ID
__gshared ubyte BaseFamily;
/// Extended Family ID
__gshared ubyte ExtendedFamily;
/// Processor model. ID and extended ID included.
__gshared ubyte Model;
/// Base Model ID
__gshared ubyte BaseModel;
/// Extended Model ID
__gshared ubyte ExtendedModel;
/// Processor stepping.
__gshared ubyte Stepping;
/// Processor type.
__gshared ubyte ProcessorType;

/// MMX Technology.
__gshared uint MMX;
/// AMD MMX Extented set.
__gshared uint MMXExt;
/// Streaming SIMD Extensions.
__gshared uint SSE;
/// Streaming SIMD Extensions 2.
__gshared uint SSE2;
/// Streaming SIMD Extensions 3.
__gshared uint SSE3;
/// Supplemental Streaming SIMD Extensions 3 (SSSE3).
__gshared uint SSSE3;
/// Streaming SIMD Extensions 4.1.
__gshared uint SSE41;
/// Streaming SIMD Extensions 4.2.
__gshared uint SSE42;
/// Streaming SIMD Extensions 4a. AMD only.
__gshared uint SSE4a;
/// AES instruction extensions.
__gshared uint AES;
/// AVX instruction extensions.
__gshared uint AVX;
/// AVX2 instruction extensions.
__gshared uint AVX2;

/// 3DNow! extension. AMD only. Deprecated in 2010.
__gshared uint _3DNow;
/// 3DNow! Extension supplements. See 3DNow!
__gshared uint _3DNowExt;

// ---- 01h ----
// -- EBX --
/// Brand index. See Table 3-24. If 0, use normal BrandString.
__gshared ubyte BrandIndex;
/// The CLFLUSH line size. Multiply by 8 to get its size in bytes.
__gshared ubyte CLFLUSHLineSize;
/// Maximum number of addressable IDs for logical processors in this physical package.
__gshared ubyte MaxIDs;
/// Initial APIC ID that the process started on.
__gshared ubyte InitialAPICID;
// -- ECX --
/// PCLMULQDQ instruction.
__gshared uint PCLMULQDQ; // 1
/// 64-bit DS Area (64-bit layout).
__gshared uint DTES64;
/// MONITOR/MWAIT.
__gshared uint MONITOR;
/// CPL Qualified Debug Store.
__gshared uint DS_CPL;
/// Virtualization | Virtual Machine eXtensions (Intel) | Secure Virtual Machine (AMD) 
__gshared uint Virt;
/// Safer Mode Extensions. Intel TXT/TPM
__gshared uint SMX;
/// Enhanced Intel SpeedStep® Technology.
__gshared uint EIST;
/// Thermal Monitor 2.
__gshared uint TM2;
/// L1 Context ID.
__gshared uint CNXT_ID;
/// Indicates the processor supports IA32_DEBUG_INTERFACE MSR for silicon debug.
__gshared uint SDBG;
/// FMA extensions using YMM state.
__gshared uint FMA;
/// Four-operand FMA instruction support.
__gshared uint FMA4;
/// CMPXCHG16B instruction.
__gshared uint CMPXCHG16B;
/// xTPR Update Control.
__gshared uint xTPR;
/// Perfmon and Debug Capability.
__gshared uint PDCM;
/// Process-context identifiers.
__gshared uint PCID;
/// Direct Cache Access.
__gshared uint DCA;
/// x2APIC feature (Intel programmable interrupt controller).
__gshared uint x2APIC;
/// MOVBE instruction.
__gshared uint MOVBE;
/// POPCNT instruction.
__gshared uint POPCNT;
/// Indicates if the APIC timer supports one-shot operation using a TSC deadline value.
__gshared uint TscDeadline;
/// Indicates the support of the XSAVE/XRSTOR extended states feature, XSETBV/XGETBV instructions, and XCR0.
__gshared uint XSAVE;
/// Indicates if the OS has set CR4.OSXSAVE[18] to enable XSETBV/XGETBV instructions for XCR0 and XSAVE.
__gshared uint OSXSAVE;
/// 16-bit floating-point conversion instructions.
__gshared uint F16C;
/// RDRAND instruction.
__gshared uint RDRAND; // 30
// -- EDX --
/// Floating Point Unit On-Chip. The processor contains an x87 FPU.
__gshared uint FPU; // 0
/// Virtual 8086 Mode Enhancements.
__gshared uint VME;
/// Debugging Extensions.
__gshared uint DE;
/// Page Size Extension.
__gshared uint PSE;
/// Time Stamp Counter.
__gshared uint TSC;
/// Model Specific Registers RDMSR and WRMSR Instructions. 
__gshared uint MSR;
/// Physical Address Extension.
__gshared uint PAE;
/// Machine Check Exception.
__gshared uint MCE;
/// CMPXCHG8B Instruction.
__gshared uint CX8;
/// Indicates if the processor contains an Advanced Programmable Interrupt Controller.
__gshared uint APIC;
/// SYSENTER and SYSEXIT Instructions.
__gshared uint SEP;
/// Memory Type Range Registers.
__gshared uint MTRR;
/// Page Global Bit.
__gshared uint PGE;
/// Machine Check Architecture.
__gshared uint MCA;
/// Conditional Move Instructions.
__gshared uint CMOV;
/// Page Attribute Table.
__gshared uint PAT;
/// 36-Bit Page Size Extension.
__gshared uint PSE_36;
/// Processor Serial Number. Only Pentium 3 used this.
__gshared uint PSN;
/// CLFLUSH Instruction.
__gshared uint CLFSH;
/// Debug Store.
__gshared uint DS;
/// Thermal Monitor and Software Controlled Clock Facilities.
__gshared uint APCI;
/// FXSAVE and FXRSTOR Instructions.
__gshared uint FXSR;
/// Self Snoop.
__gshared uint SS;
/// Max APIC IDs reserved field is Valid. 0 if only unicore.
__gshared uint HTT;
/// Thermal Monitor.
__gshared uint TM;
/// Pending Break Enable.
__gshared uint PBE; // 31

// ---- 06h ----
/// Turbo Boost Technology (Intel)
/// Re-using the name for AMD's Core Performance Boost
__gshared uint TurboBoost;


// ---- 07h ----
// -- EBX --
// Note: BMI1, BMI2, and SMEP were introduced in 4th Generation Core processors.
/// Bit manipulation group 1 instruction support.
__gshared uint BMI1; // 3
/// Supervisor Mode Execution Protection.
__gshared uint SMEP; // 7
/// Bit manipulation group 2 instruction support.
__gshared uint BMI2; // 8

// ---- 8000_0001 ----
// ECX
/// Advanced Bit Manipulation under AMD. LZCUNT under Intel.
__gshared uint LZCNT;
/// PREFETCHW under Intel. 3DNowPrefetch under AMD.
__gshared uint PREFETCHW; // 8

/// RDSEED instruction
__gshared uint RDSEED;
// EDX
/// Intel: Execute Disable Bit. AMD: No-execute page protection.
__gshared uint NX; // 20
/// 1GB Pages
__gshared uint Page1GB; // 26
/// Also known as Intel64 or AMD64.
__gshared uint LongMode; // 29

// ---- 8000_0007 ----
/// TSC Invariation support
__gshared uint TscInvariant; // 8

/// Get the maximum leaf.
/// Returns: Maximum leaf
extern (C) uint getHighestLeaf() {
	asm { naked;
		mov EAX, 0;
		cpuid;
		ret;
	}
}

/// Get the maximum extended leaf.
/// Returns: Maximum extended leaf
extern (C) uint getHighestExtendedLeaf() {
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
 *   -2 = Feature not supported.
 */
/*extern (C) short getCoresIntel() {
	asm { naked;
		mov EAX, 0;
		cpuid;
		cmp EAX, 0xB;
		jge INTEL_S;
		mov AX, -2; //TODO: go accross NUMA nodes instead
		ret;
INTEL_S:
		mov EAX, 0xB;
		mov ECX, 1;
		cpuid;
		mov AX, BX;
		ret;
	}
}*/