@system:
extern (C):
__gshared:

version (X86)
	enum PLATFORM = "x86";
else
version (X86_64)
	enum PLATFORM = "amd64";
else
static assert(0, "ddcpuid is only supported on x86 platforms");

int strcmp(scope const char*, scope const char*);
int printf(scope const char*, ...);
int puts(scope const char*);
int putchar(int c);
void* memset(void *, int, size_t);
long strtol(scope inout(char)*,scope inout(char)**, int);

enum	VERSION = "0.16.0"; /// Program version
enum	MAX_LEAF  = 0x20, /// Maximum leaf (-o)
	MAX_VLEAF = 0x4000_0010, /// Maximum virt leaf (-o)
	MAX_ELEAF = 0x8000_0020; /// Maximum extended leaf (-o)

// Self-made vendor "IDs" for faster look-ups, LSB-based.
enum VENDOR_OTHER = 0;	/// Other/unknown
enum VENDOR_INTEL = 0x756e6547;	/// Intel: "Genu"
enum VENDOR_AMD   = 0x68747541;	/// AMD: "Auth"
enum VENDOR_VIA   = 0x20414956;	/// VIA: "VIA "
enum VIRT_VENDOR_KVM      = 0x4b4d564b; /// KVM: "KVMK"
enum VIRT_VENDOR_VBOX_HV  = 0x786f4256; /// VirtualBox: "VBox", hyper-v interface
enum VIRT_VENDOR_VBOX_MIN = 0x00000000; /// VirtualBox: Minimal interface

template BIT(int n) { enum { BIT = 1 << n } }

enum {	// NOTE: Flags for our structure, not CPUID bits!
	//
	// Extension bits
	//
	F_EXTEN_FPU	= BIT!(0),
	F_EXTEN_F16C	= BIT!(1),
	F_EXTEN_MMX	= BIT!(2),
	F_EXTEN_MMXEXT	= BIT!(3),
	F_EXTEN_3DNOW	= BIT!(4),
	F_EXTEN_3DNOWEXT	= BIT!(5),
	F_EXTEN_SSE	= BIT!(6),
	F_EXTEN_SSE2	= BIT!(7),
	F_EXTEN_SSE3	= BIT!(8),
	F_EXTEN_SSSE3	= BIT!(9),
	F_EXTEN_SSE41	= BIT!(10),
	F_EXTEN_SSE42	= BIT!(11),
	F_EXTEN_SSE4a	= BIT!(12),
	F_EXTEN_AES_NI	= BIT!(15),
	F_EXTEN_SHA	= BIT!(16),
	F_EXTEN_FMA	= BIT!(17),
	F_EXTEN_FMA4	= BIT!(18),
	F_EXTEN_BMI1	= BIT!(19),
	F_EXTEN_BMI2	= BIT!(20),
	F_EXTEN_x86_64	= BIT!(21),
	F_EXTEN_LAHF64	= BIT!(22),
	F_EXTEN_WAITPKG	= BIT!(23),
	F_EXTEN_XOP	= BIT!(24),
	F_EXTEN_TBM	= BIT!(25),
	F_EXTEN_ADX	= BIT!(26),
	//
	// AVX
	//
	F_AVX_AVX	= BIT!(0),
	F_AVX_AVX2	= BIT!(1),
	F_AVX_AVX512F	= BIT!(2),
	F_AVX_AVX512ER	= BIT!(3),
	F_AVX_AVX512PF	= BIT!(4),
	F_AVX_AVX512CD	= BIT!(5),
	F_AVX_AVX512DQ	= BIT!(6),
	F_AVX_AVX512BW	= BIT!(7),
	F_AVX_AVX512VL	= BIT!(8),
	F_AVX_AVX512_IFMA	= BIT!(9),
	F_AVX_AVX512_VBMI	= BIT!(10),
	F_AVX_AVX512_VBMI2	= BIT!(11),
	F_AVX_AVX512_GFNI	= BIT!(12),
	F_AVX_AVX512_VAES	= BIT!(13),
	F_AVX_AVX512_VNNI	= BIT!(14),
	F_AVX_AVX512_BITALG	= BIT!(15),
	F_AVX_AVX512_VPOPCNTDQ	= BIT!(16),
	F_AVX_AVX512_4VNNIW	= BIT!(17),
	F_AVX_AVX512_4FMAPS	= BIT!(18),
	F_AVX_AVX512_BF16	= BIT!(19),
	F_AVX_AVX512_VP2INTERSECT	= BIT!(20),
	//
	// Extras
	//
	F_EXTRA_MONITOR	= BIT!(0),
	F_EXTRA_PCLMULQDQ	= BIT!(1),
	F_EXTRA_CMPXCHG8B	= BIT!(2),
	F_EXTRA_CMPXCHG16B	= BIT!(3),
	F_EXTRA_MOVBE	= BIT!(4),
	F_EXTRA_RDRAND	= BIT!(5),
	F_EXTRA_RDSEED	= BIT!(6),
	F_EXTRA_RDMSR	= BIT!(7),
	F_EXTRA_SYSENTER	= BIT!(8),
	F_EXTRA_TSC	= BIT!(9),
	F_EXTRA_TSC_DEADLINE	= BIT!(10),
	F_EXTRA_TSC_INVARIANT	= BIT!(11),
	F_EXTRA_RDTSCP	= BIT!(12),
	F_EXTRA_RDPID	= BIT!(13),
	F_EXTRA_CMOV	= BIT!(14),
	F_EXTRA_LZCNT	= BIT!(15),
	F_EXTRA_POPCNT	= BIT!(16),
	F_EXTRA_XSAVE	= BIT!(17),
	F_EXTRA_OSXSAVE	= BIT!(18),
	F_EXTRA_FXSR	= BIT!(19),
	F_EXTRA_PCONFIG	= BIT!(20),
	F_EXTRA_CLDEMOTE	= BIT!(22),
	F_EXTRA_MOVDIRI	= BIT!(23),
	F_EXTRA_MOVDIR64B	= BIT!(24),
	F_EXTRA_ENQCMD	= BIT!(25),
	F_EXTRA_SYSCALL	= BIT!(26),
	F_EXTRA_MONITORX	= BIT!(27),
	F_EXTRA_SKINIT	= BIT!(28),
	F_EXTRA_CLFLUSHOPT	= BIT!(29),
	//
	// Technology bits
	//
	F_TECH_EIST	= BIT!(0),
	F_TECH_TURBOBOOST	= BIT!(1),
	F_TECH_TURBOBOOST30	= BIT!(2),
	F_TECH_SMX	= BIT!(3),
	F_TECH_SGX	= BIT!(4),
	F_TECH_HTT	= BIT!(24),
	//
	// Cache bits
	//
	F_CACHE_CLFLUSH	= BIT!(8),
	F_CACHE_CNXT_ID	= BIT!(9),
	F_CACHE_SS	= BIT!(10),
	F_CACHE_PREFETCHW	= BIT!(11),
	F_CACHE_INVPCID	= BIT!(12),
	F_CACHE_WBNOINVD	= BIT!(13),
	//
	// ACPI bits
	//
	F_ACPI_ACPI	= BIT!(0),
	F_ACPI_APIC	= BIT!(0),
	F_ACPI_x2APIC	= BIT!(0),
	F_ACPI_ARAT	= BIT!(0),
	F_ACPI_TM	= BIT!(0),
	F_ACPI_TM2	= BIT!(0),
	//
	// Virt bits
	//
	F_VIRT_VIRT	= BIT!(8),
	F_VIRT_VME	= BIT!(9),
	//
	// KVM interface bits
	//
	F_KVM_FEATURE_CLOCKSOURCE	= BIT!(0),
	F_KVM_FEATURE_NOP_IO_DELAY	= BIT!(1),
	F_KVM_FEATURE_MMU_OP	= BIT!(2),
	F_KVM_FEATURE_CLOCKSOURCE2	= BIT!(3),
	F_KVM_FEATURE_ASYNC_PF	= BIT!(4),
	F_KVM_FEATURE_STEAL_TIME	= BIT!(5),
	F_KVM_FEATURE_PV_EOI	= BIT!(6),
	F_KVM_FEATURE_PV_UNHAULT	= BIT!(7),
	F_KVM_FEATURE_PV_TLB_FLUSH	= BIT!(9),
	F_KVM_FEATURE_ASYNC_PF_VMEXIT	= BIT!(10),
	F_KVM_FEATURE_PV_SEND_IPI	= BIT!(11),
	F_KVM_FEATURE_PV_POLL_CONTROL	= BIT!(12),
	F_KVM_FEATURE_PV_SCHED_YIELD	= BIT!(13),
	F_KVM_FEATURE_CLOCSOURCE_STABLE_BIT	= BIT!(24),
	F_KVM_HINTS_REALTIME	= BIT!(25),
	//
	// Hyper-V interface bits
	//
	HV_BASE_FEAT_VP_RUNTIME_MSR                  = BIT!(0), // Pair A,-
	HV_BASE_FEAT_PART_TIME_REF_COUNT_MSR         = BIT!(1),
	HV_BASE_FEAT_BASIC_SYNIC_MSRS                = BIT!(2),
	HV_BASE_FEAT_STIMER_MSRS                     = BIT!(3),
	HV_BASE_FEAT_APIC_ACCESS_MSRS                = BIT!(4),
	HV_BASE_FEAT_HYPERCALL_MSRS                  = BIT!(5),
	HV_BASE_FEAT_VP_ID_MSR                       = BIT!(6),
	HV_BASE_FEAT_VIRT_SYS_RESET_MSR              = BIT!(7),
	HV_BASE_FEAT_STAT_PAGES_MSR                  = BIT!(8),
	HV_BASE_FEAT_PART_REF_TSC_MSR                = BIT!(9),
	HV_BASE_FEAT_GUEST_IDLE_STATE_MSR            = BIT!(10),
	HV_BASE_FEAT_TIMER_FREQ_MSRS                 = BIT!(11),
	HV_BASE_FEAT_DEBUG_MSRS                      = BIT!(12),
	HV_PART_FLAGS_CREATE_PART                    = BIT!(0), // Pair B,2
	HV_PART_FLAGS_ACCESS_PART_ID                 = BIT!(1),
	HV_PART_FLAGS_ACCESS_MEMORY_POOL             = BIT!(2),
	HV_PART_FLAGS_ADJUST_MSG_BUFFERS             = BIT!(3),
	HV_PART_FLAGS_POST_MSGS                      = BIT!(4),
	HV_PART_FLAGS_SIGNAL_EVENTS                  = BIT!(5),
	HV_PART_FLAGS_CREATE_PORT                    = BIT!(6),
	HV_PART_FLAGS_CONNECT_PORT                   = BIT!(7),
	HV_PART_FLAGS_ACCESS_STATS                   = BIT!(8),
	HV_PART_FLAGS_DEBUGGING                      = BIT!(11),
	HV_PART_FLAGS_CPU_MGMT                       = BIT!(12),
	HV_PART_FLAGS_CPU_PROFILER                   = BIT!(13),
	HV_PART_FLAGS_EXPANDED_STACK_WALK            = BIT!(14),
	HV_PART_FLAGS_ACCESS_VSM                     = BIT!(16),
	HV_PART_FLAGS_ACCESS_VP_REGS                 = BIT!(17),
	HV_PART_FLAGS_EXTENDED_HYPERCALLS            = BIT!(20),
	HV_PART_FLAGS_START_VP                       = BIT!(21),
	HV_PM_MAX_CPU_POWER_STATE_C0                 = BIT!(0) << 24, // Pair C,3
	HV_PM_MAX_CPU_POWER_STATE_C1                 = BIT!(1) << 24,
	HV_PM_MAX_CPU_POWER_STATE_C2                 = BIT!(2) << 24,
	HV_PM_MAX_CPU_POWER_STATE_C3                 = BIT!(3) << 24,
	HV_PM_HPET_REQD_FOR_C3                       = BIT!(4) << 24,
	HV_MISC_FEAT_MWAIT                           = BIT!(0),
	HV_MISC_FEAT_GUEST_DEBUGGING                 = BIT!(1),
	HV_MISC_FEAT_PERF_MON                        = BIT!(2),
	HV_MISC_FEAT_PCPU_DYN_PART_EVENT             = BIT!(3),
	HV_MISC_FEAT_XMM_HYPERCALL_INPUT             = BIT!(4),
	HV_MISC_FEAT_GUEST_IDLE_STATE                = BIT!(5),
	HV_MISC_FEAT_HYPERVISOR_SLEEP_STATE          = BIT!(6),
	HV_MISC_FEAT_QUERY_NUMA_DISTANCE             = BIT!(7),
	HV_MISC_FEAT_TIMER_FREQ                      = BIT!(8),
	HV_MISC_FEAT_INJECT_SYNMC_XCPT               = BIT!(9),
	HV_MISC_FEAT_GUEST_CRASH_MSRS                = BIT!(10),
	HV_MISC_FEAT_DEBUG_MSRS                      = BIT!(11),
	HV_MISC_FEAT_NPIEP1                          = BIT!(12),
	HV_MISC_FEAT_DISABLE_HYPERVISOR              = BIT!(13),
	HV_MISC_FEAT_EXT_GVA_RANGE_FOR_FLUSH_VA_LIST = BIT!(14),
	HV_MISC_FEAT_HYPERCALL_OUTPUT_XMM            = BIT!(15),
	HV_MISC_FEAT_SINT_POLLING_MODE               = BIT!(17),
	HV_MISC_FEAT_HYPERCALL_MSR_LOCK              = BIT!(18),
	HV_MISC_FEAT_USE_DIRECT_SYNTH_MSRS           = BIT!(19),
	HV_HINT_HYPERCALL_FOR_PROCESS_SWITCH         = BIT!(0), // Pair D,4
	HV_HINT_HYPERCALL_FOR_TLB_FLUSH              = BIT!(1),
	HV_HINT_HYPERCALL_FOR_TLB_SHOOTDOWN          = BIT!(2),
	HV_HINT_MSR_FOR_APIC_ACCESS                  = BIT!(3),
	HV_HINT_MSR_FOR_SYS_RESET                    = BIT!(4),
	HV_HINT_RELAX_TIME_CHECKS                    = BIT!(5),
	HV_HINT_DMA_REMAPPING                        = BIT!(6),
	HV_HINT_INTERRUPT_REMAPPING                  = BIT!(7),
	HV_HINT_X2APIC_MSRS                          = BIT!(8),
	HV_HINT_DEPRECATE_AUTO_EOI                   = BIT!(9),
	HV_HINT_SYNTH_CLUSTER_IPI_HYPERCALL          = BIT!(10),
	HV_HINT_EX_PROC_MASKS_INTERFACE              = BIT!(11),
	HV_HINT_NESTED_HYPERV                        = BIT!(12),
	HV_HINT_INT_FOR_MBEC_SYSCALLS                = BIT!(13),
	HV_HINT_NESTED_ENLIGHTENED_VMCS_INTERFACE    = BIT!(14),
	HV_HOST_FEAT_AVIC                            = BIT!(0) << 16,
	HV_HOST_FEAT_MSR_BITMAP                      = BIT!(1) << 16,
	HV_HOST_FEAT_PERF_COUNTER                    = BIT!(2) << 16,
	HV_HOST_FEAT_NESTED_PAGING                   = BIT!(3) << 16,
	HV_HOST_FEAT_DMA_REMAPPING                   = BIT!(4) << 16,
	HV_HOST_FEAT_INTERRUPT_REMAPPING             = BIT!(5) << 16,
	HV_HOST_FEAT_MEM_PATROL_SCRUBBER             = BIT!(6) << 16,
	HV_HOST_FEAT_DMA_PROT_IN_USE                 = BIT!(7) << 16,
	HV_HOST_FEAT_HPET_REQUESTED                  = BIT!(8) << 16,
	HV_HOST_FEAT_STIMER_VOLATILE                 = BIT!(9) << 16,
	//
	// Memory bits
	//
	F_MEM_PAE	= BIT!(0),
	F_MEM_PSE	= BIT!(1),
	F_MEM_PSE_36	= BIT!(2),
	F_MEM_PAGE1GB	= BIT!(3),
	F_MEM_MTRR	= BIT!(4),
	F_MEM_PAT	= BIT!(5),
	F_MEM_PGE	= BIT!(6),
	F_MEM_DCA	= BIT!(7),
	F_MEM_NX	= BIT!(8),
	F_MEM_HLE	= BIT!(9),
	F_MEM_RTM	= BIT!(10),
	F_MEM_SMEP	= BIT!(11),
	F_MEM_SMAP	= BIT!(12),
	F_MEM_PKU	= BIT!(13),
	F_MEM_5PL	= BIT!(14),
	F_MEM_FSREPMOV	= BIT!(15),
	//
	// Debug bits
	//
	F_DEBUG_MCA	= BIT!(0),
	F_DEBUG_MCE	= BIT!(1),
	F_DEBUG_DE	= BIT!(2),
	F_DEBUG_DS	= BIT!(3),
	F_DEBUG_DS_CPL	= BIT!(4),
	F_DEBUG_DTES64	= BIT!(5),
	F_DEBUG_PDCM	= BIT!(6),
	F_DEBUG_SDBG	= BIT!(7),
	F_DEBUG_PBE	= BIT!(8),
	//
	// Security bits
	//
	F_SEC_IBPB	= BIT!(0),
	F_SEC_IBRS	= BIT!(1),
	F_SEC_IBRS_ON	= BIT!(2),
	F_SEC_IBRS_PREF	= BIT!(3),
	F_SEC_STIBP	= BIT!(4),
	F_SEC_STIBP_ON	= BIT!(5),
	F_SEC_SSBD	= BIT!(6),
	F_SEC_L1D_FLUSH	= BIT!(7),
	F_SEC_MD_CLEAR	= BIT!(8),
	F_SEC_CET_IBT	= BIT!(9),
	//
	// Misc. bits
	//
	F_MISC_PSN	= BIT!(8),
	F_MISC_PCID	= BIT!(9),
	F_MISC_xTPR	= BIT!(10),
	F_MISC_IA32_ARCH_CAPABILITIES	= BIT!(11),
	F_MISC_FSGSBASE	= BIT!(12),
}

char []CACHE_TYPE = [ '?', 'D', 'I', 'U', '?', '?', '?', '?' ];

const(char) *[]PROCESSOR_TYPE = [ "Original", "OverDrive", "Dual", "Reserved" ];

void clih() {
	puts(
	"x86/AMD64 CPUID information tool\n"~
	"  Usage: ddcpuid [OPTIONS]\n"~
	"\n"~
	"OPTIONS\n"~
	"  -r    Show raw CPUID data in a table\n"~
	"  -s    (with -r) subleaf to loop to (ECX)\n"~
	"  -o    Override leaves to 20h, 4000_0002h, and 8000_0020h\n"~
	"\n"~
	"  --version    Print version information screen and quit\n"~
	"  -h, --help   Print this help screen and quit"
	);
}

void cliv() {
	import d = std.compiler;
	printf(
	"ddcpuid-"~PLATFORM~" v"~VERSION~" ("~__TIMESTAMP__~")\n"~
	"Copyright (c) dd86k 2016-2020\n"~
	"License: MIT License <http://opensource.org/licenses/MIT>\n"~
	"Project page: <https://git.dd86k.space/dd86k/ddcpuid>, <https://github.com/dd86k/ddcpuid>\n"~
	"Compiler: "~ __VENDOR__ ~" v%u.%03u\n",
	d.version_major, d.version_minor
	);
}

/// Print cpuid info
void printc(uint leaf, uint sub) {
	uint a = void, b = void, c = void, d = void;
	version (GNU) asm {
		"cpuid\n"
		: "=a" a, "=b" b, "=c" c, "=d" d
		: "a" leaf "c" sub;
	} else asm {
		mov EAX, leaf;
		mov ECX, sub;
		cpuid;
		mov a, EAX;
		mov b, EBX;
		mov c, ECX;
		mov d, EDX;
	}
	printf("| %8X | %8X | %8X | %8X | %8X | %8X |\n", leaf, sub, a, b, c, d);
}

// GAS reminder: asm { "asm" : output : input : clobber }

int main(int argc, char **argv) {
	bool opt_raw;	/// Raw option (-r), table option
	bool opt_override;	/// opt_override max leaf option (-o)
	uint opt_subleaf;	/// Max subleaf for -r

	for (size_t argi = 1; argi < argc; ++argi) {
		if (argv[argi][1] == '-') { // Long arguments
			char* a = argv[argi] + 2;
			if (strcmp(a, "help") == 0) {
				clih; return 0;
			}
			if (strcmp(a, "version") == 0) {
				cliv; return 0;
			}
			printf("Unknown parameter: %s\n", a);
			return 1;
		} else if (argv[argi][0] == '-') { // Short arguments
			char* a = argv[argi];
			char o = a[1];
			switch (o) {
			case 'o': opt_override = true; break;
			case 'r': opt_raw = true; break;
			case 's':
				opt_subleaf = cast(uint)strtol(argv[argi + 1], null, 10);
				break;
			case 'h': clih; return 0;
			default:
				printf("Unknown parameter: %c\n", o);
				return 1;
			}
		} // else if
	} // for

	CPUINFO cpu = void;
	memset(cast(ubyte*)&cpu + 12, 0, CPUINFO.sizeof - 12);

	if (opt_override) {
		cpu.MaximumLeaf = MAX_LEAF;
		cpu.MaximumVirtLeaf = MAX_VLEAF;
		cpu.MaximumExtendedLeaf = MAX_ELEAF;
	} else
		leafs(cpu);

	if (opt_raw) { // -r
		puts(
		"| Leaf     | Sub-leaf | EAX      | EBX      | ECX      | EDX      |\n"~
		"|----------|----------|----------|----------|----------|----------|"
		);
		uint l, s; // Normal
		do {
			do { printc(l, s); } while (++s <= opt_subleaf);
			s = 0;
		} while (++l <= cpu.MaximumLeaf);
		l = 0x4000_0000; // Hypervisor, show first level anyway
		do {
			do { printc(l, s); } while (++s <= opt_subleaf);
			s = 0;
		} while (++l <= cpu.MaximumVirtLeaf);
		l = 0x8000_0000; // Extended
		do {
			do { printc(l, s); } while (++s <= opt_subleaf);
			s = 0;
		} while (++l <= cpu.MaximumExtendedLeaf);
		return 0;
	}

	fetchInfo(cpu);

	const(char) *cstring = cast(const(char)*)cpu.cpuString;

	switch (cpu.VendorID) {
	case VENDOR_INTEL: // Common in Intel processor brand strings
		while (*cstring == ' ') ++cstring; // left trim cpu string
		break;
	default:
	}

	//
	// ANCHOR Processor basic information
	//

	printf(
	"[Vendor] %.12s\n"~
	"[String] %.48s\n"~
	"[Identifier] Family %u (%Xh) [%Xh:%Xh] Model %u (%Xh) [%Xh:%Xh] Stepping %u\n"~
	"[Extensions]",
	cast(char*)cpu.vendorString, cstring,
	cpu.Family, cpu.Family, cpu.BaseFamily, cpu.ExtendedFamily,
	cpu.Model, cpu.Model, cpu.BaseModel, cpu.ExtendedModel,
	cpu.Stepping
	);

	if (cpu.EXTEN & F_EXTEN_FPU) {
		printf(" x87/FPU");
		if (cpu.EXTEN & F_EXTEN_F16C) printf(" +F16C");
	}
	if (cpu.EXTEN & F_EXTEN_MMX) {
		printf(" MMX");
		if (cpu.EXTEN & F_EXTEN_MMXEXT) printf(" Ext.MMX");
	}
	if (cpu.EXTEN & F_EXTEN_3DNOW) {
		printf(" 3DNow!");
		if (cpu.EXTEN & F_EXTEN_3DNOWEXT) printf(" Ext.3DNow!");
	}
	if (cpu.EXTEN & F_EXTEN_SSE) {
		printf(" SSE");
		if (cpu.EXTEN & F_EXTEN_SSE2) printf(" SSE2");
		if (cpu.EXTEN & F_EXTEN_SSE3) printf(" SSE3");
		if (cpu.EXTEN & F_EXTEN_SSSE3) printf(" SSSE3");
		if (cpu.EXTEN & F_EXTEN_SSE41) printf(" SSE4.1");
		if (cpu.EXTEN & F_EXTEN_SSE42) printf(" SSE4.2");
		if (cpu.EXTEN & F_EXTEN_SSE4a) printf(" SSE4a");
		if (cpu.EXTEN & F_EXTEN_XOP) printf(" XOP");
	}
	if (cpu.EXTEN & F_EXTEN_x86_64) {
		switch (cpu.VendorID) {
		case VENDOR_INTEL: printf(" Intel64/x86-64"); break;
		case VENDOR_AMD: printf(" AMD64/x86-64"); break;
		default: printf(" x86-64");
		}
		if (cpu.EXTEN & F_EXTEN_LAHF64)
			printf(" +LAHF64");
	}
	if (cpu.VIRT & F_VIRT_VIRT)
		switch (cpu.VendorID) {
		case VENDOR_INTEL: printf(" VT-x/VMX"); break;
		case VENDOR_AMD: // SVM
			printf(" AMD-V/VMX");
			if (cpu.virt_ver)
				printf(":v%u", cpu.virt_ver);
			break;
		case VENDOR_VIA: printf(" VIA-VT/VMX"); break;
		default: printf(" VMX");
		}
	if (cpu.TECH & F_TECH_SMX) printf(" Intel-TXT/SMX");
	if (cpu.EXTEN & F_EXTEN_AES_NI) printf(" AES-NI");
	if (cpu.AVX & F_AVX_AVX) printf(" AVX");
	if (cpu.AVX & F_AVX_AVX2) printf(" AVX2");
	if (cpu.AVX & F_AVX_AVX512F) {
		printf(" AVX512F");
		if (cpu.AVX & F_AVX_AVX512ER) printf(" AVX512ER");
		if (cpu.AVX & F_AVX_AVX512PF) printf(" AVX512PF");
		if (cpu.AVX & F_AVX_AVX512CD) printf(" AVX512CD");
		if (cpu.AVX & F_AVX_AVX512DQ) printf(" AVX512DQ");
		if (cpu.AVX & F_AVX_AVX512BW) printf(" AVX512BW");
		if (cpu.AVX & F_AVX_AVX512VL) printf(" AVX512VL");
		if (cpu.AVX & F_AVX_AVX512_IFMA) printf(" AVX512_IFMA");
		if (cpu.AVX & F_AVX_AVX512_VBMI) printf(" AVX512_VBMI");
		if (cpu.AVX & F_AVX_AVX512_4VNNIW) printf(" AVX512_4VNNIW");
		if (cpu.AVX & F_AVX_AVX512_4FMAPS) printf(" AVX512_4FMAPS");
		if (cpu.AVX & F_AVX_AVX512_VBMI2) printf(" AVX512_VBMI2");
		if (cpu.AVX & F_AVX_AVX512_GFNI) printf(" AVX512_GFNI");
		if (cpu.AVX & F_AVX_AVX512_VAES) printf(" AVX512_VAES");
		if (cpu.AVX & F_AVX_AVX512_VNNI) printf(" AVX512_VNNI");
		if (cpu.AVX & F_AVX_AVX512_BITALG) printf(" AVX512_BITALG");
		if (cpu.AVX & F_AVX_AVX512_BF16) printf(" AVX512_BF16");
		if (cpu.AVX & F_AVX_AVX512_VP2INTERSECT) printf(" AVX512_VP2INTERSECT");
	}
	if (cpu.EXTEN & F_EXTEN_ADX) printf(" ADX");
	if (cpu.EXTEN & F_EXTEN_SHA) printf(" SHA");
	if (cpu.EXTEN & F_EXTEN_FMA) printf(" FMA3");
	if (cpu.EXTEN & F_EXTEN_FMA4) printf(" FMA4");
	if (cpu.EXTEN & F_EXTEN_TBM) printf(" TBM");
	if (cpu.EXTEN & F_EXTEN_BMI1) printf(" BMI1");
	if (cpu.EXTEN & F_EXTEN_BMI2) printf(" BMI2");
	if (cpu.EXTEN & F_EXTEN_WAITPKG) printf(" WAITPKG");

	//
	// ANCHOR Other instructions
	//

	printf("\n[Extra]");
	if (cpu.EXTRA & F_EXTRA_MONITOR) {
		printf(" MONITOR+MWAIT");
		if (cpu.mwait_min)
			printf(" +MIN:%u +MAX:%u", cpu.mwait_min, cpu.mwait_max);
		if (cpu.EXTRA & F_EXTRA_MONITORX) printf(" MONITORX+MWAITX");
	}
	if (cpu.EXTRA & F_EXTRA_PCLMULQDQ) printf(" PCLMULQDQ");
	if (cpu.EXTRA & F_EXTRA_CMPXCHG8B) printf(" CMPXCHG8B");
	if (cpu.EXTRA & F_EXTRA_CMPXCHG16B) printf(" CMPXCHG16B");
	if (cpu.EXTRA & F_EXTRA_MOVBE) printf(" MOVBE");
	if (cpu.EXTRA & F_EXTRA_RDRAND) printf(" RDRAND");
	if (cpu.EXTRA & F_EXTRA_RDSEED) printf(" RDSEED");
	if (cpu.EXTRA & F_EXTRA_RDMSR) printf(" RDMSR+WRMSR");
	if (cpu.EXTRA & F_EXTRA_SYSENTER) printf(" SYSENTER+SYSEXIT");
	if (cpu.EXTRA & F_EXTRA_SYSCALL) printf(" SYSCALL+SYSRET");
	if (cpu.EXTRA & F_EXTRA_TSC) {
		printf(" RDTSC");
		if (cpu.EXTRA & F_EXTRA_TSC_DEADLINE)
			printf(" +TSC-Deadline");
		if (cpu.EXTRA & F_EXTRA_TSC_INVARIANT)
			printf(" +TSC-Invariant");
	}
	if (cpu.EXTRA & F_EXTRA_RDTSCP) printf(" RDTSCP");
	if (cpu.EXTRA & F_EXTRA_RDPID) printf(" RDPID");
	if (cpu.EXTRA & F_EXTRA_CMOV) {
		printf(" CMOV");
		if (cpu.EXTEN & F_EXTEN_FPU) printf(" FCOMI+FCMOV");
	}
	if (cpu.EXTRA & F_EXTRA_LZCNT) printf(" LZCNT");
	if (cpu.EXTRA & F_EXTRA_POPCNT) printf(" POPCNT");
	if (cpu.EXTRA & F_EXTRA_XSAVE) printf(" XSAVE+XRSTOR");
	if (cpu.EXTRA & F_EXTRA_OSXSAVE) printf(" XSETBV+XGETBV");
	if (cpu.EXTRA & F_EXTRA_FXSR) printf(" FXSAVE+FXRSTOR");
	if (cpu.EXTRA & F_EXTRA_PCONFIG) printf(" PCONFIG");
	if (cpu.EXTRA & F_EXTRA_CLDEMOTE) printf(" CLDEMOTE");
	if (cpu.EXTRA & F_EXTRA_MOVDIRI) printf(" MOVDIRI");
	if (cpu.EXTRA & F_EXTRA_MOVDIR64B) printf(" MOVDIR64B");
	if (cpu.EXTRA & F_EXTRA_ENQCMD) printf(" ENQCMD");
	if (cpu.EXTRA & F_EXTRA_SKINIT) printf(" SKINIT+STGI");

	//
	// ANCHOR Vendor specific technologies
	//

	printf("\n[Technologies]");

	switch (cpu.VendorID) {
	case VENDOR_INTEL:
		if (cpu.TECH & F_TECH_EIST) printf(" EIST");
		if (cpu.TECH & F_TECH_TURBOBOOST)
			printf(cpu.TECH & F_TECH_TURBOBOOST30 ?
				" TurboBoot-3.0" : " TurboBoost");
		if (cpu.TECH & F_MEM_HLE || cpu.TECH & F_MEM_RTM) {
			printf(" Intel-TSX (");
			if (cpu.TECH & F_MEM_HLE)
				printf("HLE");
			if (cpu.TECH & F_MEM_HLE && cpu.TECH & F_MEM_RTM)
				printf(", ");
			if (cpu.TECH & F_MEM_RTM)
				printf("RTM");
			printf(")");
		}
		if (cpu.TECH & F_TECH_SMX) printf(" Intel-TXT/SMX");
		if (cpu.TECH & F_TECH_SGX) printf(" Intel-SGX");
		break;
	case VENDOR_AMD:
		if (cpu.TECH & F_TECH_TURBOBOOST) printf(" Core-Performance-Boost");
		break;
	default:
	}
	if (cpu.TECH & F_TECH_HTT) printf(" HTT");

	//
	// ANCHOR Cache information
	//

	printf("\n[Cache]");
	if (cpu.CACHE & F_CACHE_CLFLUSH) {
		printf(" CLFLUSH:%uB", cpu.CLFLUSHLineSize << 3);
	}
	if (cpu.EXTRA & F_EXTRA_CLFLUSHOPT) printf(" CLFLUSHOPT");
	if (cpu.CACHE & F_CACHE_CNXT_ID) printf(" CNXT_ID");
	if (cpu.CACHE & F_CACHE_SS) printf(" SS");
	if (cpu.CACHE & F_CACHE_PREFETCHW) printf(" PREFETCHW");
	if (cpu.CACHE & F_CACHE_INVPCID) printf(" INVPCID");
	if (cpu.CACHE & F_CACHE_WBNOINVD) printf(" WBNOINVD");

	CACHEINFO *ca = cast(CACHEINFO*)cpu.caches; /// Caches

	while (ca.type) {
		char c = 'K';
		if (ca.size >= 1024) {
			ca.size >>= 10;
			c = 'M';
		}
		printf("\n- L%u-%c: %u %ciB, %u ways, %u partitions, %u B, %u sets",
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
	if (cpu.ACPI & F_ACPI_ACPI) printf(" ACPI");
	if (cpu.ACPI & F_ACPI_APIC) printf(" APIC");
	if (cpu.ACPI & F_ACPI_x2APIC) printf(" x2APIC");
	if (cpu.ACPI & F_ACPI_ARAT) printf(" ARAT");
	if (cpu.ACPI & F_ACPI_TM) printf(" TM");
	if (cpu.ACPI & F_ACPI_TM2) printf(" TM2");
	if (cpu.InitialAPICID) printf(" APIC-ID:%u", cpu.InitialAPICID);
	if (cpu.MaxIDs) printf(" MAX-ID:%u", cpu.MaxIDs);

	printf("\n[Virtualization]");
	if (cpu.VIRT & F_VIRT_VME) printf(" VME");
	if (cpu.MaximumVirtLeaf >= 0x4000_0000) {
		if (cpu.virt_vendor_id)
			printf(" HOST:%.12s", cast(char*)cpu.virt_vendor);
		switch (cpu.virt_vendor_id) {
		case VIRT_VENDOR_VBOX_MIN: // VBox Minimal Paravirt
			if (cpu.VIRT_SPEC)
				printf(" TSC_FREQ_KHZ:%u", cpu.VIRT_SPEC);
			if (cpu.VIRT_SPEC2)
				printf(" APIC_FREQ_KHZ:%u", cpu.VIRT_SPEC2);
			break;
		case VIRT_VENDOR_VBOX_HV: // Hyper-V
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_VP_RUNTIME_MSR) printf(" HV_BASE_FEAT_VP_RUNTIME_MSR");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_PART_TIME_REF_COUNT_MSR) printf(" HV_BASE_FEAT_PART_TIME_REF_COUNT_MSR");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_BASIC_SYNIC_MSRS) printf(" HV_BASE_FEAT_BASIC_SYNIC_MSRS");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_STIMER_MSRS) printf(" HV_BASE_FEAT_STIMER_MSRS");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_APIC_ACCESS_MSRS) printf(" HV_BASE_FEAT_APIC_ACCESS_MSRS");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_HYPERCALL_MSRS) printf(" HV_BASE_FEAT_HYPERCALL_MSRS");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_VP_ID_MSR) printf(" HV_BASE_FEAT_VP_ID_MSR");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_VIRT_SYS_RESET_MSR) printf(" HV_BASE_FEAT_VIRT_SYS_RESET_MSR");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_STAT_PAGES_MSR) printf(" HV_BASE_FEAT_STAT_PAGES_MSR");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_PART_REF_TSC_MSR) printf(" HV_BASE_FEAT_PART_REF_TSC_MSR");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_GUEST_IDLE_STATE_MSR) printf(" HV_BASE_FEAT_GUEST_IDLE_STATE_MSR");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_TIMER_FREQ_MSRS) printf(" HV_BASE_FEAT_TIMER_FREQ_MSRS");
			if (cpu.VIRT_SPEC & HV_BASE_FEAT_DEBUG_MSRS) printf(" HV_BASE_FEAT_DEBUG_MSRS");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_CREATE_PART) printf(" HV_PART_FLAGS_CREATE_PART");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_ACCESS_PART_ID) printf(" HV_PART_FLAGS_ACCESS_PART_ID");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_ACCESS_MEMORY_POOL) printf(" HV_PART_FLAGS_ACCESS_MEMORY_POOL");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_ADJUST_MSG_BUFFERS) printf(" HV_PART_FLAGS_ADJUST_MSG_BUFFERS");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_POST_MSGS) printf(" HV_PART_FLAGS_POST_MSGS");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_SIGNAL_EVENTS) printf(" HV_PART_FLAGS_SIGNAL_EVENTS");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_CREATE_PORT) printf(" HV_PART_FLAGS_CREATE_PORT");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_CONNECT_PORT) printf(" HV_PART_FLAGS_CONNECT_PORT");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_ACCESS_STATS) printf(" HV_PART_FLAGS_ACCESS_STATS");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_DEBUGGING) printf(" HV_PART_FLAGS_DEBUGGING");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_CPU_MGMT) printf(" HV_PART_FLAGS_CPU_MGMT");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_CPU_PROFILER) printf(" HV_PART_FLAGS_CPU_PROFILER");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_EXPANDED_STACK_WALK) printf(" HV_PART_FLAGS_EXPANDED_STACK_WALK");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_ACCESS_VSM) printf(" HV_PART_FLAGS_ACCESS_VSM");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_ACCESS_VP_REGS) printf(" HV_PART_FLAGS_ACCESS_VP_REGS");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_EXTENDED_HYPERCALLS) printf(" HV_PART_FLAGS_EXTENDED_HYPERCALLS");
			if (cpu.VIRT_SPEC2 & HV_PART_FLAGS_START_VP) printf(" HV_PART_FLAGS_START_VP");
			if (cpu.VIRT_SPEC3 & HV_PM_MAX_CPU_POWER_STATE_C0) printf(" HV_PM_MAX_CPU_POWER_STATE_C0");
			if (cpu.VIRT_SPEC3 & HV_PM_MAX_CPU_POWER_STATE_C1) printf(" HV_PM_MAX_CPU_POWER_STATE_C1");
			if (cpu.VIRT_SPEC3 & HV_PM_MAX_CPU_POWER_STATE_C2) printf(" HV_PM_MAX_CPU_POWER_STATE_C2");
			if (cpu.VIRT_SPEC3 & HV_PM_MAX_CPU_POWER_STATE_C3) printf(" HV_PM_MAX_CPU_POWER_STATE_C3");
			if (cpu.VIRT_SPEC3 & HV_PM_HPET_REQD_FOR_C3) printf(" HV_PM_HPET_REQD_FOR_C3");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_MWAIT) printf(" HV_MISC_FEAT_MWAIT");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_GUEST_DEBUGGING) printf(" HV_MISC_FEAT_GUEST_DEBUGGING");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_PERF_MON) printf(" HV_MISC_FEAT_PERF_MON");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_PCPU_DYN_PART_EVENT) printf(" HV_MISC_FEAT_PCPU_DYN_PART_EVENT");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_XMM_HYPERCALL_INPUT) printf(" HV_MISC_FEAT_XMM_HYPERCALL_INPUT");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_GUEST_IDLE_STATE) printf(" HV_MISC_FEAT_GUEST_IDLE_STATE");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_HYPERVISOR_SLEEP_STATE) printf(" HV_MISC_FEAT_HYPERVISOR_SLEEP_STATE");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_QUERY_NUMA_DISTANCE) printf(" HV_MISC_FEAT_QUERY_NUMA_DISTANCE");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_TIMER_FREQ) printf(" HV_MISC_FEAT_TIMER_FREQ");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_INJECT_SYNMC_XCPT) printf(" HV_MISC_FEAT_INJECT_SYNMC_XCPT");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_GUEST_CRASH_MSRS) printf(" HV_MISC_FEAT_GUEST_CRASH_MSRS");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_DEBUG_MSRS) printf(" HV_MISC_FEAT_DEBUG_MSRS");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_NPIEP1) printf(" HV_MISC_FEAT_NPIEP1");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_DISABLE_HYPERVISOR) printf(" HV_MISC_FEAT_DISABLE_HYPERVISOR");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_EXT_GVA_RANGE_FOR_FLUSH_VA_LIST) printf(" HV_MISC_FEAT_EXT_GVA_RANGE_FOR_FLUSH_VA_LIST");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_HYPERCALL_OUTPUT_XMM) printf(" HV_MISC_FEAT_HYPERCALL_OUTPUT_XMM");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_SINT_POLLING_MODE) printf(" HV_MISC_FEAT_SINT_POLLING_MODE");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_HYPERCALL_MSR_LOCK) printf(" HV_MISC_FEAT_HYPERCALL_MSR_LOCK");
			if (cpu.VIRT_SPEC3 & HV_MISC_FEAT_USE_DIRECT_SYNTH_MSRS) printf(" HV_MISC_FEAT_USE_DIRECT_SYNTH_MSRS");
			if (cpu.VIRT_SPEC4 & HV_HINT_HYPERCALL_FOR_PROCESS_SWITCH) printf(" HV_HINT_HYPERCALL_FOR_PROCESS_SWITCH");
			if (cpu.VIRT_SPEC4 & HV_HINT_HYPERCALL_FOR_TLB_FLUSH) printf(" HV_HINT_HYPERCALL_FOR_TLB_FLUSH");
			if (cpu.VIRT_SPEC4 & HV_HINT_HYPERCALL_FOR_TLB_SHOOTDOWN) printf(" HV_HINT_HYPERCALL_FOR_TLB_SHOOTDOWN");
			if (cpu.VIRT_SPEC4 & HV_HINT_MSR_FOR_APIC_ACCESS) printf(" HV_HINT_MSR_FOR_APIC_ACCESS");
			if (cpu.VIRT_SPEC4 & HV_HINT_MSR_FOR_SYS_RESET) printf(" HV_HINT_MSR_FOR_SYS_RESET");
			if (cpu.VIRT_SPEC4 & HV_HINT_RELAX_TIME_CHECKS) printf(" HV_HINT_RELAX_TIME_CHECKS");
			if (cpu.VIRT_SPEC4 & HV_HINT_DMA_REMAPPING) printf(" HV_HINT_DMA_REMAPPING");
			if (cpu.VIRT_SPEC4 & HV_HINT_INTERRUPT_REMAPPING) printf(" HV_HINT_INTERRUPT_REMAPPING");
			if (cpu.VIRT_SPEC4 & HV_HINT_X2APIC_MSRS) printf(" HV_HINT_X2APIC_MSRS");
			if (cpu.VIRT_SPEC4 & HV_HINT_DEPRECATE_AUTO_EOI) printf(" HV_HINT_DEPRECATE_AUTO_EOI");
			if (cpu.VIRT_SPEC4 & HV_HINT_SYNTH_CLUSTER_IPI_HYPERCALL) printf(" HV_HINT_SYNTH_CLUSTER_IPI_HYPERCALL");
			if (cpu.VIRT_SPEC4 & HV_HINT_EX_PROC_MASKS_INTERFACE) printf(" HV_HINT_EX_PROC_MASKS_INTERFACE");
			if (cpu.VIRT_SPEC4 & HV_HINT_NESTED_HYPERV) printf(" HV_HINT_NESTED_HYPERV");
			if (cpu.VIRT_SPEC4 & HV_HINT_INT_FOR_MBEC_SYSCALLS) printf(" HV_HINT_INT_FOR_MBEC_SYSCALLS");
			if (cpu.VIRT_SPEC4 & HV_HINT_NESTED_ENLIGHTENED_VMCS_INTERFACE) printf(" HV_HINT_NESTED_ENLIGHTENED_VMCS_INTERFACE");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_AVIC) printf(" HV_HOST_FEAT_AVIC");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_MSR_BITMAP) printf(" HV_HOST_FEAT_MSR_BITMAP");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_PERF_COUNTER) printf(" HV_HOST_FEAT_PERF_COUNTER");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_NESTED_PAGING) printf(" HV_HOST_FEAT_NESTED_PAGING");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_DMA_REMAPPING) printf(" HV_HOST_FEAT_DMA_REMAPPING");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_INTERRUPT_REMAPPING) printf(" HV_HOST_FEAT_INTERRUPT_REMAPPING");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_MEM_PATROL_SCRUBBER) printf(" HV_HOST_FEAT_MEM_PATROL_SCRUBBER");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_DMA_PROT_IN_USE) printf(" HV_HOST_FEAT_DMA_PROT_IN_USE");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_HPET_REQUESTED) printf(" HV_HOST_FEAT_HPET_REQUESTED");
			if (cpu.VIRT_SPEC4 & HV_HOST_FEAT_STIMER_VOLATILE) printf(" HV_HOST_FEAT_STIMER_VOLATILE");
			break;
		case VIRT_VENDOR_KVM:
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_CLOCKSOURCE) printf(" KVM_FEATURE_CLOCKSOURCE");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_NOP_IO_DELAY) printf(" KVM_FEATURE_NOP_IO_DELAY");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_MMU_OP) printf(" KVM_FEATURE_MMU_OP");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_CLOCKSOURCE2) printf(" KVM_FEATURE_CLOCKSOURCE2");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_ASYNC_PF) printf(" KVM_FEATURE_ASYNC_PF");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_STEAL_TIME) printf(" KVM_FEATURE_STEAL_TIME");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_PV_EOI) printf(" KVM_FEATURE_PV_EOI");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_PV_UNHAULT) printf(" KVM_FEATURE_PV_UNHAULT");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_PV_TLB_FLUSH) printf(" KVM_FEATURE_PV_TLB_FLUSH");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_ASYNC_PF_VMEXIT) printf(" KVM_FEATURE_ASYNC_PF_VMEXIT");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_PV_SEND_IPI) printf(" KVM_FEATURE_PV_SEND_IPI");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_PV_POLL_CONTROL) printf(" KVM_FEATURE_PV_POLL_CONTROL");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_PV_SCHED_YIELD) printf(" KVM_FEATURE_PV_SCHED_YIELD");
			if (cpu.VIRT_SPEC & F_KVM_FEATURE_CLOCSOURCE_STABLE_BIT) printf(" KVM_FEATURE_CLOCSOURCE_STABLE_BIT");
			if (cpu.VIRT_SPEC & F_KVM_HINTS_REALTIME) printf(" KVM_HINTS_REALTIME");
			break;
		default:
		}
	}

	printf("\n[Memory]");
	if (cpu.phys_bits) printf(" P-Bits:%u", cpu.phys_bits);
	if (cpu.line_bits) printf(" L-Bits:%u", cpu.line_bits);
	if (cpu.MEM & F_MEM_PAE) printf(" PAE");
	if (cpu.MEM & F_MEM_PSE) printf(" PSE");
	if (cpu.MEM & F_MEM_PSE_36) printf(" PSE-36");
	if (cpu.MEM & F_MEM_PAGE1GB) printf(" Page1GB");
	if (cpu.MEM & F_MEM_NX)
		switch (cpu.VendorID) {
		case VENDOR_INTEL: printf(" Intel-XD/NX"); break;
		case VENDOR_AMD: printf(" AMD-EVP/NX"); break;
		default: printf(" NX");
		}
	if (cpu.MEM & F_MEM_DCA) printf(" DCA");
	if (cpu.MEM & F_MEM_PAT) printf(" PAT");
	if (cpu.MEM & F_MEM_MTRR) printf(" MTRR");
	if (cpu.MEM & F_MEM_PGE) printf(" PGE");
	if (cpu.MEM & F_MEM_SMEP) printf(" SMEP");
	if (cpu.MEM & F_MEM_SMAP) printf(" SMAP");
	if (cpu.MEM & F_MEM_PKU) printf(" PKU");
	if (cpu.MEM & F_MEM_5PL) printf(" 5PL");
	if (cpu.MEM & F_MEM_FSREPMOV) printf(" FSREPMOV");

	printf("\n[Debugging]");
	if (cpu.DEBUG & F_DEBUG_MCA) printf(" MCA");
	if (cpu.DEBUG & F_DEBUG_MCE) printf(" MCE");
	if (cpu.DEBUG & F_DEBUG_DE) printf(" DE");
	if (cpu.DEBUG & F_DEBUG_DS) printf(" DS");
	if (cpu.DEBUG & F_DEBUG_DS_CPL) printf(" DS-CPL");
	if (cpu.DEBUG & F_DEBUG_DTES64) printf(" DTES64");
	if (cpu.DEBUG & F_DEBUG_PDCM) printf(" PDCM");
	if (cpu.DEBUG & F_DEBUG_SDBG) printf(" SDBG");
	if (cpu.DEBUG & F_DEBUG_PBE) printf(" PBE");

	printf("\n[Security]");
	if (cpu.SEC & F_SEC_IBPB) printf(" IBPB");
	if (cpu.SEC & F_SEC_IBRS) printf(" IBRS");
	if (cpu.SEC & F_SEC_STIBP) printf(" STIBP");
	if (cpu.SEC & F_SEC_SSBD) printf(" SSBD");

	switch (cpu.VendorID) {
	case VENDOR_INTEL:
		if (cpu.SEC & F_SEC_L1D_FLUSH) printf(" L1D_FLUSH");
		if (cpu.SEC & F_SEC_MD_CLEAR) printf(" MD_CLEAR");
		if (cpu.SEC & F_SEC_CET_IBT) printf(" CET_IBT");
		break;
	case VENDOR_AMD:
		if (cpu.SEC & F_SEC_IBRS_ON) printf(" IBRS_ON");
		if (cpu.SEC & F_SEC_IBRS_PREF) printf(" IBRS_PREF");
		if (cpu.SEC & F_SEC_STIBP_ON) printf(" STIBP_ON");
		break;
	default:
	}

	printf("\n[Misc.] HLeaf:%Xh HELeaf:%Xh Type:%s Index:%u",
		cpu.MaximumLeaf, cpu.MaximumExtendedLeaf,
		PROCESSOR_TYPE[cpu.ProcessorType], cpu.BrandIndex);
	if (cpu.MISC & F_MISC_xTPR) printf(" xTPR");
	if (cpu.MISC & F_MISC_PSN) printf(" PSN");
	if (cpu.MISC & F_MISC_PCID) printf(" PCID");
	if (cpu.MISC & F_MISC_IA32_ARCH_CAPABILITIES) printf(" IA32_ARCH_CAPABILITIES");
	if (cpu.MISC & F_MISC_FSGSBASE) printf(" FSGSBASE");

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

	debug printf("VendorID: %X\n", VendorID);

	uint l; /// Cache level
	CACHEINFO *ca = cast(CACHEINFO*)s.caches;

	uint a = void, b = void, c = void, d = void; // EAX to EDX

	switch (s.VendorID) { // CACHE INFORMATION
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
		s.caches[0].level = s.caches[1].level = 1; // L1
		s.caches[0].type = 1; // data
		s.caches[0].__bundle1 = c;
		s.caches[0].size = s.caches[0]._amdsize;
		s.caches[1].__bundle1 = d;
		s.caches[1].size = s.caches[1]._amdsize;

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
			s.caches[2].level = 2; // L2
			s.caches[2].type = 3; // unified
			s.caches[2].ways = _amd_ways(_amd_ways_l2);
			s.caches[2].size = c >> 16;
			s.caches[2].sets = (c >> 8) & 7;
			s.caches[2].linesize = cast(ubyte)c;

			ubyte _amd_ways_l3 = (d >> 12) & 0b111;
			if (_amd_ways_l3) {
				s.caches[3].level = 3; // L2
				s.caches[3].type = 3; // unified
				s.caches[3].ways = _amd_ways(_amd_ways_l3);
				s.caches[3].size = ((d >> 18) + 1) * 512;
				s.caches[3].sets = (d >> 8) & 7;
				s.caches[3].linesize = cast(ubyte)(d & 0x7F);
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
		"mov %%edx, %3"
		: "=a" a, "=b" b, "=c" c, "=d" d;
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

	switch (s.VendorID) {
	case VENDOR_INTEL:
		s.Family = s.BaseFamily != 0 ?
			s.BaseFamily :
			cast(ubyte)(s.ExtendedFamily + s.BaseFamily);

		s.Model = s.BaseFamily == 6 || s.BaseFamily == 0 ?
			cast(ubyte)((s.ExtendedModel << 4) + s.BaseModel) :
			s.BaseModel; // DisplayModel = Model_ID;

		// ECX
		if (c & BIT!(2)) s.DEBUG  |= F_DEBUG_DTES64;
		if (c & BIT!(4)) s.DEBUG  |= F_DEBUG_DS_CPL;
		if (c & BIT!(5)) s.VIRT   |= F_VIRT_VIRT;
		if (c & BIT!(6)) s.TECH   |= F_TECH_SMX;
		if (c & BIT!(7)) s.TECH   |= F_TECH_EIST;
		if (c & BIT!(8)) s.ACPI   |= F_ACPI_TM2;
		if (c & BIT!(10)) s.CACHE |= F_CACHE_CNXT_ID;
		if (c & BIT!(11)) s.DEBUG |= F_DEBUG_SDBG;
		if (c & BIT!(14)) s.MISC  |= F_MISC_xTPR;
		if (c & BIT!(15)) s.DEBUG |= F_DEBUG_PDCM;
		if (c & BIT!(17)) s.MISC  |= F_MISC_PCID;
		if (c & BIT!(18)) s.DEBUG |= F_DEBUG_MCA;
		if (c & BIT!(21)) s.ACPI  |= F_ACPI_x2APIC;
		if (c & BIT!(24)) s.EXTRA |= F_EXTRA_TSC_DEADLINE;

		// EDX
		if (d & BIT!(18)) s.MISC  |= F_MISC_PSN;
		if (d & BIT!(21)) s.DEBUG |= F_DEBUG_DS;
		if (d & BIT!(22)) s.ACPI  |= F_ACPI_ACPI;
		if (d & BIT!(27)) s.CACHE |= F_CACHE_SS;
		if (d & BIT!(29)) s.ACPI  |= F_ACPI_TM;
		if (d & BIT!(31)) s.DEBUG |= F_DEBUG_PBE;
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
	s.b_01_ebx = b; // BrandIndex, CLFLUSHLineSize, MaxIDs, InitialAPICID

	// ECX
	if (c & BIT!(0)) s.EXTEN  |= F_EXTEN_SSE3;
	if (c & BIT!(1)) s.EXTRA  |= F_EXTRA_PCLMULQDQ;
	if (c & BIT!(3)) s.EXTRA  |= F_EXTRA_MONITOR;
	if (c & BIT!(9)) s.EXTEN  |= F_EXTEN_SSSE3;
	if (c & BIT!(12)) s.EXTEN |= F_EXTEN_FMA;
	if (c & BIT!(13)) s.EXTRA |= F_EXTRA_CMPXCHG16B;
	if (c & BIT!(15)) s.EXTEN |= F_EXTEN_SSE41;
	if (c & BIT!(20)) s.EXTEN |= F_EXTEN_SSE42;
	if (c & BIT!(22)) s.EXTRA |= F_EXTRA_MOVBE;
	if (c & BIT!(23)) s.EXTRA |= F_EXTRA_POPCNT;
	if (c & BIT!(25)) s.EXTEN |= F_EXTEN_AES_NI;
	if (c & BIT!(26)) s.EXTEN |= F_EXTRA_XSAVE;
	if (c & BIT!(27)) s.EXTRA |= F_EXTRA_OSXSAVE;
	if (c & BIT!(28)) s.AVX   |= F_AVX_AVX;
	if (c & BIT!(29)) s.EXTEN |= F_EXTEN_F16C;
	if (c & BIT!(30)) s.EXTRA |= F_EXTRA_RDRAND;

	// EDX
	if (d & BIT!(0)) s.EXTEN  |= F_EXTEN_FPU;
	if (d & BIT!(1)) s.VIRT   |= F_VIRT_VME;
	if (d & BIT!(2)) s.DEBUG  |= F_DEBUG_DE;
	if (d & BIT!(3)) s.MEM    |= F_MEM_PSE;
	if (d & BIT!(4)) s.EXTRA  |= F_EXTRA_TSC;
	if (d & BIT!(5)) s.EXTRA  |= F_EXTRA_RDMSR;
	if (d & BIT!(6)) s.MEM    |= F_MEM_PAE;
	if (d & BIT!(7)) s.DEBUG  |= F_DEBUG_MCE;
	if (d & BIT!(8)) s.EXTRA  |= F_EXTRA_CMPXCHG8B;
	if (d & BIT!(9)) s.ACPI   |= F_ACPI_APIC;
	if (d & BIT!(11)) s.EXTRA |= F_EXTRA_SYSENTER;
	if (d & BIT!(12)) s.MEM   |= F_MEM_MTRR;
	if (d & BIT!(13)) s.MEM   |= F_MEM_PGE;
	if (d & BIT!(14)) s.DEBUG |= F_DEBUG_MCA;
	if (d & BIT!(15)) s.EXTRA |= F_EXTRA_CMOV;
	if (d & BIT!(16)) s.MEM   |= F_MEM_PAT;
	if (d & BIT!(17)) s.MEM   |= F_MEM_PSE_36;
	if (d & BIT!(19)) s.CACHE |= F_CACHE_CLFLUSH;
	if (d & BIT!(23)) s.EXTEN |= F_EXTEN_MMX;
	if (d & BIT!(24)) s.EXTRA |= F_EXTRA_FXSR;
	if (d & BIT!(25)) s.EXTEN |= F_EXTEN_SSE;
	if (d & BIT!(26)) s.EXTEN |= F_EXTEN_SSE2;
	if (d & BIT!(28)) s.TECH  |= F_TECH_HTT;

	if (s.MaximumLeaf < 5) goto EXTENDED_LEAVES;

	version (GNU) asm {
		"mov $5, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%ebx, %1\n"
		: "=a" a "=b" b;
	} else asm {
		mov EAX, 5;
		cpuid;
		mov a, EAX;
		mov b, EBX;
	} // ----- 5H

	s.mwait_min = cast(ushort)a;
	s.mwait_max = cast(ushort)b;

	if (s.MaximumLeaf < 6) goto EXTENDED_LEAVES;

	version (GNU) asm {
		"mov $6, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0"
		: "=a" a;
	} else asm {
		mov EAX, 6;
		cpuid;
		mov a, EAX;
	} // ----- 6H

	switch (s.VendorID) {
	case VENDOR_INTEL:
		if (a & BIT!(1))  s.TECH |= F_TECH_TURBOBOOST;
		if (a & BIT!(14)) s.TECH |= F_TECH_TURBOBOOST30;
		break;
	default:
	}

	if (a & BIT!(2)) s.ACPI |= F_ACPI_ARAT;

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

	switch (s.VendorID) {
	case VENDOR_INTEL:
		// EBX
		if (b & BIT!(2)) s.TECH   |= F_TECH_SGX;
		if (b & BIT!(4)) s.MEM    |= F_MEM_HLE;
		if (b & BIT!(10)) s.CACHE |= F_CACHE_INVPCID;
		if (b & BIT!(11)) s.MEM   |= F_MEM_RTM;
		if (b & BIT!(16)) s.AVX   |= F_AVX_AVX512F;
		if (b & BIT!(20)) s.MEM   |= F_MEM_SMAP;
		if (b & BIT!(27)) s.AVX   |= F_AVX_AVX512ER;
		if (b & BIT!(26)) s.AVX   |= F_AVX_AVX512PF;
		if (b & BIT!(28)) s.AVX   |= F_AVX_AVX512CD;
		if (b & BIT!(17)) s.AVX   |= F_AVX_AVX512DQ;
		if (b & BIT!(30)) s.AVX   |= F_AVX_AVX512BW;
		if (b & BIT!(21)) s.AVX   |= F_AVX_AVX512_IFMA;
		if (b & BIT!(31)) s.AVX   |= F_AVX_AVX512_VBMI;
		// ECX
		if (c & BIT!(1)) s.AVX    |= F_AVX_AVX512VL;
		if (c & BIT!(3)) s.MEM    |= F_MEM_PKU;
		if (c & BIT!(4)) s.MEM    |= F_MEM_FSREPMOV;
		if (c & BIT!(5)) s.EXTEN  |= F_EXTEN_WAITPKG;
		if (c & BIT!(6)) s.AVX    |= F_AVX_AVX512_VBMI2;
		if (c & BIT!(8)) s.AVX    |= F_AVX_AVX512_GFNI;
		if (c & BIT!(9)) s.AVX    |= F_AVX_AVX512_VAES;
		if (c & BIT!(11)) s.AVX   |= F_AVX_AVX512_VNNI;
		if (c & BIT!(12)) s.AVX   |= F_AVX_AVX512_BITALG;
		if (c & BIT!(14)) s.AVX   |= F_AVX_AVX512_VPOPCNTDQ;
		if (c & BIT!(16)) s.MEM   |= F_MEM_5PL;
		if (c & BIT!(25)) s.EXTRA |= F_EXTRA_CLDEMOTE;
		if (c & BIT!(27)) s.EXTRA |= F_EXTRA_MOVDIRI;
		if (c & BIT!(28)) s.EXTRA |= F_EXTRA_MOVDIR64B;
		if (c & BIT!(29)) s.EXTRA |= F_EXTRA_ENQCMD;
		// EDX
		if (d & BIT!(2)) s.AVX    |= F_AVX_AVX512_4VNNIW;
		if (d & BIT!(3)) s.AVX    |= F_AVX_AVX512_4FMAPS;
		if (d & BIT!(8)) s.AVX    |= F_AVX_AVX512_VP2INTERSECT;
		if (d & BIT!(10)) s.SEC   |= F_SEC_MD_CLEAR;
		if (d & BIT!(18)) s.EXTRA |= F_EXTRA_PCONFIG;
		if (d & BIT!(20)) s.SEC   |= F_SEC_CET_IBT;
		if (d & BIT!(26)) s.SEC   |= (F_SEC_IBRS | F_SEC_IBPB);
		if (d & BIT!(27)) s.SEC   |= F_SEC_STIBP;
		if (d & BIT!(28)) s.SEC   |= F_SEC_L1D_FLUSH;
		if (d & BIT!(29)) s.MISC  |= F_MISC_IA32_ARCH_CAPABILITIES;
		if (d & BIT!(31)) s.SEC   |= F_SEC_SSBD;
		break;
	default:
	}

	// b
	if (b & BIT!(0)) s.MISC   |= F_MISC_FSGSBASE;
	if (b & BIT!(3)) s.EXTEN  |= F_EXTEN_BMI1;
	if (b & BIT!(5)) s.AVX    |= F_AVX_AVX2;
	if (b & BIT!(7)) s.MEM    |= F_MEM_SMEP;
	if (b & BIT!(8)) s.EXTEN  |= F_EXTEN_BMI2;
	if (b & BIT!(18)) s.EXTRA |= F_EXTRA_RDSEED;
	if (b & BIT!(19)) s.EXTEN |= F_EXTEN_ADX;
	if (b & BIT!(23)) s.EXTRA |= F_EXTRA_CLFLUSHOPT;
	if (b & BIT!(29)) s.EXTEN |= F_EXTEN_SHA;
	// c
	if (c & BIT!(22)) s.EXTRA |= F_EXTRA_RDPID;

	switch (s.VendorID) {
	case VENDOR_INTEL:
		version (GNU) asm {
			"mov $7, %%eax\n"~
			"mov $1, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"
			: "=a" a;
		} else asm {
			mov EAX, 7;
			mov ECX, 1;
			cpuid;
			mov a, EAX;
		} // ----- 7H ECX=1h
		// a
		if (a & BIT!(5)) s.AVX |= F_AVX_AVX512_BF16;
		break;
	default:
	}

	if (s.MaximumVirtLeaf < 0x4000_0000) goto EXTENDED_LEAVES;

	__A = cast(size_t)&s.virt_vendor;
	version (X86_64) {
		version (GNU) asm {
			"mov %0, %%rdi\n"~
			"mov $0x40000000, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n"~
			"mov %%ecx, 4(%%rdi)\n"~
			"mov %%edx, 8(%%rdi)\n"
			: "=m" __A;
		} else asm {
			mov RDI, __A;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [RDI], EBX;
			mov [RDI+4], ECX;
			mov [RDI+8], EDX;
		}
	} else {
		version (GNU) asm {
			"mov %0, %%edi\n"~
			"mov $0x40000000, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, (%%edi)\n"~
			"mov %%ecx, 4(%%edi)\n"~
			"mov %%edx, 8(%%edi)\n"
			: "m" __A;
		} else asm {
			mov EDI, __A;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [EDI], EBX;
			mov [EDI+4], ECX;
			mov [EDI+8], EDX;
		}
	}

	if (s.MaximumVirtLeaf < 0x4000_0001) goto EXTENDED_LEAVES;

	version (GNU) asm {
		"mov $0x40000001, %%eax\n"~
		"mov $0, %%ecx\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%edx, %1\n"
		: "=a" a, "=d" d;
	} else asm {
		mov EAX, 0x4000_0001;
		mov ECX, 0;
		cpuid;
		mov a, EAX;
		mov d, EDX;
	} // ----- 4000_0001H ECX=0h

	switch (s.virt_vendor_id) {
	case VIRT_VENDOR_KVM:
		s.VIRT_SPEC = a;
		if (d & BIT!(0)) s.VIRT_SPEC |= F_KVM_HINTS_REALTIME;
		break;
	default:
	}

	if (s.MaximumVirtLeaf < 0x4000_0003) goto EXTENDED_LEAVES;

	version (GNU) asm {
		"mov $0x40000003, %%eax\n"~
		"mov $0, %%ecx\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%ebx, %1\n"~
		"mov %%ecx, %2\n"~
		"mov %%edx, %3\n"
		: "=a" a, "=b" b, "=c" c, "=d", d;
	} else asm {
		mov EAX, 0x4000_0003;
		mov ECX, 0;
		cpuid;
		mov a, EAX;
		mov b, EBX;
		mov c, ECX;
		mov d, EDX;
	} // ----- 4000_0003H ECX=0h

	switch (s.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		s.VIRT_SPEC = a;
		s.VIRT_SPEC2 = b;
		s.VIRT_SPEC3 = (c << 24) | d;
		break;
	default:
	}

	if (s.MaximumVirtLeaf < 0x4000_0004) goto EXTENDED_LEAVES;

	version (GNU) asm {
		"mov $0x40000004, %%eax\n"~
		"mov $0, %%ecx\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"
		: "=a" a;
	} else asm {
		mov EAX, 0x4000_0004;
		mov ECX, 0;
		cpuid;
		mov a, EAX;
	} // ----- 4000_0004H ECX=0h

	switch (s.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		s.VIRT_SPEC4 = a << 16;
		break;
	default:
	}

	if (s.MaximumVirtLeaf < 0x4000_0006) goto EXTENDED_LEAVES;

	version (GNU) asm {
		"mov $0x40000006, %%eax\n"~
		"mov $0, %%ecx\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"
		: "=a" a;
	} else asm {
		mov EAX, 0x4000_0006;
		mov ECX, 0;
		cpuid;
		mov a, EAX;
	} // ----- 4000_0006H ECX=0h

	switch (s.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		s.VIRT_SPEC4 |= cast(ushort)a;
		break;
	default:
	}

	if (s.MaximumVirtLeaf < 0x4000_0010) goto EXTENDED_LEAVES;

	version (GNU) asm {
		"mov $0x40000010, %%eax\n"~
		"mov $0, %%ecx\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%ebx, %1\n"
		: "=a" a, "=b" b;
	} else asm {
		mov EAX, 0x4000_0010;
		mov ECX, 0;
		cpuid;
		mov a, EAX;
		mov b, EBX;
	} // ----- 4000_0001H ECX=0h

	switch (s.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_MIN: // VBox Minimal
		s.VIRT_SPEC = a;
		s.VIRT_SPEC2 = b;
		break;
	default:
	}

	//
	// Extended CPUID leaves
	//

EXTENDED_LEAVES:

	version (GNU) asm {
		"mov $0x80000001, %%eax\n"~
		"cpuid\n"~
		"mov %%ecx, %0\n"~
		"mov %%edx, %1"
		: "=c" c, "=d" d;
	} else asm {
		mov EAX, 0x8000_0001;
		cpuid;
		mov c, ECX;
		mov d, EDX;
	} // EXTENDED 8000_0001H

	switch (s.VendorID) {
	case VENDOR_AMD:
		if (c & BIT!(2)) s.VIRT   |= F_VIRT_VIRT;
		if (c & BIT!(3)) s.ACPI   |= F_ACPI_x2APIC;
		if (c & BIT!(6)) s.EXTEN  |= F_EXTEN_SSE4a;
		if (c & BIT!(11)) s.EXTEN |= F_EXTEN_XOP;
		if (c & BIT!(12)) s.EXTRA |= F_EXTRA_SKINIT;
		if (c & BIT!(16)) s.EXTEN |= F_EXTEN_FMA4;
		if (c & BIT!(21)) s.EXTEN |= F_EXTEN_TBM;
		if (c & BIT!(29)) s.EXTRA |= F_EXTRA_MONITORX;
		if (d & BIT!(22)) s.EXTEN |= F_EXTEN_MMXEXT;
		if (d & BIT!(30)) s.EXTEN |= F_EXTEN_3DNOWEXT;
		if (d & BIT!(31)) s.EXTEN |= F_EXTEN_3DNOW;
		break;
	default:
	}

	if (c & BIT!(0)) s.EXTEN  |= F_EXTEN_LAHF64;
	if (c & BIT!(5)) s.EXTRA  |= F_EXTRA_LZCNT;
	if (c & BIT!(8)) s.CACHE  |= F_CACHE_PREFETCHW;
	if (d & BIT!(11)) s.EXTRA |= F_EXTRA_SYSCALL;
	if (d & BIT!(20)) s.MEM   |= F_MEM_NX;
	if (d & BIT!(26)) s.MEM   |= F_MEM_PAGE1GB;
	if (d & BIT!(27)) s.EXTRA |= F_EXTRA_RDTSCP;
	if (d & BIT!(29)) s.EXTEN |= F_EXTEN_x86_64;

	if (s.MaximumExtendedLeaf < 0x8000_0007) return;

	version (GNU) asm {
		"mov $0x80000007, %%eax\n"~
		"cpuid\n"~
		"mov %%ebx, %0\n"~
		"mov %%edx, %1"
		: "=b" b, "=d" d;
	} else asm {
		mov EAX, 0x8000_0007;
		cpuid;
		mov b, EBX;
		mov d, EDX;
	} // EXTENDED 8000_0007H

	switch (s.VendorID) {
	case VENDOR_INTEL:
		if (b & BIT!(28)) s.EXTRA |= F_EXTRA_RDSEED;
		break;
	case VENDOR_AMD:
		if (d & BIT!(4)) s.ACPI |= F_ACPI_TM;
		if (d & BIT!(9)) s.TECH |= F_TECH_TURBOBOOST;
		break;
	default:
	}

	if (d & BIT!(8)) s.EXTRA |= F_EXTRA_TSC_INVARIANT;

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

	switch (s.VendorID) {
	case VENDOR_INTEL:
		if (b & BIT!(9)) s.CACHE |= F_CACHE_WBNOINVD;
		break;
	case VENDOR_AMD:
		if (b & BIT!(12)) s.SEC |= F_SEC_IBPB;
		if (b & BIT!(14)) s.SEC |= F_SEC_IBRS;
		if (b & BIT!(15)) s.SEC |= F_SEC_STIBP;
		if (b & BIT!(16)) s.SEC |= F_SEC_IBRS_ON;
		if (b & BIT!(17)) s.SEC |= F_SEC_STIBP_ON;
		if (b & BIT!(18)) s.SEC |= F_SEC_IBRS_PREF;
		if (b & BIT!(24)) s.SEC |= F_SEC_SSBD;
		break;
	default:
	}

	s.b_8000_0008_ax = cast(ushort)a; // s.addr_phys_bits, s.addr_line_bits

	if (s.MaximumExtendedLeaf < 0x8000_000A) return;

	version (GNU) asm {
		"mov $0x8000000a, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0"
		: "=a" a;
	} else asm {
		mov EAX, 0x8000_000A;
		cpuid;
		mov a, EAX;
	} // EXTENDED 8000_000AH

	switch (s.VendorID) {
	case VENDOR_AMD:
		s.virt_ver = cast(ubyte)a; // EAX[7:0]
		break;
	default:
	}

	//if (s.MaximumExtendedLeaf < ...) return;
}

/// Get maximum leaf and maximum extended leaf into CPUINFO
void leafs(ref CPUINFO cpu) {
	version (GNU) { // GDC
		uint l = void, lv = void, le = void; // @suppress(dscanner.suspicious.unmodified)
		asm {
			"mov $0, %%eax\n"~
			"cpuid"
			: "=a" l;
		}
		asm {
			"mov $0x40000000, %%eax\n"~
			"cpuid"
			: "=a" lv;
		}
		asm {
			"mov $0x80000000, %%eax\n"~
			"cpuid"
			: "=a" le;
		}
		cpu.MaximumLeaf = l;
		cpu.MaximumVirtLeaf = lv;
		cpu.MaximumExtendedLeaf = le;
	} else
	version (LDC) { // LDC2
		version (X86)
		asm {
			lea ESI, cpu;
			mov EAX, 0;
			cpuid;
			mov [ESI + cpu.MaximumLeaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [ESI + cpu.MaximumVirtLeaf.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [ESI + cpu.MaximumExtendedLeaf.offsetof], EAX;
		}
		else
		version (X86_64)
		asm {
			lea RSI, cpu;
			mov EAX, 0;
			cpuid;
			mov [RSI + cpu.MaximumLeaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [RSI + cpu.MaximumVirtLeaf.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [RSI + cpu.MaximumExtendedLeaf.offsetof], EAX;
		}
	} else { // DMD
		version (X86)
		asm {
			mov ESI, cpu;
			mov EAX, 0;
			cpuid;
			mov [ESI + cpu.MaximumLeaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [ESI + cpu.MaximumVirtLeaf.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [ESI + cpu.MaximumExtendedLeaf.offsetof], EAX;
		}
		else
		version (X86_64)
		asm {
			mov RSI, cpu;
			mov EAX, 0;
			cpuid;
			mov [RSI + cpu.MaximumLeaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [RSI + cpu.MaximumVirtLeaf.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [RSI + cpu.MaximumExtendedLeaf.offsetof], EAX;
		}
	}
}

struct CACHEINFO {
	union {
		uint __bundle1;
		struct {
			ubyte linesize;
			ubyte partitions; // or "lines per tag" (AMD)
			ubyte ways; // n-way
			ubyte _amdsize; // (old AMD) Size in KB
		}
	}
	/// Cache Size in Bytes
	/// (Ways + 1) * (Partitions + 1) * (Line_Size + 1) * (Sets + 1)
	/// (EBX[31:22] + 1) * (EBX[21:12] + 1) * (EBX[11:0] + 1) * (ECX + 1)
	uint size; // Size in KB
	ushort sets;
	// bit 0, Self Initializing cache level
	// bit 1, Fully Associative cache
	// bit 2, Write-Back Invalidate/Invalidate (toggle)
	// bit 3, Cache Inclusiveness (toggle)
	// bit 4, Complex Cache Indexing (toggle)
	ushort features;
	ubyte type; // data=1, instructions=2, unified=3
	ubyte level; // L1, L2, etc.
}

struct CPUINFO { align(1):
	uint MaximumLeaf;
	uint MaximumExtendedLeaf;
	uint MaximumVirtLeaf;

	union {
		ubyte [12]vendorString;	// inits to 0
		uint VendorID;
	}
	ubyte [48]cpuString;	// inits to 0

	//
	// Identifier
	//

	ubyte Family;
	ubyte BaseFamily;
	ubyte ExtendedFamily;
	ubyte Model;
	ubyte BaseModel;
	ubyte ExtendedModel;
	ubyte Stepping;
	ubyte ProcessorType;

	//
	// Extensions
	//

	/// Processor extensions$(BR)
	/// Bit 0: FPU/x87$(BR)
	/// Bit 1: F16C$(BR)
	/// Bit 2: MMX$(BR)
	/// Bit 3: MMXExt$(BR)
	/// Bit 4: 3DNow!$(BR)
	/// Bit 5: 3DNow!Ext$(BR)
	/// Bit 6: SSE$(BR)
	/// Bit 7: SSE2$(BR)
	/// Bit 8: SSE3$(BR)
	/// Bit 9: SSSE3$(BR)
	/// Bit 10: SSE4.1$(BR)
	/// Bit 11: SSE4.2$(BR)
	/// Bit 12: SSE4a$(BR)
	/// Bit 13: $(BR)
	/// Bit 14: $(BR)
	/// Bit 15: AES-NI$(BR)
	/// Bit 16: SHA 1/256$(BR)
	/// Bit 17: FMA$(BR)
	/// Bit 18: FMA4$(BR)
	/// Bit 19: BMI1$(BR)
	/// Bit 20: BMI2$(BR)
	/// Bit 21: x86_64 (long mode, EM64T/Intel64)$(BR)
	/// Bit 22: +LAHF/SAHF in long mode$(BR)
	/// Bit 23: WAITPKG$(BR)
	/// Bit 24: (AMD) XOP$(BR)
	/// Bit 25: (AMD) TBM$(BR)
	/// Bit 26: ADX$(BR)
	uint EXTEN;

	/// All AVX extensions$(BR)
	/// Bit 0: AVX$(BR)
	/// Bit 1: AVX2$(BR)
	/// Bit 2: AVX512F$(BR)
	/// Bit 3: AVX512ER$(BR)
	/// Bit 4: AVX512PF$(BR)
	/// Bit 5: AVX512CD$(BR)
	/// Bit 6: AVX512DQ$(BR)
	/// Bit 7: AVX512BW$(BR)
	/// Bit 8: AVX512VL$(BR)
	/// Bit 9: AVX512_IFMA$(BR)
	/// Bit 10: AVX512_VBMI$(BR)
	/// Bit 11: AVX512_VBMI2$(BR)
	/// Bit 12: AVX512_GFNI$(BR)
	/// Bit 13: AVX512_VAES$(BR)
	/// Bit 14: AVX512_VNNI$(BR)
	/// Bit 15: AVX512_BITALG$(BR)
	/// Bit 16: AVX512_VPOPCNTDQ$(BR)
	/// Bit 17: AVX512_4VNNIW$(BR)
	/// Bit 18: AVX512_4FMAPS$(BR)
	/// Bit 19: AVX512_BF16$(BR)
	/// Bit 20: AVX512_VP2INTERSECT$(BR)
	uint AVX;

	//
	// Extras
	//

	/// Processor extra instructions$(BR)
	/// Bit 0: MONITOR+WAIT$(BR)
	/// Bit 1: PCLMULQDQ$(BR)
	/// Bit 2: CMPXCHG8B$(BR)
	/// Bit 3: CMPXCHG16B$(BR)
	/// Bit 4: MOVBE$(BR)
	/// Bit 5: RDRAND$(BR)
	/// Bit 6: RDSEED$(BR)
	/// Bit 7: RDMSR+WRMSR, MSR bit$(BR)
	/// Bit 8: SYSENTER+SYSEXIT$(BR)
	/// Bit 9: RDTSC, TSC CPUID bit$(BR)
	/// Bit 10: +TSC-Deadline$(BR)
	/// Bit 11: +TSC-Invariant$(BR)
	/// Bit 12: RDTSCP$(BR)
	/// Bit 13: RDPID$(BR)
	/// Bit 14: CMOV (+ if FPU: FCOMI+FCMOV)$(BR)
	/// Bit 15: LZCNT$(BR)
	/// Bit 16: POPCNT$(BR)
	/// Bit 17: XSAVE+XRSTOR$(BR)
	/// Bit 18: XSETBV+XGETBV (OSXSAVE)$(BR)
	/// Bit 19: FXSAVE+FXRSTOR (FXSR)$(BR)
	/// Bit 20: PCONFIG$(BR)
	/// Bit 22: CLDEMOTE$(BR)
	/// Bit 23: MOVDIRI$(BR)
	/// Bit 24: MOVDIR64B$(BR)
	/// Bit 25: ENQCMD$(BR)
	/// Bit 26: SYSCALL+SYSRET$(BR)
	/// Bit 27: MONITORX+MWAITX$(BR)
	/// Bit 28: SKINIT+STGI$(BR)
	/// Bit 29: CLFLUSHOPT$(BR)
	uint EXTRA;

	//
	// Technologies
	//

	/// Processor technologies$(BR)
	/// Bit 0: (Intel) EIST: Ehanced SpeedStep$(BR)
	/// Bit 1: (Intel) TurboBoost (AMD) Core Performance Boost$(BR)
	/// Bit 2: (Intel) TurboBoost 3.0$(BR)
	/// Bit 3: (Intel) SMX: TPM/TXT$(BR)
	/// Bit 4: (Intel) SGX: Software Guard Extensions$(BR)
	/// Bit 24: HTT, Hyper-Threading Technology$(BR)
	uint TECH;
	
	//
	// Cache
	//

	// 6 levels should be enough (L1-D, L1-I, L2, L3, 0, 0)
	/// Caches
	CACHEINFO [6]caches;
	/// Cache features$(BR)
	/// Bit 0-7: CLFLUSH line size (bytes: * 8)$(BR)
	/// Bit 8: CLFLUSH available$(BR)
	/// Bit 9: CNXT-ID: L1 Context ID$(BR)
	/// Bit 10: SS: Self Snoop$(BR)
	/// Bit 11: PREFETCHW$(BR)
	/// Bit 12: INVPCID$(BR)
	/// Bit 13: WBNOINVD$(BR)
	ushort CACHE;

	//
	// ACPI
	//

	/// ACPI features$(BR)
	// Initial APIC ID and Maximum APIC IDs on dedicated fields$(BR)
	/// Bit 0: ACPI$(BR)
	/// Bit 1: APIC$(BR)
	/// Bit 2: x2APIC$(BR)
	/// Bit 3: ARAT: Always-Running-APIC-Timer feature$(BR)
	/// Bit 4: TM$(BR)
	/// Bit 5: TM2$(BR)
	uint ACPI;
	union { // 01h.EBX
		uint b_01_ebx;
		struct {
			ubyte BrandIndex;
			ubyte CLFLUSHLineSize;
			ubyte MaxIDs;
			ubyte InitialAPICID;
		}
	}
	ushort mwait_min;
	ushort mwait_max;

	//
	// Virtualization
	//

	/// Virtualization features$(BR)
	/// Bit 0-7: (AMD: EAX[7:0]) SVM version$(BR)
	/// Bit 8: VMX/SVM capable$(BR)
	/// Bit 9: VME$(BR)
	union {
		ubyte virt_ver;
		uint VIRT;
	}
	// Virtualization software vendor name
	union {
		char[12] virt_vendor;
		uint virt_vendor_id;
	}
	/// Hypervisor specific features$(BR)
	/// * KVM $(BR)
	/// Bit 0: (KVM) KVM_FEATURE_CLOCKSOURCE$(BR)
	/// Bit 1: (KVM) KVM_FEATURE_NOP_IO_DELAY$(BR)
	/// Bit 2: (KVM) KVM_FEATURE_MMU_OP$(BR)
	/// Bit 3: (KVM) KVM_FEATURE_CLOCKSOURCE2$(BR)
	/// Bit 4: (KVM) KVM_FEATURE_ASYNC_PF$(BR)
	/// Bit 5: (KVM) KVM_FEATURE_STEAL_TIME$(BR)
	/// Bit 6: (KVM) KVM_FEATURE_PV_EOI$(BR)
	/// Bit 7: (KVM) KVM_FEATURE_PV_UNHAULT$(BR)
	/// Bit 9: (KVM) KVM_FEATURE_PV_TLB_FLUSH$(BR)
	/// Bit 10: (KVM) KVM_FEATURE_ASYNC_PF_VMEXIT$(BR)
	/// Bit 11: (KVM) KVM_FEATURE_PV_SEND_IPI$(BR)
	/// Bit 12: (KVM) KVM_FEATURE_PV_POLL_CONTROL$(BR)
	/// Bit 13: (KVM) KVM_FEATURE_PV_SCHED_YIELD$(BR)
	/// Bit 24: (KVM) KVM_FEATURE_CLOCSOURCE_STABLE_BIT$(BR)
	/// Bit 25: (KVM) KVM_HINTS_REALTIME$(BR)
	/// * VBox Minimal$(BR)
	/// SPEC:  TSC_FREQ_KHZ$(BR)
	/// SPEC2: APIC_FREQ_KHZ$(BR)
	/// * VBox Hyper-V$(BR)
	/// 
	uint VIRT_SPEC;
	uint VIRT_SPEC2;
	uint VIRT_SPEC3;
	uint VIRT_SPEC4;

	//
	// Memory
	//

	/// Memory features$(BR)
	/// Bit 0: PAE$(BR)
	/// Bit 1: PSE$(BR)
	/// Bit 2: PSE-36$(BR)
	/// Bit 3: Page1GB$(BR)
	/// Bit 4: MTRR$(BR)
	/// Bit 5: PAT$(BR)
	/// Bit 6: PGE$(BR)
	/// Bit 7: DCA$(BR)
	/// Bit 8: NX (no execute)$(BR)
	/// Bit 9: HLE$(BR)
	/// Bit 10: RTM$(BR)
	/// Bit 11: SMEP$(BR)
	/// Bit 12: SMAP$(BR)
	/// Bit 13: PKU$(BR)
	/// Bit 14: 5PL (5-level paging)$(BR)
	/// Bit 15: FSREPMOV (fast rep mov)$(BR)
	uint MEM;
	union {
		ushort b_8000_0008_ax;
		struct {
			ubyte phys_bits;	// EAX[7 :0]
			ubyte line_bits;	// EAX[15:8]
		}
	}
			

	//
	// Debugging
	//

	/// Debugging features$(BR)
	/// Bit 0: MCA$(BR)
	/// Bit 1: MCE$(BR)
	/// Bit 2: DE (Debugging Extensions)$(BR)
	/// Bit 3: DS (Debug Store)$(BR)
	/// Bit 4: DS-CPL (Debug Store CPL branching)$(BR)
	/// Bit 5: DTES64 (64-bit DS area)$(BR)
	/// Bit 6: PDCM$(BR)
	/// Bit 7: SDBG (IA32_DEBUG_INTERFACE silicon debug)$(BR)
	/// Bit 8: PBE (Pending Break Enable)$(BR)
	uint DEBUG;

	//
	// Security
	//

	/// Security patches$(BR)
	/// Bit 0: IBPB$(BR)
	/// Bit 1: IBRS$(BR)
	/// Bit 2: IBRS_ON$(BR)
	/// Bit 3: IBRS_PREF$(BR)
	/// Bit 4: STIBP$(BR)
	/// Bit 5: STIBP_ON$(BR)
	/// Bit 6: SSBD$(BR)
	/// Bit 7: L1D_FLUSH$(BR)
	/// Bit 8: MD_CLEAR$(BR)
	uint SEC;

	//
	// Misc.
	//

	/// Miscellaneous$(BR)
	/// Bit 8: PSN, serial number$(BR)
	/// Bit 9: PCID$(BR)
	/// Bit 10: xTPR$(BR)
	/// Bit 11: IA32_ARCH_CAPABILITIES$(BR)
	/// Bit 12: FSGSBASE$(BR)
	uint MISC;
}

pragma(msg, "* sizeof CPUINFO: ", CPUINFO.sizeof);
pragma(msg, "* sizeof CACHE: ", CACHEINFO.sizeof);