extern (C):

int strcmp(scope const char*, scope const char*);
int printf(scope const char*, ...);
int puts(scope const char*);
int putchar(int c);
void* memset(void *, int, size_t);

//TODO: Rely on bitflags instead of bytes, which could increase memset runtime
// Solution 1: u32 per sections (memory, acpi, etc.)

enum VERSION = "0.13.0"; /// Program version
enum	MAX_LEAF  = 0x20, /// Maximum leaf (-o)
	MAX_ELEAF = 0x8000_0020; /// Maximum extended leaf (-o)

/*
 * Self-made vendor "IDs" for faster look-ups, LSB-based.
 *
 * NOTE:
 * If another vendor starts with the same 4 first characters, check with the
 * last 4 characters, then 4 middle characters (as, e.g. VENDOR_INTEL3 and
 * then VENDOR_INTEL2).
 */
enum VENDOR_OTHER = 0;	/// Other/unknown
enum VENDOR_INTEL = 0x756e6547;	/// Intel: "Genu"
enum VENDOR_AMD   = 0x68747541;	/// AMD: "Auth"
enum VENDOR_VIA   = 0x20414956;	/// VIA: "VIA "

version (X86) {
	enum PLATFORM = "x86";
} else
version (X86_64) {
	enum PLATFORM = "amd64";
} else
	static assert(0,
		"ddcpuid is only supported on x86 and amd64 platforms.");

template BIT(int n) { enum { BIT = 1 << n } }

ubyte CHECK(int n, int f) pure @nogc nothrow {
	return (n & f) != 0;
}

__gshared uint VendorID; /// Vendor "ID", inits to VENDOR_OTHER

void shelp() {
	puts(
	"x86/AMD64 CPUID information tool\n"~
	"  Usage: ddcpuid [OPTIONS]\n"~
	"\n"~
	"OPTIONS\n"~
	"  -r    Show raw CPUID data in a table\n"~
	"  -o    Override leaves to 20h and 8000_0020h\n"~
	"\n"~
	"  --version    Print version information screen and quit\n"~
	"  -h, --help   Print this help screen and quit"
	);
}

void sversion() {
	import d = std.compiler;
	printf(
	"ddcpuid-"~PLATFORM~" v"~VERSION~" ("~__TIMESTAMP__~")\n"~
	"Copyright (c) dd86k 2016-2019\n"~
	"License: MIT License <http://opensource.org/licenses/MIT>\n"~
	"Project page: <https://github.com/dd86k/ddcpuid>\n"~
	"Compiler: "~ __VENDOR__ ~" v%u.%03u\n",
	d.version_major, d.version_minor
	);
}

/// Print cpuid info
void printc(uint leaf) {
	uint a = void, b = void, c = void, d = void;
	version (GNU) asm {
		"cpuid\n"
		: "=a" a, "=b" b, "=c" c, "=d" d
		: "a" leaf;
	} else asm {
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

//TODO: (AMD) APICv (AVIC) Fn8000_000A_EDX[13], Intel has no bit for APICv
// GAS reminder: asm { "asm" : output : input : clobber }

int main(int argc, char **argv) {
	bool opt_raw;	/// Raw option (-r), table option
	// See Intel(R) Architecture Instruction Set Extensions and Future
	// Features Programming Reference
	bool opt_override;	/// opt_override max leaf option (-o)

	while (--argc >= 1) { // CLI
		if (argv[argc][1] == '-') { // Long arguments
			char* a = argv[argc] + 2;
			if (strcmp(a, "help") == 0) {
				shelp; return 0;
			}
			if (strcmp(a, "version") == 0) {
				sversion; return 0;
			}
			printf("Unknown parameter: %s\n", a);
			return 1;
		} else if (argv[argc][0] == '-') { // Short arguments
			char* a = argv[argc];
			while (*++a != 0) switch (*a) {
			case 'o': opt_override = true; break;
			case 'r': opt_raw = true; break;
			case 'h', '?': shelp; return 0;
			default:
				printf("Unknown parameter: %c\n", *a);
				return 1;
			} // while+switch
		} // else if
	} // while arg

	CPUINFO s = void;
	memset(&s, 0, s.sizeof);

	if (opt_override) {
		s.MaximumLeaf = MAX_LEAF;
		s.MaximumExtendedLeaf = MAX_ELEAF;
	} else {
		s.MaximumLeaf = hleaf;
		s.MaximumExtendedLeaf = heleaf;
		assert(s.MaximumLeaf > 0); // Mostly due to LDC
	}

	if (opt_raw) { // -r
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

	fetchInfo(s);

	const(char) *cstring = cast(const(char)*)s.cpuString;

	switch (VendorID) {
	case VENDOR_INTEL: // Common in Intel processor brand strings
		while (*cstring == ' ') ++cstring; // left trim cpu string
		break;
	default:
	}

	// -- Processor basic information --

	printf(
	"[Vendor] %.12s\n"~
	"[String] %.48s\n"~
	"[Identifier] Family %u (%Xh) [%Xh:%Xh] Model %u (%Xh) [%Xh:%Xh] Stepping %u\n"~
	"[Extensions]",
	cast(char*)s.vendorString, cstring,
	s.Family, s.Family, s.BaseFamily, s.ExtendedFamily,
	s.Model, s.Model, s.BaseModel, s.ExtendedModel,
	s.Stepping
	);

	if (s.FPU) {
		printf(" x87/FPU");
		if (s.F16C) printf(" +F16C");
	}
	if (s.MMX) printf(" MMX");
	if (s.MMXExt) printf(" Ext.MMX");
	if (s._3DNow) printf(" 3DNow!");
	if (s._3DNowExt) printf(" Ext.3DNow!");
	if (s.SSE) printf(" SSE");
	if (s.SSE2) printf(" SSE2");
	if (s.SSE3) printf(" SSE3");
	if (s.SSSE3) printf(" SSSE3");
	if (s.SSE41) printf(" SSE4.1");
	if (s.SSE42) printf(" SSE4.2");
	if (s.SSE4a) printf(" SSE4a");
	if (s.LongMode)
		switch (VendorID) {
		case VENDOR_INTEL: printf(" Intel64/x86-64"); break;
		case VENDOR_AMD: printf(" AMD64/x86-64"); break;
		default: printf(" x86-64");
		}
	if (s.Virt)
		switch (VendorID) {
		case VENDOR_INTEL: printf(" VT-x/VMX"); break; // VMX
		case VENDOR_AMD: // SVM
			printf(" AMD-V/VMX:v%u\n", s.VirtVersion);
			break;
		//case VENDOR_VIA: printf(" VIA-VT/VMX"); break; <- Uncomment when VIA
		default: printf(" VMX");
		}
	if (s.NX)
		switch (VendorID) {
		case VENDOR_INTEL: printf(" Intel-XD/NX"); break;
		case VENDOR_AMD: printf(" AMD-EVP/NX"); break;
		default: printf(" NX");
		}
	if (s.SMX) printf(" Intel-TXT/SMX");
	if (s.AES) printf(" AES-NI");
	if (s.AVX) printf(" AVX");
	if (s.AVX2) printf(" AVX2");
	if (s.AVX512F) {
		printf(" AVX512F");
		if (s.AVX512ER) printf(" AVX512ER");
		if (s.AVX512PF) printf(" AVX512PF");
		if (s.AVX512CD) printf(" AVX512CD");
		if (s.AVX512DQ) printf(" AVX512DQ");
		if (s.AVX512BW) printf(" AVX512BW");
		if (s.AVX512VL) printf(" AVX512VL");
		if (s.AVX512_IFMA) printf(" AVX512_IFMA");
		if (s.AVX512_VBMI) printf(" AVX512_VBMI");
		if (s.AVX512_4VNNIW) printf(" AVX512_4VNNIW");
		if (s.AVX512_4FMAPS) printf(" AVX512_4FMAPS");
		if (s.AVX512_VBMI2) printf(" AVX512_VBMI2");
		if (s.AVX512_GFNI) printf(" AVX512_GFNI");
		if (s.AVX512_VAES) printf(" AVX512_VAES");
		if (s.AVX512_VNNI) printf(" AVX512_VNNI");
		if (s.AVX512_BITALG) printf(" AVX512_BITALG");
	}
	if (s.FMA) printf(" FMA3");
	if (s.FMA4) printf(" FMA4");
	if (s.BMI1) printf(" BMI1");
	if (s.BMI2) printf(" BMI2");
	if (s.WAITPKG) printf(" WAITPKG");

	// -- Other instructions --

	printf("\n[Extra]");
	if (s.MONITOR) printf(" MONITOR+MWAIT");
	if (s.PCLMULQDQ) printf(" PCLMULQDQ");
	if (s.CX8) printf(" CMPXCHG8B");
	if (s.CMPXCHG16B) printf(" CMPXCHG16B");
	if (s.MOVBE) printf(" MOVBE"); // Intel Atom and quite a few AMD processors.
	if (s.RDRAND) printf(" RDRAND");
	if (s.RDSEED) printf(" RDSEED");
	if (s.MSR) printf(" RDMSR+WRMSR");
	if (s.SEP) printf(" SYSENTER+SYSEXIT");
	if (s.TSC) {
		printf(" RDTSC");
		if (s.TscDeadline)
			printf(" +TSC-Deadline");
		if (s.TscInvariant)
			printf(" +TSC-Invariant");
	}
	if (s.RDTSCP) printf(" RDTSCP");
	if (s.RDPID) printf(" RDPID");
	if (s.CMOV) {
		printf(" CMOV");
		if (s.FPU) printf(" FCOMI+FCMOV");
	}
	if (s.CLFSH) printf(" CLFLUSH:%uB", s.CLFLUSHLineSize * 8);
	if (s.PREFETCHW) printf(" PREFETCHW");
	if (s.LZCNT) printf(" LZCNT");
	if (s.POPCNT) printf(" POPCNT");
	if (s.XSAVE) printf(" XSAVE+XRSTOR");
	if (s.OSXSAVE) printf(" XSETBV+XGETBV");
	if (s.FXSR) printf(" FXSAVE+FXRSTOR");
	if (s.SHA) printf(" SHA");
	if (s.PCONFIG) printf(" PCONFIG");
	if (s.WBNOINVD) printf(" WBNOINVD");
	if (s.CLDEMOTE) printf(" CLDEMOTE");
	if (s.MOVDIRI) printf(" MOVDIRI");
	if (s.MOVDIR64B) printf(" MOVDIR64B");
	if (s.AVX512_VPOPCNTDQ) printf(" VPOPCNTDQ");

	// -- Vendor specific technologies ---

	printf("\n[Technologies]");

	switch (VendorID) {
	case VENDOR_INTEL:
		if (s.EIST) printf(" Enhanced-SpeedStep");
		if (s.TurboBoost) {
			printf(" TurboBoost");
			if (s.TurboBoost3) printf("-3.0");
		}
		if (s.HLE || s.RTM) printf(" Intel-TSX");
		if (s.SGX) printf(" Intel-SGX");
		break;
	case VENDOR_AMD:
		if (s.TurboBoost) printf(" Core-Performance-Boost");
		break;
	default:
	}

	// -- Cache information --

	printf("\n[Cache]");
	if (s.CNXT_ID) printf(" CNXT_ID");
	if (s.SS) printf(" SS");

	__gshared char []CACHE_TYPE = [ '?', 'D', 'I', 'U', '?', '?', '?', '?' ];

	CACHE *ca = cast(CACHE*)s.cache; /// Caches

	while (ca.type) {
		char c = 'K';
		if (ca.size >= 1024) {
			ca.size >>= 10; c = 'M';
		}
		printf("\n- L%u-%c: %u %cB, %u ways, %u partitions, %u B, %u sets",
			ca.level, CACHE_TYPE[ca.type], ca.size, c,
			ca.ways, ca.partitions, ca.linesize, ca.sets
		);
		if (ca.features & BIT!(0)) printf("\n\t- Self Initializing");
		if (ca.features & BIT!(1)) printf("\n\t- Fully Associative");
		if (ca.features & BIT!(2)) printf("\n\t- No Write-Back Validation");
		if (ca.features & BIT!(3)) printf("\n\t- Cache Inclusive");
		if (ca.features & BIT!(4)) printf("\n\t- Complex Cache Indexing");
		++ca;
	}

	printf("\n[ACPI]");
	if (s.ACPI) printf(" ACPI");
	if (s.APIC) printf(" APIC");
	if (s.x2APIC) printf(" x2APIC");
	if (s.ARAT) printf(" ARAT");
	if (s.TM) printf(" TM");
	if (s.TM2) printf(" TM2");
	if (s.InitialAPICID) printf(" APIC-ID:%u", s.InitialAPICID);
	if (s.MaxIDs) printf(" MAX-ID:%u", s.MaxIDs);

	printf("\n[Virtualization]");
	if (s.VME) printf(" VME");

	printf("\n[Memory]");
	if (s.PAE) printf(" PAE");
	if (s.PSE) printf(" PSE");
	if (s.PSE_36) printf(" PSE-36");
	if (s.Page1GB) printf(" Page1GB");
	if (s.DCA) printf(" DCA");
	if (s.PAT) printf(" PAT");
	if (s.MTRR) printf(" MTRR");
	if (s.PGE) printf(" PGE");
	if (s.SMEP) printf(" SMEP");
	if (s.SMAP) printf(" SMAP");
	if (s.PKU) printf(" PKU");
	if (s.HLE) printf(" HLE");
	if (s.RTM) printf(" RTM");
	if (s._5PL) printf(" 5PL");
	if (s.addr_phys_bits) printf(" P-Bits:%u", s.addr_phys_bits);
	if (s.addr_line_bits) printf(" L-Bits:%u", s.addr_line_bits);

	printf("\n[Debugging]");
	if (s.MCA) printf(" MCA");
	if (s.MCE) printf(" MCE");
	if (s.DE) printf(" DE");
	if (s.DS) printf(" DS");
	if (s.DS_CPL) printf(" DS_CPL");
	if (s.DTES64) printf(" DTES64");
	if (s.PDCM) printf(" PDCM");
	if (s.SDBG) printf(" SDBG");

	printf("\n[Security]");
	if (s.IBPB) printf(" IBPB");
	if (s.IBRS) printf(" IBRS");
	if (s.STIBP) printf(" STIBP");
	if (s.SSBD) printf(" SSBD");

	switch (VendorID) {
	case VENDOR_INTEL:
		if (s.L1D_FLUSH) printf(" L1D_FLUSH");
		break;
	case VENDOR_AMD:
		if (s.IBRS_ON) printf(" IBRS_ON");
		if (s.IBRS_PREF) printf(" IBRS_PREF");
		if (s.STIBP_ON) printf(" STIBP_ON");
		break;
	default:
	}

	__gshared const(char) *[]PROCESSOR_TYPE = [
		"Original", "OverDrive", "Dual", "Reserved"
	];

	printf("\n[Misc.] HLeaf:%Xh HELeaf:%Xh Type:%s Index:%u",
		s.MaximumLeaf, s.MaximumExtendedLeaf,
		PROCESSOR_TYPE[s.ProcessorType], s.BrandIndex
	);
	if (s.xTPR) printf(" xTPR");
	if (s.PCID) printf(" PCID");
	if (s.PSN) printf(" PSN");
	if (s.PBE) printf(" PBE");
	if (s.IA32_ARCH_CAPABILITIES) printf(" IA32_ARCH_CAPABILITIES");
	if (s.LAHF64) printf(" LAHF64+SAHF64");
	if (s.FSREPMOV) printf(" FSREPMOV");

	putchar('\n');

	return 0;
} // main

/**
 * Fetch CPU info
 * Params: s = CPUINFO structure
 */
void fetchInfo(ref CPUINFO s) {
	// Position Independant Code compliant
	size_t __A = cast(size_t)&s.vendorString;
	size_t __B = cast(size_t)&s.cpuString;

	// Get processor vendor and processor brand string
	version (X86_64) {
		version (GNU) asm {
			"mov %0, %%rdi\n"~
			"mov $0, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n"~
			"mov %%edx, 4(%%rdi)\n"~
			"mov %%ecx, 8(%%rdi)\n"~

			"mov %1, %%rdi\n"~
			"mov $0x80000002, %%eax\n"~
			"cpuid\n"~
			"mov %%eax, (%%rdi)\n"~
			"mov %%ebx, 4(%%rdi)\n"~
			"mov %%ecx, 8(%%rdi)\n"~
			"mov %%edx, 12(%%rdi)\n"~
			"mov $0x80000003, %%eax\n"~
			"cpuid\n"~
			"mov %%eax, 16(%%rdi)\n"~
			"mov %%ebx, 20(%%rdi)\n"~
			"mov %%ecx, 24(%%rdi)\n"~
			"mov %%edx, 28(%%rdi)\n"~
			"mov $0x80000004, %%eax\n"~
			"cpuid\n"~
			"mov %%eax, 32(%%rdi)\n"~
			"mov %%ebx, 36(%%rdi)\n"~
			"mov %%ecx, 40(%%rdi)\n"~
			"mov %%edx, 44(%%rdi)"
			:
			: "m" __A, "m" __B;
		} else asm {
			mov RDI, __A;
			mov EAX, 0;
			cpuid;
			mov [RDI], EBX;
			mov [RDI+4], EDX;
			mov [RDI+8], ECX;

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
		}
	} else { // version X86
		version (GNU) asm {
			"mov %0, %%edi\n"~
			"mov $0, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, disp(%%edi)\n"~
			"mov %%edx, disp(%%edi+4)\n"~
			"mov %%ecx, disp(%%edi+8)\n"~

			"mov %1, %%edi\n"~
			"mov $0x80000002, %%eax\n"~
			"cpuid\n"
			"mov %%eax, disp(%%edi)\n"~
			"mov %%ebx, disp(%%edi+4)\n"~
			"mov %%ecx, disp(%%edi+8)\n"~
			"mov %%edx, disp(%%edi+12)\n"~
			"mov $0x80000003, %%eax\n"~
			"cpuid\n"
			"mov %%eax, disp(%%edi+16)\n"~
			"mov %%ebx, disp(%%edi+20)\n"~
			"mov %%ecx, disp(%%edi+24)\n"~
			"mov %%edx, disp(%%edi+28)\n"~
			"mov $0x80000004, %%eax\n"~
			"cpuid\n"
			"mov %%eax, disp(%%edi+32)\n"~
			"mov %%ebx, disp(%%edi+36)\n"~
			"mov %%ecx, disp(%%edi+40)\n"~
			"mov %%edx, disp(%%edi+44)"
			:
			: "m" __A, "m" __B;
		} else asm {
			mov EDI, __A;
			mov EAX, 0;
			cpuid;
			mov [EDI], EBX;
			mov [EDI+4], EDX;
			mov [EDI+8], ECX;

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
		}
	}

	VendorID = *cast(uint*)s.vendorString;

	debug printf("VendorID: %X\n", VendorID);

	uint l; /// Cache level
	CACHE *ca = cast(CACHE*)s.cache;

	debug puts("--- Cache information ---");

	uint a = void, b = void, c = void, d = void; // EAX to EDX

	switch (VendorID) { // CACHE INFORMATION
	case VENDOR_INTEL:
		version (GNU) asm {
			"mov $4, %%eax\n"~
			"mov %4, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"~
			"mov %%ebx, %1\n"~
			"mov %%ecx, %2\n"~
			"mov %%edx, %3"
			: "=a" a, "=b" b, "=c" c, "=d" d
			: "m" l;
		} else asm {
			mov EAX, 4;
			mov ECX, l;
			cpuid;
			//cmp EAX, 0; // Check ZF
			//jz CACHE_DONE; // if EAX=0, get out
			mov a, EAX;
			mov b, EBX;
			mov c, ECX;
			mov d, EDX;
		}

		// Fix LDC2 compiling issue (#13)
		if (a == 0) goto default;

		ca.type = (a & 0xF);
		ca.level = cast(ubyte)((a >> 5) & 7);
		ca.linesize = cast(ubyte)((b & 0x7FF) + 1);
		ca.partitions = cast(ubyte)(((b >> 12) & 0x7FF) + 1);
		ca.ways = cast(ubyte)((b >> 22) + 1);
		ca.sets = cast(ushort)(c + 1);
		if (a & BIT!(8)) ca.features = 1;
		if (a & BIT!(9)) ca.features |= BIT!(1);
		if (d & BIT!(0)) ca.features |= BIT!(2);
		if (d & BIT!(1)) ca.features |= BIT!(3);
		if (d & BIT!(2)) ca.features |= BIT!(4);
		ca.size = (ca.sets * ca.linesize * ca.partitions * ca.ways) >> 10;

		debug printf("| %8X | %8X | %8X | %8X | %8X |\n", l, a, b, c, d);
		++l; ++ca;
		goto case VENDOR_INTEL;
	case VENDOR_AMD:
		ubyte _amd_ways_l2 = void; // please the compiler (for further goto)

		if (s.MaximumExtendedLeaf >= 0x8000_001D) goto CACHE_AMD_NEWER;

		version (GNU) asm {
			"mov $0x80000005, %%eax\n"~
			"cpuid\n"~
			"mov %%ecx, %0\n"~
			"mov %%edx, %1"
			: "=c" c, "=d" d;
		} else asm {
			mov EAX, 0x8000_0005;
			cpuid;
			mov c, ECX;
			mov d, EDX;
		}
		s.cache[0].level = s.cache[1].level = 1; // L1
		s.cache[0].type = 1; // data
		s.cache[0].__bundle1 = c;
		s.cache[0].size = s.cache[0]._amdsize;
		s.cache[1].__bundle1 = d;
		s.cache[1].size = s.cache[1]._amdsize;

		if (s.MaximumExtendedLeaf < 0x8000_0006) break; // No L2/L3

		// Old reference table
		// See Table E-4. L2/L3 Cache and TLB Associativity Field Encoding
		// Returns: n-ways
		extern (C)
		ubyte _amd_ways(ubyte w) {
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

		version (GNU) asm {
			"mov $0x80000006, %%eax\n"~
			"cpuid\n"~
			"mov %%ecx, %0\n"~
			"mov %%edx, %1"
			: "=c" c, "=d" d;
		} else asm { // AMD olde way
			mov EAX, 0x8000_0006;
			cpuid;
			mov c, ECX;
			mov d, EDX;
		}

		_amd_ways_l2 = (c >> 12) & 7;
		if (_amd_ways_l2) {
			s.cache[2].level = 2; // L2
			s.cache[2].type = 3; // unified
			s.cache[2].ways = _amd_ways(_amd_ways_l2);
			s.cache[2].size = c >> 16;
			s.cache[2].sets = (c >> 8) & 7;
			s.cache[2].linesize = cast(ubyte)c;

			ubyte _amd_ways_l3 = (d >> 12) & 0b111;
			if (_amd_ways_l3) {
				s.cache[3].level = 3; // L2
				s.cache[3].type = 3; // unified
				s.cache[3].ways = _amd_ways(_amd_ways_l3);
				s.cache[3].size = ((d >> 18) + 1) * 512;
				s.cache[3].sets = (d >> 8) & 7;
				s.cache[3].linesize = cast(ubyte)(d & 0x7F);
			}
		}

CACHE_AMD_NEWER:
		version (GNU) asm {
			"mov $0x8000001d, %%eax\n"~
			"mov %4, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"~
			"mov %%ebx, %1\n"~
			"mov %%ecx, %2\n"~
			"mov %%edx, %3"
			: "=a" a, "=b" b, "=c" c, "=d" d
			: "m" l;
		} else asm {
			mov EAX, 0x8000_001D;
			mov ECX, l;
			cpuid;
			mov a, EAX;
			mov b, EBX;
			mov c, ECX;
			mov d, EDX;
		}
		// Fix LDC2 compiling issue (#13)
		// LDC has some trouble jumping to an exterior label
		if (a == 0) goto default;

		ca.type = (a & 0xF); // Same as Intel
		ca.level = cast(ubyte)((a >> 5) & 7);
		ca.linesize = cast(ubyte)((b & 0x7FF) + 1);
		ca.partitions = cast(ubyte)(((b >> 12) & 0x7FF) + 1);
		ca.ways = cast(ubyte)((b >> 22) + 1);
		ca.sets = cast(ushort)(c + 1);
		if (a & BIT!(8)) ca.features = 1;
		if (a & BIT!(9)) ca.features |= BIT!(1);
		if (d & BIT!(0)) ca.features |= BIT!(2);
		if (d & BIT!(1)) ca.features |= BIT!(3);
		ca.size = (ca.sets * ca.linesize * ca.partitions * ca.ways) >> 10;

		debug printf("| %8X | %8X | %8X | %8X | %8X |\n", l, a, b, c, d);
		++l; ++ca;
		goto CACHE_AMD_NEWER;
	default:
	}

	version (GNU) asm {
		"mov $1, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%ebx, %1\n"~
		"mov %%ecx, %2\n"~
		"mov %%edx, %3" : "=a" a, "=b" b, "=c" c, "=d" d;
	} else asm {
		mov EAX, 1;
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
		s.DTES64      = CHECK(c, BIT!(2));
		s.DS_CPL      = CHECK(c, BIT!(4));
		s.Virt        = CHECK(c, BIT!(5));
		s.SMX         = CHECK(c, BIT!(6));
		s.EIST        = CHECK(c, BIT!(7));
		s.TM2         = CHECK(c, BIT!(8));
		s.CNXT_ID     = CHECK(c, BIT!(10));
		s.SDBG        = CHECK(c, BIT!(11));
		s.xTPR        = CHECK(c, BIT!(14));
		s.PDCM        = CHECK(c, BIT!(15));
		s.PCID        = CHECK(c, BIT!(17));
		s.DCA         = CHECK(c, BIT!(18));
		s.x2APIC      = CHECK(c, BIT!(21));
		s.TscDeadline = CHECK(c, BIT!(24));

		// EDX
		s.PSN  = CHECK(d, BIT!(18));
		s.DS   = CHECK(d, BIT!(21));
		s.ACPI = CHECK(d, BIT!(22));
		s.SS   = CHECK(d, BIT!(27));
		s.TM   = CHECK(d, BIT!(29));
		s.PBE  = CHECK(d, BIT!(31));
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
	s.__bundle1 = b; // BrandIndex, CLFLUSHLineSize, MaxIDs, InitialAPICID

	// ECX
	s.SSE3       = CHECK(c, BIT!(0));
	s.PCLMULQDQ  = CHECK(c, BIT!(1));
	s.MONITOR    = CHECK(c, BIT!(3));
	s.SSSE3      = CHECK(c, BIT!(9));
	s.FMA        = CHECK(c, BIT!(12));
	s.CMPXCHG16B = CHECK(c, BIT!(13));
	s.SSE41      = CHECK(c, BIT!(15));
	s.SSE42      = CHECK(c, BIT!(20));
	s.MOVBE      = CHECK(c, BIT!(22));
	s.POPCNT     = CHECK(c, BIT!(23));
	s.AES        = CHECK(c, BIT!(25));
	s.XSAVE      = CHECK(c, BIT!(26));
	s.OSXSAVE    = CHECK(c, BIT!(27));
	s.AVX        = CHECK(c, BIT!(28));
	s.F16C       = CHECK(c, BIT!(29));
	s.RDRAND     = CHECK(c, BIT!(30));

	// EDX
	s.FPU    = CHECK(d, BIT!(0));
	s.VME    = CHECK(d, BIT!(1));
	s.DE     = CHECK(d, BIT!(2));
	s.PSE    = CHECK(d, BIT!(3));
	s.TSC    = CHECK(d, BIT!(4));
	s.MSR    = CHECK(d, BIT!(5));
	s.PAE    = CHECK(d, BIT!(6));
	s.MCE    = CHECK(d, BIT!(7));
	s.CX8    = CHECK(d, BIT!(8));
	s.APIC   = CHECK(d, BIT!(9));
	s.SEP    = CHECK(d, BIT!(11));
	s.MTRR   = CHECK(d, BIT!(12));
	s.PGE    = CHECK(d, BIT!(13));
	s.MCA    = CHECK(d, BIT!(14));
	s.CMOV   = CHECK(d, BIT!(15));
	s.PAT    = CHECK(d, BIT!(16));
	s.PSE_36 = CHECK(d, BIT!(17));
	s.CLFSH  = CHECK(d, BIT!(19));
	s.MMX    = CHECK(d, BIT!(23));
	s.FXSR   = CHECK(d, BIT!(24));
	s.SSE    = CHECK(d, BIT!(25));
	s.SSE2   = CHECK(d, BIT!(26));
	s.HTT    = CHECK(d, BIT!(28));

	if (s.MaximumLeaf < 6) goto EXTENDED_LEAVES;

	version (GNU) asm {
		"mov $6, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0" : "=a" a;
	} else asm {
		mov EAX, 6;
		cpuid;
		mov a, EAX;
	} // ----- 6H

	switch (VendorID) {
	case VENDOR_INTEL:
		s.TurboBoost = CHECK(a, BIT!(1));
		s.TurboBoost3 = CHECK(a, BIT!(14));
		break;
	default:
	}

	s.ARAT = CHECK(a, BIT!(2));

	if (s.MaximumLeaf < 7) goto EXTENDED_LEAVES;

	version (GNU) asm {
		"mov $7, %%eax\n"~
		"mov $0, %%ecx\n"~
		"cpuid\n"~
		"mov %%ebx, %0\n"~
		"mov %%ecx, %1\n"~
		"mov %%edx, %2\n"
		: "=b" b, "=c" c, "=d" d;
	} else asm {
		mov EAX, 7;
		mov ECX, 0;
		cpuid;
		mov b, EBX;
		mov c, ECX;
		mov d, EDX;
	} // ----- 7H

	switch (VendorID) {
	case VENDOR_INTEL:
		// b
		s.SGX         = CHECK(b, BIT!(2));
		s.HLE         = CHECK(b, BIT!(4));
		s.RTM         = CHECK(b, BIT!(11));
		s.AVX512F     = CHECK(b, BIT!(16));
		s.SMAP        = CHECK(b, BIT!(20));
		s.AVX512ER    = CHECK(b, BIT!(27));
		s.AVX512PF    = CHECK(b, BIT!(26));
		s.AVX512CD    = CHECK(b, BIT!(28));
		s.AVX512DQ    = CHECK(b, BIT!(17));
		s.AVX512BW    = CHECK(b, BIT!(30));
		s.AVX512_IFMA = CHECK(b, BIT!(21));
		s.SHA         = CHECK(b, BIT!(29));
		s.AVX512_VBMI = CHECK(b, BIT!(31));
		// c
		s.AVX512VL    = CHECK(c, BIT!(1));
		s.PKU    = CHECK(c, BIT!(3));
		s.FSREPMOV    = CHECK(c, BIT!(4));
		s.WAITPKG     = CHECK(c, BIT!(5));
		s.AVX512_VBMI2 = CHECK(c, BIT!(6));
		s.AVX512_GFNI = CHECK(c, BIT!(8));
		s.AVX512_VAES = CHECK(c, BIT!(9));
		s.AVX512_VNNI = CHECK(c, BIT!(11));
		s.AVX512_BITALG = CHECK(c, BIT!(12));
		s.AVX512_VPOPCNTDQ = CHECK(c, BIT!(14));
		s._5PL = CHECK(c, BIT!(16));
		s.CLDEMOTE    = CHECK(c, BIT!(25));
		s.MOVDIRI     = CHECK(c, BIT!(27));
		s.MOVDIR64B   = CHECK(c, BIT!(28));
		// d
		s.AVX512_4VNNIW   = CHECK(d, BIT!(2));
		s.AVX512_4FMAPS   = CHECK(d, BIT!(3));
		s.PCONFIG     = CHECK(d, BIT!(18));
		s.IBRS        = s.IBPB = CHECK(d, BIT!(26));
		s.STIBP       = CHECK(d, BIT!(27));
		s.L1D_FLUSH   = CHECK(d, BIT!(28));
		s.IA32_ARCH_CAPABILITIES = CHECK(d, BIT!(29));
		s.SSBD        = CHECK(d, BIT!(31));
		break;
	default:
	}

	s.BMI1   = CHECK(b, BIT!(4));
	s.AVX2   = CHECK(b, BIT!(5));
	s.SMEP   = CHECK(b, BIT!(7));
	s.BMI2   = CHECK(b, BIT!(8));
	s.RDSEED = CHECK(b, BIT!(18));
	s.RDPID  = CHECK(c, BIT!(22));

	//if (s.MaximumLeaf < ...) goto EXTENDED_LEAVES;

	//
	// Extended CPUID leaves
	//

EXTENDED_LEAVES:

	version (GNU) asm {
		"mov $0x80000001, %%eax\n"~
		"cpuid\n"~
		"mov %%ecx, %0\n"~
		"mov %%edx, %1" : "=c" c, "=d" d;
	} else asm {
		mov EAX, 0x8000_0001;
		cpuid;
		mov c, ECX;
		mov d, EDX;
	} // EXTENDED 8000_0001H

	switch (VendorID) {
	case VENDOR_AMD:
		s.Virt      = CHECK(c, BIT!(2)); // SVM
		s.SSE4a     = CHECK(c, BIT!(6));
		s.FMA4      = CHECK(c, BIT!(16));
		s.MMXExt    = CHECK(d, BIT!(22));
		s._3DNowExt = CHECK(d, BIT!(30));
		s._3DNow    = CHECK(d, BIT!(31));
		break;
	default:
	}

	s.LAHF64    = CHECK(c, BIT!(0));
	s.LZCNT     = CHECK(c, BIT!(5));
	s.PREFETCHW = CHECK(c, BIT!(8));
	s.NX        = CHECK(d, BIT!(20));
	s.Page1GB   = CHECK(d, BIT!(26));
	s.RDTSCP    = CHECK(d, BIT!(27));
	s.LongMode  = CHECK(d, BIT!(29));

	if (s.MaximumExtendedLeaf < 0x8000_0007) return;

	version (GNU) asm {
		"mov $0x80000007, %%eax\n"~
		"cpuid\n"~
		"mov %%ebx, %0\n"~
		"mov %%edx, %1" : "=b" b, "=d" d;
	} else asm {
		mov EAX, 0x8000_0007;
		cpuid;
		mov b, EBX;
		mov d, EDX;
	} // EXTENDED 8000_0007H

	switch (VendorID) {
	case VENDOR_INTEL:
		s.RDSEED = CHECK(b, BIT!(28));
		break;
	case VENDOR_AMD:
		s.TM = CHECK(d, BIT!(4));
		s.TurboBoost = CHECK(d, BIT!(9));
		break;
	default:
	}

	s.TscInvariant = CHECK(d, BIT!(8));

	if (s.MaximumExtendedLeaf < 0x8000_0008) return;

	version (GNU) asm {
		"mov $0x80000008, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%ebx, %1\n"
		: "=a" a, "=b" b;
	} else asm {
		mov EAX, 0x8000_0008;
		cpuid;
		mov a, EAX;
		mov b, EBX;
	} // EXTENDED 8000_0008H

	switch (VendorID) {
	case VENDOR_INTEL:
		s.WBNOINVD = CHECK(b, BIT!(9));
		break;
	case VENDOR_AMD:
		s.IBPB      = CHECK(b, BIT!(12));
		s.IBRS      = CHECK(b, BIT!(14));
		s.STIBP     = CHECK(b, BIT!(15));
		s.IBRS_ON   = CHECK(b, BIT!(16));
		s.STIBP_ON  = CHECK(b, BIT!(17));
		s.IBRS_PREF = CHECK(b, BIT!(18));
		s.SSBD      = CHECK(b, BIT!(24));
		break;
	default:
	}

	s.__bundle3 = cast(ushort)a; // s.addr_phys_bits, s.addr_line_bits

	if (s.MaximumExtendedLeaf < 0x8000_000A) return;

	version (GNU) asm {
		"mov $0x8000000a, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0" : "=a" a;
	} else asm {
		mov EAX, 0x8000_000A;
		cpuid;
		mov a, EAX;
	} // EXTENDED 8000_000AH

	switch (VendorID) {
	case VENDOR_AMD:
		s.VirtVersion = cast(ubyte)a; // EAX[7:0]
		break;
	default:
	}

	//if (s.MaximumExtendedLeaf < ...) return;
}

version (GNU) {
	/// Get the maximum leaf.
	/// Returns: Maximum leaf
	uint hleaf() {
		uint r = void;
		asm {
			"mov $0, %%eax\n"~
			"cpuid" : "=a" r;
		}
		return r;
	}
	/// Get the maximum extended leaf.
	/// Returns: Maximum extended leaf
	uint heleaf() {
		uint r = void;
		asm {
			"mov $0x80000000, %%eax\n"~
			"cpuid" : "=a" r;
		}
		return r;
	}
} else {
	/// Get the maximum leaf.
	/// Returns: Maximum leaf
	uint hleaf() {
		asm {	naked;
			mov EAX, 0;
			cpuid;
			ret;
		}
	}
	/// Get the maximum extended leaf.
	/// Returns: Maximum extended leaf
	uint heleaf() {
		asm {	naked;
			mov EAX, 0x8000_0000;
			cpuid;
			ret;
		}
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

struct CACHE {
	/*
	 * Cache Size in Bytes
	 * (Ways + 1) * (Partitions + 1) * (Line_Size + 1) * (Sets + 1)
	 * (EBX[31:22] + 1) * (EBX[21:12] + 1) * (EBX[11:0] + 1) * (ECX + 1)
	 */
	ubyte type; // data=1, instructions=2, unified=3
	ubyte level; // L1, L2, etc.
	union {
		uint __bundle1;
		struct {
			ubyte linesize;
			ubyte partitions; // or "lines per tag" (AMD)
			ubyte ways; // n-way
			ubyte _amdsize; // (old AMD) Size in KB
		}
	}
	uint size; // Size in KB
	ushort sets;
	// bit 0, Self Initializing cache level
	// bit 1, Fully Associative cache
	// bit 2, Write-Back Invalidate/Invalidate (toggle)
	// bit 3, Cache Inclusiveness (toggle)
	// bit 4, Complex Cache Indexing (toggle)
	ubyte features;
}

struct CPUINFO { align(1):
	ubyte [12]vendorString;	// inits to 0
	ubyte [48]cpuString;	// inits to 0

	uint MaximumLeaf;
	uint MaximumExtendedLeaf;

	//ushort NumberOfCores;
	//ushort NumberOfThreads;

	ubyte Family;
	ubyte BaseFamily;
	ubyte ExtendedFamily;
	ubyte Model;
	ubyte BaseModel;
	ubyte ExtendedModel;
	ubyte Stepping;
	ubyte ProcessorType;

	ubyte MMX;
	ubyte MMXExt;
	ubyte SSE;
	ubyte SSE2;
	ubyte SSE3;
	ubyte SSSE3;
	ubyte SSE41;
	ubyte SSE42;
	ubyte SSE4a;
	ubyte AES;
	ubyte AVX;
	ubyte AVX2;
	ubyte AVX512F;
	ubyte AVX512ER;
	ubyte AVX512PF;
	ubyte AVX512CD;
	ubyte AVX512DQ;
	ubyte AVX512BW;
	ubyte AVX512_IFMA;
	ubyte AVX512_VBMI;
	ubyte AVX512_VBMI2;
	ubyte AVX512_GFNI;
	ubyte AVX512_VAES;
	ubyte AVX512_VNNI;
	ubyte AVX512_BITALG;
	ubyte AVX512_VPOPCNTDQ;
	ubyte AVX512_4VNNIW;
	ubyte AVX512_4FMAPS;
	ubyte AVX512VL;
	ubyte SHA;

	ubyte _3DNow;
	ubyte _3DNowExt;

	// ---- 01h ----
	// -- EBX --
	union {
		uint __bundle1;
		struct {
			ubyte BrandIndex;
			ubyte CLFLUSHLineSize;
			ubyte MaxIDs;
			ubyte InitialAPICID;
		}
	}

	// -- ECX --
	ubyte PCLMULQDQ;	// 1
	ubyte DTES64;
	ubyte MONITOR;
	ubyte DS_CPL;
	ubyte Virt;	// VMX (intel) / SVM (AMD)
	ubyte SMX;	// intel txt/tpm
	ubyte EIST;	// intel speedstep
	ubyte TM2;
	ubyte CNXT_ID;	// l1 context id
	ubyte SDBG;	// IA32_DEBUG_INTERFACE silicon debug
	ubyte FMA;
	ubyte FMA4;
	ubyte CMPXCHG16B;
	ubyte xTPR;
	ubyte PDCM;
	ubyte PCID;	// Process-context identifiers
	ubyte DCA;
	ubyte x2APIC;
	ubyte MOVBE;
	ubyte POPCNT;
	ubyte TscDeadline;
	ubyte XSAVE;
	ubyte OSXSAVE;
	ubyte F16C;
	ubyte RDRAND;	// 30

	// -- EDX --
	ubyte FPU;	// 0
	ubyte VME;
	ubyte DE;
	ubyte PSE;
	ubyte TSC;
	ubyte MSR;
	ubyte PAE;
	ubyte MCE;
	ubyte CX8;
	ubyte APIC;
	ubyte SEP;	/// sysenter/sysexit
	ubyte MTRR;
	ubyte PGE;
	ubyte MCA;
	ubyte CMOV;
	ubyte PAT;
	ubyte PSE_36;
	ubyte PSN;
	ubyte CLFSH;
	ubyte DS;
	ubyte ACPI;
	ubyte FXSR;
	ubyte SS;	/// self-snoop
	ubyte HTT;
	ubyte TM;
	ubyte PBE;	// 31

	// ---- 06h ----
	/// eq. to AMD's Core Performance Boost
	ubyte TurboBoost;	// 1
	ubyte ARAT;	/// Always-Running-APIC-Timer feature
	ubyte TurboBoost3;	// 14

	// ---- 07h ----
	// -- EBX --
	ubyte SGX;	// 2 Intel SGX (Software Guard Extensions)
	ubyte HLE;	// 4 hardware lock elision
	ubyte SMEP;	// 7
	union {
		ushort __bundle2;
		struct {
			ubyte BMI1;	// 3
			ubyte BMI2;	// 8
		}
	}
	ubyte RTM;	// 11 restricted transactional memory
	ubyte SMAP;	// 22
	// -- ECX --
	ubyte PKU;	// 3
	ubyte FSREPMOV;	// 4
	ubyte WAITPKG;	// 5
	ubyte _5PL;	// 16
	ubyte RDPID;	// 22
	ubyte CLDEMOTE;	// 25
	ubyte MOVDIRI;	// 27
	ubyte MOVDIR64B;	// 28
	// -- EDX --
	ubyte PCONFIG;	// 18
	ubyte IBPB;	// 26
	ubyte IBRS;	// 26
	ubyte STIBP;	// 27
	ubyte L1D_FLUSH;	// 28
	ubyte IA32_ARCH_CAPABILITIES;	// 29
	ubyte SSBD;	// 31

	// ---- 8000_0001 ----
	// ECX
	ubyte LAHF64;	/// LAHF/SAHF in LONG mode
	ubyte LZCNT;	/// Counts leading zero bits, SSE4 SIMD
	ubyte PREFETCHW;	// 8, Prefetch

	ubyte RDSEED;	// RDSEED instruction
	// EDX
	ubyte NX;	// 20, No execute
	ubyte Page1GB;	// 26, 1 GB pages
	ubyte LongMode;	// 29, Intel64/AMD64

	// EDX
	ubyte RDTSCP;	// 27

	// ---- 8000_0007 ----
	ubyte TscInvariant;	// 8

	// ---- 8000_0008 ----
	union {
		ushort __bundle3;
		struct {
			ubyte addr_phys_bits;	// EAX[7 :0]
			ubyte addr_line_bits;	// EAX[15:8]
		}
	}
	// EBX
	ubyte WBNOINVD;	// 9
	ubyte IBRS_ON;	// AMD, 16
	ubyte STIBP_ON;	// AMD, 17
	ubyte IBRS_PREF;	// AMD, 18

	// ---- 8000_000A ----
	ubyte VirtVersion;	// (AMD) EAX[7:0]

	// 6 levels should be enough (L1-D, L1-I, L2, L3, 0, 0)
	CACHE [6]cache;	// all inits to 0
}

pragma(msg, "-- sizeof CPUINFO: ", CPUINFO.sizeof);
pragma(msg, "-- sizeof CACHE: ", CACHE.sizeof);
static assert(CPUINFO.__bundle1.sizeof == 4);
static assert(CPUINFO.__bundle2.sizeof == 2);
static assert(CPUINFO.__bundle3.sizeof == 2);
static assert(CACHE.__bundle1.sizeof == 4);