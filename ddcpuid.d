/*
 * ddcpuid x86 CPU Identification tool
 * Written by dd86k <dd@dax.moe>
 *
 * NOTE: printf is mainly used for two reasons. First, fputs with stdout
 *       crashes on Windows. Secondly, line buffering.
 *
 * License: MIT
 */

//TODO: Consider making a template that populates registers on-demand
// GAS reminder: asm { "asm" : output : input : clobber }

version (X86) enum PLATFORM = "x86";
else version (X86_64) enum PLATFORM = "amd64";
else static assert(0, "ddcpuid is only supported on x86 platforms");

private:
@system:
extern (C):
__gshared:

enum VERSION = "0.18.0"; /// Program version

int strcmp(scope const char*, scope const char*);
int puts(scope const char*);
int putchar(int);
long strtol(scope inout(char)*, scope inout(char)**, int);

static if (__VERSION__ >= 2092) {
	pragma(printf)
	int printf(scope const char*, ...);
} else {
	int printf(scope const char*, ...);
}

/// Make a bit mask of one bit at n position
template BIT(int n) if (n <= 31) { enum uint BIT = 1 << n; }

/// Vendor ID template
template ID(char[4] c) {
	enum ID = c[0] | c[1] << 8 | c[2] << 16 | c[3] << 24;
}

/// Compiler version template
template CVER(int v) {
	enum CVER =
		cast(char)((v / 1000) + '0') ~
		"." ~
		cast(char)(((v % 1000) / 100) + '0') ~
		cast(char)(((v % 100) / 10) + '0') ~
		cast(char)((v % 10) + '0');
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
	// bit 0, Self Initializing cache
	// bit 1, Fully Associative cache
	// bit 2, No Write-Back Invalidation (toggle)
	// bit 3, Cache Inclusiveness (toggle)
	// bit 4, Complex Cache Indexing (toggle)
	ushort feat;
	ubyte type; // data=1, instructions=2, unified=3
	ubyte level; // L1, L2, etc.
}

struct CPUINFO { align(1):
	//
	// Leaf information
	//
	
	uint max_leaf;	/// Highest cpuid leaf
	uint max_virt_leaf;	/// Highest cpuid virtualization leaf
	uint max_ext_leaf;	/// Highest cpuid extended leaf
	
	//
	// Strings
	//
	
	union { align(1):
		char[12] vendor;	/// Vendor String
		uint vendor_id;	/// Vendor "ID"
		uint[3] vendor32;	/// Vendor 32-bit parts
	}
	char[48] brand;	/// Processor Brand String
	
	//
	// Identifier
	//

	ubyte family;	/// 
	ubyte base_family;	/// 
	ubyte ext_family;	/// 
	ubyte model;	/// 
	ubyte base_model;	/// 
	ubyte ext_model;	/// 
	ubyte stepping;	/// 
	ubyte type;	/// processor type
	
	//
	// Extensions
	//
	
	//TODO: Consider bit flags for families like mmx, 3dnow, sse
	bool fpu;	/// x87 FPU
	bool f16c;	/// Float16 Conversions
	bool mmx;	/// MMX
	bool mmxext;	/// MMX Extended
	bool _3dnow;	/// 3DNow!
	bool _3dnowext;	/// 3DNow! Extended
	bool aes_ni;	/// AES-NI
	bool sha;	/// SHA1
	bool fma3;	/// FMA3
	bool fma4;	/// FMA4
	bool bmi1;	/// BMI1
	bool bmi2;	/// BMI2
	bool x86_64;	/// Long mode
	bool lahf64;	/// LAHF/SAHF in 64-bit mode
	bool waitpkg;	/// WAITPKG
	bool xop;	/// XOP
	bool tbm;	/// TBM
	bool adx;	/// ADX
	
	// SSE
	
	bool sse;	/// SSE
	bool sse2;	/// SSE2
	bool sse3;	/// SSE3
	bool ssse3;	/// SSSE3
	bool sse41;	/// SSE4.1
	bool sse42;	/// SSE4.2
	bool sse4a;	/// SSE4a
	
	// AVX
	
	bool avx;	/// AVX
	bool avx2;	/// AVX-2
	bool avx512f;	/// AVX-512
	bool avx512er;	/// AVX-512-ER
	bool avx512pf;	/// AVX-512-PF
	bool avx512cd;	/// AVX-512-CD
	bool avx512dq;	/// AVX-512-DQ
	bool avx512bw;	/// AVX-512-BW
	bool avx512vl;	/// AVX-512-VL
	bool avx512_ifma;	/// AVX-512-IFMA
	bool avx512_vbmi;	/// AVX-512-VBMI
	bool avx512_vbmi2;	/// AVX-512-VBMI2
	bool avx512_gfni;	/// AVX-512-GFNI
	bool avx512_vaes;	/// AVX-512-VAES
	bool avx512_vnni;	/// AVX-512-VNNI
	bool avx512_bitalg;	/// AVX-512-BITALG
	bool avx512_vpopcntdq;	/// AVX-512-VPOPCNTDQ
	bool avx512_4vnniw;	/// AVX-512-4VNNIW
	bool avx512_4fmaps;	/// AVX-512-4FMAPS
	bool avx512_bf16;	/// AVX-512-BF16
	bool avx512_vp2intersect;	/// AVX-512-VP2INTERSECT
	
	// AMX
	
	bool amx;	/// AMX
	bool amx_bf16;	/// AMX-BF16
	bool amx_int8;	/// AMX-INT8
	bool amx_xtilecfg;	/// AMX-XTILECFG
	bool amx_xtiledata;	/// AMX-XTILEDATA
	bool amx_xfd;	/// AMX-XFD
	
	//
	// Extra instructions
	//
	
	bool monitor;	/// MONITOR+MWAIT
	bool pclmulqdq;	/// PCLMULQDQ
	bool cmpxchg8b;	/// CMPXCHG8B
	bool cmpxchg16b;	/// CMPXCHG16B
	bool movbe;	/// MOVBE
	bool rdrand;	/// RDRAND
	bool rdseed;	/// RDSEED
	bool rdmsr;	/// RDMSR
	bool sysenter;	/// SYSENTER+SYSEXIT
	bool rdtsc;	/// RDTSC
	bool rdtsc_deadline;	/// TSC_DEADLINE
	bool rdtsc_invariant;	/// TSC_INVARIANT
	bool rdtscp;	/// RDTSCP
	bool rdpid;	/// RDPID
	bool cmov;	/// CMOVcc
	bool lzcnt;	/// LZCNT
	bool popcnt;	/// POPCNT
	bool xsave;	/// XSAVE+XRSTOR
	bool osxsave;	/// OSXSAVE+XGETBV
	bool fxsr;	/// FXSAVE+FXRSTOR
	bool pconfig;	/// PCONFIG
	bool cldemote;	/// CLDEMOTE
	bool movdiri;	/// MOVDIRI
	bool movdir64b;	/// MOVDIR64B
	bool enqcmd;	/// ENQCMD
	bool syscall;	/// SYSCALL+SYSRET
	bool monitorx;	/// MONITORX+MWAITX
	bool skinit;	/// SKINIT
	bool clflushopt;	/// CLFLUSHOPT
	bool serialize;	/// SERIALIZE
	
	//
	// Technologies
	//
	
	bool eist;	/// Intel SpeedStep/AMD PowerNow/AMD Cool'n'Quiet
	bool turboboost;	/// Intel TurboBoost/AMD CorePerformanceBoost
	bool turboboost30;	/// Intel TurboBoost 3.0
	bool smx;	/// Intel SMX
	bool sgx;	/// Intel SGX
	bool htt;	/// HyperThreading
	
	//
	// Cache
	//
	
	CACHEINFO [6]cache;	/// Cache information
	bool clflush;	/// CLFLUSH size
	bool cnxt_id;	/// L1 Context ID
	bool ss;	/// SelfSnoop
	bool prefetchw;	/// PREFETCHW
	bool invpcid;	/// INVPCID
	bool wbnoinvd;	/// WBNOINVD

	
	//
	// ACPI
	//
	
	bool acpi;	/// ACPI
	bool apic;	/// APIC
	bool x2apic;	/// x2APIC
	bool arat;	/// Always-Running-APIC-Timer
	bool tm;	/// Thermal Monitor
	bool tm2;	/// Thermal Monitor 2
	union { // 01h.EBX internal
		uint b_01_ebx;
		struct {
			ubyte brand_index;
			ubyte clflush_linesize;
			ubyte max_apic_id;
			ubyte apic_id;
		}
	}
	ushort mwait_min;	/// MWAIT minimum size
	ushort mwait_max;	/// MWAIT maximum size
	
	//
	// Virtualization
	//
	
	bool virt;	/// VT-x/AMD-V
	ubyte virt_version;	/// (AMD) Virtualization platform version
	bool vme;	/// vm8086 enhanced
	
	union {
		char[12] virt_vendor;	/// Paravirtualization vendor
		uint virt_vendor_id;
		uint[3] virt_vendor32;
	}
	
	// VBox
	
	uint vbox_tsc_freq_khz;	/// TSC KHz frequency
	uint vbox_apic_freq_khz;	/// API KHz frequency
	ushort vbox_guest_vendor_id;	/// VBox Guest Vendor ID
	ushort vbox_guest_build;	/// VBox Guest Build number
	ubyte vbox_guest_os;	/// VBox Guest OS ID
	ubyte vbox_guest_major;	/// VBox Guest OS Major version
	ubyte vbox_guest_minor;	/// VBox Guest OS Minor version
	ubyte vbox_guest_service;	/// VBox Guest Service ID
	bool vbox_guest_opensource;	/// If set: VBox guest additions open-source
	
	// KVM
	
	bool kvm_feature_clocksource;
	bool kvm_feature_nop_io_delay;
	bool kvm_feature_mmu_op;
	bool kvm_feature_clocksource2;
	bool kvm_feature_async_pf;
	bool kvm_feature_steal_time;
	bool kvm_feature_pv_eoi;
	bool kvm_feature_pv_unhault;
	bool kvm_feature_pv_tlb_flush;
	bool kvm_feature_async_pf_vmexit;
	bool kvm_feature_pv_send_ipi;
	bool kvm_feature_pv_poll_control;
	bool kvm_feature_pv_sched_yield;
	bool kvm_feature_clocsource_stable_bit;
	bool kvm_hints_realtime;
	
	// Hyper-V
	
	bool hv_base_feat_vp_runtime_msr;	/// 
	bool hv_base_feat_part_time_ref_count_msr;	/// 
	bool hv_base_feat_basic_synic_msrs;	/// 
	bool hv_base_feat_stimer_msrs;	/// 
	bool hv_base_feat_apic_access_msrs;	/// 
	bool hv_base_feat_hypercall_msrs;	/// 
	bool hv_base_feat_vp_id_msr;	/// 
	bool hv_base_feat_virt_sys_reset_msr;	/// 
	bool hv_base_feat_stat_pages_msr;	/// 
	bool hv_base_feat_part_ref_tsc_msr;	/// 
	bool hv_base_feat_guest_idle_state_msr;	/// 
	bool hv_base_feat_timer_freq_msrs;	/// 
	bool hv_base_feat_debug_msrs;	/// 
	bool hv_part_flags_create_part;	/// 
	bool hv_part_flags_access_part_id;	/// 
	bool hv_part_flags_access_memory_pool;	/// 
	bool hv_part_flags_adjust_msg_buffers;	/// 
	bool hv_part_flags_post_msgs;	/// 
	bool hv_part_flags_signal_events;	/// 
	bool hv_part_flags_create_port;	/// 
	bool hv_part_flags_connect_port;	/// 
	bool hv_part_flags_access_stats;	/// 
	bool hv_part_flags_debugging;	/// 
	bool hv_part_flags_cpu_mgmt;	/// 
	bool hv_part_flags_cpu_profiler;	/// 
	bool hv_part_flags_expanded_stack_walk;	/// 
	bool hv_part_flags_access_vsm;	/// 
	bool hv_part_flags_access_vp_regs;	/// 
	bool hv_part_flags_extended_hypercalls;	/// 
	bool hv_part_flags_start_vp;	/// 
	bool hv_pm_max_cpu_power_state_c0;	/// 
	bool hv_pm_max_cpu_power_state_c1;	/// 
	bool hv_pm_max_cpu_power_state_c2;	/// 
	bool hv_pm_max_cpu_power_state_c3;	/// 
	bool hv_pm_hpet_reqd_for_c3;	/// 
	bool hv_misc_feat_mwait;	/// 
	bool hv_misc_feat_guest_debugging;	/// 
	bool hv_misc_feat_perf_mon;	/// 
	bool hv_misc_feat_pcpu_dyn_part_event;	/// 
	bool hv_misc_feat_xmm_hypercall_input;	/// 
	bool hv_misc_feat_guest_idle_state;	/// 
	bool hv_misc_feat_hypervisor_sleep_state;	/// 
	bool hv_misc_feat_query_numa_distance;	/// 
	bool hv_misc_feat_timer_freq;	/// 
	bool hv_misc_feat_inject_synmc_xcpt;	/// 
	bool hv_misc_feat_guest_crash_msrs;	/// 
	bool hv_misc_feat_debug_msrs;	/// 
	bool hv_misc_feat_npiep1;	/// 
	bool hv_misc_feat_disable_hypervisor;	/// 
	bool hv_misc_feat_ext_gva_range_for_flush_va_list;	/// 
	bool hv_misc_feat_hypercall_output_xmm;	/// 
	bool hv_misc_feat_sint_polling_mode;	/// 
	bool hv_misc_feat_hypercall_msr_lock;	/// 
	bool hv_misc_feat_use_direct_synth_msrs;	/// 
	bool hv_hint_hypercall_for_process_switch;	/// 
	bool hv_hint_hypercall_for_tlb_flush;	/// 
	bool hv_hint_hypercall_for_tlb_shootdown;	/// 
	bool hv_hint_msr_for_apic_access;	/// 
	bool hv_hint_msr_for_sys_reset;	/// 
	bool hv_hint_relax_time_checks;	/// 
	bool hv_hint_dma_remapping;	/// 
	bool hv_hint_interrupt_remapping;	/// 
	bool hv_hint_x2apic_msrs;	/// 
	bool hv_hint_deprecate_auto_eoi;	/// 
	bool hv_hint_synth_cluster_ipi_hypercall;	/// 
	bool hv_hint_ex_proc_masks_interface;	/// 
	bool hv_hint_nested_hyperv;	/// 
	bool hv_hint_int_for_mbec_syscalls;	/// 
	bool hv_hint_nested_enlightened_vmcs_interface;	/// 
	bool hv_host_feat_avic;	/// 
	bool hv_host_feat_msr_bitmap;	/// 
	bool hv_host_feat_perf_counter;	/// 
	bool hv_host_feat_nested_paging;	/// 
	bool hv_host_feat_dma_remapping;	/// 
	bool hv_host_feat_interrupt_remapping;	/// 
	bool hv_host_feat_mem_patrol_scrubber;	/// 
	bool hv_host_feat_dma_prot_in_use;	/// 
	bool hv_host_feat_hpet_requested;	/// 
	bool hv_host_feat_stimer_volatile;	/// 
	
	// Memory
	
	bool pae;	/// PAE
	bool pse;	/// PSE
	bool pse_36;	/// PSE-36
	bool page1gb;	/// 1GiB pages
	bool mtrr;	/// MTRR
	bool pat;	/// PAT
	bool pge;	/// PGE
	bool dca;	/// DCA
	bool nx;	/// Intel XD/NX bit
	bool hle;	/// (TSX) HLE
	bool rtm;	/// (TSX) RTM
	bool smep;	/// SMEP
	bool smap;	/// SMAP
	bool pku;	/// PKG
	bool _5pl;	/// 5-level paging
	bool fsrepmov;	/// FSREPMOV optimization
	bool tsxldtrk;	/// (TSX) TSKLDTRK
	bool lam;	/// LAM
	union {
		ushort b_8000_0008_ax;
		struct {
			ubyte phys_bits;	/// Memory physical bits
			ubyte line_bits;	/// Memory linear bits
		}
	}
	
	// Debugging
	
	bool mca;	/// Machine Check Architecture
	bool mce;	/// MCE
	bool de;	/// DE
	bool ds;	/// DS
	bool ds_cpl;	/// DS-CPL
	bool dtes64;	/// DTES64
	bool pdcm;	/// PDCM
	bool sdbg;	/// SDBG
	bool pbe;	/// PBE
	
	// Security
	
	bool ibpb;	/// IPRB
	bool ibrs;	/// IBRS
	bool ibrs_on;	/// IBRS_ON
	bool ibrs_pref;	/// IBRS_PREF
	bool stibp;	/// STIBP
	bool stibp_on;	/// STIBP_ON
	bool ssbd;	/// SSBD
	bool l1d_flush;	/// L1D_FLUSH
	bool md_clear;	/// MD_CLEAR
	bool cet_ibt;	/// CET_IBT
	bool cet_ss;	/// CET_SS
	
	// Misc.
	
	bool psn;	/// Processor Serial Number (Pentium III only)
	bool pcid;	/// PCID
	bool xtpr;	/// xTPR
	bool ia32_arch_capabilities;	/// IA32_ARCH_CAPABILITIES MSR
	bool fsgsbase;	/// FS and GS register base
	bool uintr;	/// User Interrupts
	
	align(8) private ubyte marker;
}

enum : uint {
	MAX_LEAF	= 0x20, /// Maximum leaf override
	MAX_VLEAF	= 0x4000_0010, /// Maximum virt leaf override
	MAX_ELEAF	= 0x8000_0020, /// Maximum extended leaf override
}

// Self-made vendor "IDs" for faster look-ups, LSB-based.
enum : uint {
	VENDOR_OTHER = 0,	/// Other/unknown
	VENDOR_INTEL = ID!("Genu"),	/// Intel: "Genu", 0x756e6547
	VENDOR_AMD   = ID!("Auth"),	/// AMD: "Auth", 0x68747541
	VENDOR_VIA   = ID!("VIA "),	/// VIA: "VIA ", 0x20414956
	VIRT_VENDOR_KVM      = ID!("KVMK"), /// KVM: "KVMK", 0x4b4d564b
	VIRT_VENDOR_VBOX_HV  = ID!("VBox"), /// VirtualBox: "VBox"/Hyper-V interface, 0x786f4256
	VIRT_VENDOR_VBOX_MIN = 0, /// VirtualBox: Minimal interface (zero)
}

immutable char[] CACHE_TYPE = [ '?', 'D', 'I', 'U', '?', '?', '?', '?' ];

const(char)*[] PROCESSOR_TYPE = [ "Original", "OverDrive", "Dual", "Reserved" ];

/// print help page
void clih() {
	puts(
	"x86/AMD64 CPUID information tool\n"~
	"  Usage: ddcpuid [OPTIONS...]\n"~
	"\n"~
	"OPTIONS\n"~
	"  -r    Show raw CPUID data in a table\n"~
	"  -s    Set subleaf (ECX) input value with -r\n"~
	"  -o    Override leaves to 20h, 4000_0010h, and 8000_0020h\n"~
	"\n"~
	"  --version    Print version screen and quit\n"~
	"  --ver        Print version and quit\n"~
	"  -h, --help   Print this help screen and quit"
	);
}

/// print version page
void cliv() {
	puts(
	"ddcpuid-"~PLATFORM~" v"~VERSION~" ("~__TIMESTAMP__~")\n"~
	"Copyright (c) dd86k 2016-2021\n"~
	"License: MIT License <http://opensource.org/licenses/MIT>\n"~
	"Project page: <https://github.com/dd86k/ddcpuid>\n"~
	"Compiler: "~ __VENDOR__ ~" v"~CVER!(__VERSION__)
	);
}

/// Print cpuid info
void printc(uint leaf, uint sub) {
	uint a = void, b = void, c = void, d = void;
	version (GNU) asm {
		"cpuid\n"
		: "=a" (a), "=b" (b), "=c" (c), "=d" (d)
		: "a" (leaf), "c" (sub);
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
			if (strcmp(a, "ver") == 0) {
				puts(VERSION); return 0;
			}
			printf("Unknown parameter: '%s'\n", argv[argi]);
			return 1;
		} else if (argv[argi][0] == '-') { // Short arguments
			char* a = argv[argi] + 1;
			char o = void;
			while ((o = *a) != 0) {
				++a;
				switch (o) {
				case 'o': opt_override = true; continue;
				case 'r': opt_raw = true; continue;
				case 's':
					opt_subleaf = cast(uint)strtol(argv[argi + 1], null, 10);
					continue;
				case 'h': clih; return 0;
				default:
					printf("Unknown parameter: '-%c'\n", o);
					return 1;
				}
			}
		} // else if
	} // for

	CPUINFO info = void;
	reset(&info);

	if (opt_override) {
		info.max_leaf = MAX_LEAF;
		info.max_virt_leaf = MAX_VLEAF;
		info.max_ext_leaf = MAX_ELEAF;
	} else
		getLeaves(info);
	
	if (opt_raw) { // -r
		puts(
		"| Leaf     | Sub-leaf | EAX      | EBX      | ECX      | EDX      |\n"~
		"|----------|----------|----------|----------|----------|----------|"
		);
		
		// Normal
		uint l = void, s = void;
		for (l = 0; l <= info.max_leaf; ++l) {
			s = 0;
			do { printc(l, s); } while (++s <= opt_subleaf);
		}
		
		// Paravirtualization
		if (info.max_virt_leaf > 0x4000_0000)
		for (l = 0x4000_0000; l <= info.max_virt_leaf; ++l) {
			s = 0;
			do { printc(l, s); } while (++s <= opt_subleaf);
		}
		
		// Extended
		for (l = 0x8000_0000; l <= info.max_ext_leaf; ++l) {
			s = 0;
			do { printc(l, s); } while (++s <= opt_subleaf);
		}
		return 0;
	}
	
	getInfo(info);

	char* cstring = info.brand.ptr;

	switch (info.vendor_id) {
	case VENDOR_INTEL: // Common in Intel processor brand strings
		while (*cstring == ' ') ++cstring; // left trim cpu string
		break;
	default:
	}

	//
	// ANCHOR Processor basic information
	//

	printf(
	"Vendor      : %.12s\n"~
	"String      : %.48s\n"~
	"Identifier  : Family %u (%Xh) [%Xh:%Xh] Model %u (%Xh) [%Xh:%Xh] Stepping %u\n"~
	"Extensions  :",
	cast(char*)info.vendor, cstring,
	info.family, info.family, info.base_family, info.ext_family,
	info.model, info.model, info.base_model, info.ext_model,
	info.stepping
	);

	if (info.fpu) {
		printf(" x87/FPU");
		if (info.f16c) printf(" +F16C");
	}
	if (info.mmx) {
		printf(" MMX");
		if (info.mmxext) printf(" ExtMMX");
	}
	if (info._3dnow) {
		printf(" 3DNow!");
		if (info._3dnowext) printf(" Ext3DNow!");
	}
	if (info.sse) {
		printf(" SSE");
		if (info.sse2) printf(" SSE2");
		if (info.sse3) printf(" SSE3");
		if (info.ssse3) printf(" SSSE3");
		if (info.sse41) printf(" SSE4.1");
		if (info.sse42) printf(" SSE4.2");
		if (info.sse4a) printf(" SSE4a");
		if (info.xop) printf(" XOP");
	}
	if (info.x86_64) {
		switch (info.vendor_id) {
		case VENDOR_INTEL: printf(" Intel64/x86-64"); break;
		case VENDOR_AMD: printf(" AMD64/x86-64"); break;
		default: printf(" x86-64");
		}
		if (info.lahf64)
			printf(" +LAHF64");
	}
	if (info.virt)
		switch (info.vendor_id) {
		case VENDOR_INTEL: printf(" VT-x/VMX"); break;
		case VENDOR_AMD: // SVM
			printf(" AMD-V/VMX");
			if (info.virt_version)
				printf(":v%u", info.virt_version);
			break;
		case VENDOR_VIA: printf(" VIA-VT/VMX"); break;
		default: printf(" VMX");
		}
	if (info.smx) printf(" Intel-TXT/SMX");
	if (info.aes_ni) printf(" AES-NI");
	if (info.avx) printf(" AVX");
	if (info.avx2) printf(" AVX2");
	if (info.avx512f) {
		printf(" AVX512F");
		if (info.avx512er) printf(" AVX512ER");
		if (info.avx512pf) printf(" AVX512PF");
		if (info.avx512cd) printf(" AVX512CD");
		if (info.avx512dq) printf(" AVX512DQ");
		if (info.avx512bw) printf(" AVX512BW");
		if (info.avx512vl) printf(" AVX512VL");
		if (info.avx512_ifma) printf(" AVX512_IFMA");
		if (info.avx512_vbmi) printf(" AVX512_VBMI");
		if (info.avx512_4vnniw) printf(" AVX512_4VNNIW");
		if (info.avx512_4fmaps) printf(" AVX512_4FMAPS");
		if (info.avx512_vbmi2) printf(" AVX512_VBMI2");
		if (info.avx512_gfni) printf(" AVX512_GFNI");
		if (info.avx512_vaes) printf(" AVX512_VAES");
		if (info.avx512_vnni) printf(" AVX512_VNNI");
		if (info.avx512_bitalg) printf(" AVX512_BITALG");
		if (info.avx512_bf16) printf(" AVX512_BF16");
		if (info.avx512_vp2intersect) printf(" AVX512_VP2INTERSECT");
	}
	if (info.adx) printf(" ADX");
	if (info.sha) printf(" SHA");
	if (info.fma3) printf(" FMA3");
	if (info.fma4) printf(" FMA4");
	if (info.tbm) printf(" TBM");
	if (info.bmi1) printf(" BMI1");
	if (info.bmi2) printf(" BMI2");
	if (info.waitpkg) printf(" WAITPKG");
	if (info.amx) printf(" AMX");
	if (info.amx_bf16) printf(" +BF16");
	if (info.amx_int8) printf(" +INT8");
	if (info.amx_xtilecfg) printf(" +XTILECFG");
	if (info.amx_xtiledata) printf(" +XTILEDATA");
	if (info.amx_xfd) printf(" +XFD");

	//
	// ANCHOR Extra/lone instructions
	//

	printf("\nExtra       :");
	if (info.monitor) {
		printf(" MONITOR+MWAIT");
		if (info.mwait_min)
			printf(" +MIN=%u +MAX=%u", info.mwait_min, info.mwait_max);
		if (info.monitorx) printf(" MONITORX+MWAITX");
	}
	if (info.pclmulqdq) printf(" PCLMULQDQ");
	if (info.cmpxchg8b) printf(" CMPXCHG8B");
	if (info.cmpxchg16b) printf(" CMPXCHG16B");
	if (info.movbe) printf(" MOVBE");
	if (info.rdrand) printf(" RDRAND");
	if (info.rdseed) printf(" RDSEED");
	if (info.rdmsr) printf(" RDMSR+WRMSR");
	if (info.sysenter) printf(" SYSENTER+SYSEXIT");
	if (info.syscall) printf(" SYSCALL+SYSRET");
	if (info.rdtsc) {
		printf(" RDTSC");
		if (info.rdtsc_deadline)
			printf(" +TSC-Deadline");
		if (info.rdtsc_invariant)
			printf(" +TSC-Invariant");
	}
	if (info.rdtscp) printf(" RDTSCP");
	if (info.rdpid) printf(" RDPID");
	if (info.cmov) {
		printf(" CMOV");
		if (info.fpu) printf(" FCOMI+FCMOV");
	}
	if (info.lzcnt) printf(" LZCNT");
	if (info.popcnt) printf(" POPCNT");
	if (info.xsave) printf(" XSAVE+XRSTOR");
	if (info.osxsave) printf(" XSETBV+XGETBV");
	if (info.fxsr) printf(" FXSAVE+FXRSTOR");
	if (info.pconfig) printf(" PCONFIG");
	if (info.cldemote) printf(" CLDEMOTE");
	if (info.movdiri) printf(" MOVDIRI");
	if (info.movdir64b) printf(" MOVDIR64B");
	if (info.enqcmd) printf(" ENQCMD");
	if (info.skinit) printf(" SKINIT+STGI");
	if (info.serialize) printf(" SERIALIZE");
	
	//
	// ANCHOR Vendor specific technologies
	//
	
	printf("\nTechnologies:");
	
	switch (info.vendor_id) {
	case VENDOR_INTEL:
		if (info.eist) printf(" EIST");
		if (info.turboboost)
			printf(info.turboboost30 ?
				" TurboBoot-3.0" : " TurboBoost");
		if (info.hle || info.rtm) {
			printf(" TSX");
			if (info.hle)
				printf(" +HLE");
			if (info.rtm)
				printf(" +RTM");
			if (info.tsxldtrk)
				printf(" +TSXLDTRK");
		}
		if (info.smx) printf(" TXT/SMX");
		if (info.sgx) printf(" SGX");
		break;
	case VENDOR_AMD:
		if (info.turboboost) printf(" Core-Performance-Boost");
		break;
	default:
	}
	if (info.htt) printf(" HTT");

	//
	// ANCHOR Cache information
	//

	printf("\nCache       :");
	if (info.clflush)
		printf(" CLFLUSH=%uB", info.clflush_linesize << 3);
	if (info.clflushopt) printf(" CLFLUSHOPT");
	if (info.cnxt_id) printf(" CNXT_ID");
	if (info.ss) printf(" SS");
	if (info.prefetchw) printf(" PREFETCHW");
	if (info.invpcid) printf(" INVPCID");
	if (info.wbnoinvd) printf(" WBNOINVD");

	CACHEINFO *ca = cast(CACHEINFO*)info.cache; /// Caches

	while (ca.type) {
		char c = 'K';
		if (ca.size >= 1024) {
			ca.size >>= 10;
			c = 'M';
		}
		printf("\n\tL%u-%c: %u %ciB\t%u ways, %u parts, %u B, %u sets",
			ca.level, CACHE_TYPE[ca.type], ca.size, c,
			ca.ways, ca.partitions, ca.linesize, ca.sets
		);
		if (ca.feat & BIT!(0)) printf(" +SI"); // Self Initiative
		if (ca.feat & BIT!(1)) printf(" +FA"); // Fully Associative
		if (ca.feat & BIT!(2)) printf(" +NWBV"); // No Write-Back Validation
		if (ca.feat & BIT!(3)) printf(" +CI"); // Cache Inclusive
		if (ca.feat & BIT!(4)) printf(" +CCI"); // Complex Cache Indexing
		++ca;
	}

	printf("\nACPI        :");
	if (info.acpi) printf(" ACPI");
	if (info.apic) printf(" APIC");
	if (info.x2apic) printf(" x2APIC");
	if (info.arat) printf(" ARAT");
	if (info.tm) printf(" TM");
	if (info.tm2) printf(" TM2");
	printf(" APIC-ID=%u", info.apic_id);
	if (info.max_apic_id) printf(" MAX-ID=%u", info.max_apic_id);

	printf("\nVirtual     :");
	if (info.vme) printf(" VME");
	if (info.max_virt_leaf > 0x4000_0000) {
		if (info.virt_vendor_id)
			printf(" HOST=%.12s", cast(char*)info.virt_vendor);
		switch (info.virt_vendor_id) {
		case VIRT_VENDOR_VBOX_MIN: // VBox Minimal Paravirt
			if (info.vbox_tsc_freq_khz)
				printf(" TSC_FREQ_KHZ=%u", info.vbox_tsc_freq_khz);
			if (info.vbox_apic_freq_khz)
				printf(" APIC_FREQ_KHZ=%u", info.vbox_apic_freq_khz);
			break;
		case VIRT_VENDOR_VBOX_HV: // Hyper-V
			printf(" OPENSOURCE=%d VENDOR_ID=%d OS=%d MAJOR=%d MINOR=%d SERVICE=%d BUILD=%d",
				info.vbox_guest_opensource,
				info.vbox_guest_vendor_id,
				info.vbox_guest_os,
				info.vbox_guest_major,
				info.vbox_guest_minor,
				info.vbox_guest_service,
				info.vbox_guest_build);
			if (info.hv_base_feat_vp_runtime_msr) printf(" HV_BASE_FEAT_VP_RUNTIME_MSR");
			if (info.hv_base_feat_part_time_ref_count_msr) printf(" HV_BASE_FEAT_PART_TIME_REF_COUNT_MSR");
			if (info.hv_base_feat_basic_synic_msrs) printf(" HV_BASE_FEAT_BASIC_SYNIC_MSRS");
			if (info.hv_base_feat_stimer_msrs) printf(" HV_BASE_FEAT_STIMER_MSRS");
			if (info.hv_base_feat_apic_access_msrs) printf(" HV_BASE_FEAT_APIC_ACCESS_MSRS");
			if (info.hv_base_feat_hypercall_msrs) printf(" HV_BASE_FEAT_HYPERCALL_MSRS");
			if (info.hv_base_feat_vp_id_msr) printf(" HV_BASE_FEAT_VP_ID_MSR");
			if (info.hv_base_feat_virt_sys_reset_msr) printf(" HV_BASE_FEAT_VIRT_SYS_RESET_MSR");
			if (info.hv_base_feat_stat_pages_msr) printf(" HV_BASE_FEAT_STAT_PAGES_MSR");
			if (info.hv_base_feat_part_ref_tsc_msr) printf(" HV_BASE_FEAT_PART_REF_TSC_MSR");
			if (info.hv_base_feat_guest_idle_state_msr) printf(" HV_BASE_FEAT_GUEST_IDLE_STATE_MSR");
			if (info.hv_base_feat_timer_freq_msrs) printf(" HV_BASE_FEAT_TIMER_FREQ_MSRS");
			if (info.hv_base_feat_debug_msrs) printf(" HV_BASE_FEAT_DEBUG_MSRS");
			if (info.hv_part_flags_create_part) printf(" HV_PART_FLAGS_CREATE_PART");
			if (info.hv_part_flags_access_part_id) printf(" HV_PART_FLAGS_ACCESS_PART_ID");
			if (info.hv_part_flags_access_memory_pool) printf(" HV_PART_FLAGS_ACCESS_MEMORY_POOL");
			if (info.hv_part_flags_adjust_msg_buffers) printf(" HV_PART_FLAGS_ADJUST_MSG_BUFFERS");
			if (info.hv_part_flags_post_msgs) printf(" HV_PART_FLAGS_POST_MSGS");
			if (info.hv_part_flags_signal_events) printf(" HV_PART_FLAGS_SIGNAL_EVENTS");
			if (info.hv_part_flags_create_port) printf(" HV_PART_FLAGS_CREATE_PORT");
			if (info.hv_part_flags_connect_port) printf(" HV_PART_FLAGS_CONNECT_PORT");
			if (info.hv_part_flags_access_stats) printf(" HV_PART_FLAGS_ACCESS_STATS");
			if (info.hv_part_flags_debugging) printf(" HV_PART_FLAGS_DEBUGGING");
			if (info.hv_part_flags_cpu_mgmt) printf(" HV_PART_FLAGS_CPU_MGMT");
			if (info.hv_part_flags_cpu_profiler) printf(" HV_PART_FLAGS_CPU_PROFILER");
			if (info.hv_part_flags_expanded_stack_walk) printf(" HV_PART_FLAGS_EXPANDED_STACK_WALK");
			if (info.hv_part_flags_access_vsm) printf(" HV_PART_FLAGS_ACCESS_VSM");
			if (info.hv_part_flags_access_vp_regs) printf(" HV_PART_FLAGS_ACCESS_VP_REGS");
			if (info.hv_part_flags_extended_hypercalls) printf(" HV_PART_FLAGS_EXTENDED_HYPERCALLS");
			if (info.hv_part_flags_start_vp) printf(" HV_PART_FLAGS_START_VP");
			if (info.hv_pm_max_cpu_power_state_c0) printf(" HV_PM_MAX_CPU_POWER_STATE_C0");
			if (info.hv_pm_max_cpu_power_state_c1) printf(" HV_PM_MAX_CPU_POWER_STATE_C1");
			if (info.hv_pm_max_cpu_power_state_c2) printf(" HV_PM_MAX_CPU_POWER_STATE_C2");
			if (info.hv_pm_max_cpu_power_state_c3) printf(" HV_PM_MAX_CPU_POWER_STATE_C3");
			if (info.hv_pm_hpet_reqd_for_c3) printf(" HV_PM_HPET_REQD_FOR_C3");
			if (info.hv_misc_feat_mwait) printf(" HV_MISC_FEAT_MWAIT");
			if (info.hv_misc_feat_guest_debugging) printf(" HV_MISC_FEAT_GUEST_DEBUGGING");
			if (info.hv_misc_feat_perf_mon) printf(" HV_MISC_FEAT_PERF_MON");
			if (info.hv_misc_feat_pcpu_dyn_part_event) printf(" HV_MISC_FEAT_PCPU_DYN_PART_EVENT");
			if (info.hv_misc_feat_xmm_hypercall_input) printf(" HV_MISC_FEAT_XMM_HYPERCALL_INPUT");
			if (info.hv_misc_feat_guest_idle_state) printf(" HV_MISC_FEAT_GUEST_IDLE_STATE");
			if (info.hv_misc_feat_hypervisor_sleep_state) printf(" HV_MISC_FEAT_HYPERVISOR_SLEEP_STATE");
			if (info.hv_misc_feat_query_numa_distance) printf(" HV_MISC_FEAT_QUERY_NUMA_DISTANCE");
			if (info.hv_misc_feat_timer_freq) printf(" HV_MISC_FEAT_TIMER_FREQ");
			if (info.hv_misc_feat_inject_synmc_xcpt) printf(" HV_MISC_FEAT_INJECT_SYNMC_XCPT");
			if (info.hv_misc_feat_guest_crash_msrs) printf(" HV_MISC_FEAT_GUEST_CRASH_MSRS");
			if (info.hv_misc_feat_debug_msrs) printf(" HV_MISC_FEAT_DEBUG_MSRS");
			if (info.hv_misc_feat_npiep1) printf(" HV_MISC_FEAT_NPIEP1");
			if (info.hv_misc_feat_disable_hypervisor) printf(" HV_MISC_FEAT_DISABLE_HYPERVISOR");
			if (info.hv_misc_feat_ext_gva_range_for_flush_va_list) printf(" HV_MISC_FEAT_EXT_GVA_RANGE_FOR_FLUSH_VA_LIST");
			if (info.hv_misc_feat_hypercall_output_xmm) printf(" HV_MISC_FEAT_HYPERCALL_OUTPUT_XMM");
			if (info.hv_misc_feat_sint_polling_mode) printf(" HV_MISC_FEAT_SINT_POLLING_MODE");
			if (info.hv_misc_feat_hypercall_msr_lock) printf(" HV_MISC_FEAT_HYPERCALL_MSR_LOCK");
			if (info.hv_misc_feat_use_direct_synth_msrs) printf(" HV_MISC_FEAT_USE_DIRECT_SYNTH_MSRS");
			if (info.hv_hint_hypercall_for_process_switch) printf(" HV_HINT_HYPERCALL_FOR_PROCESS_SWITCH");
			if (info.hv_hint_hypercall_for_tlb_flush) printf(" HV_HINT_HYPERCALL_FOR_TLB_FLUSH");
			if (info.hv_hint_hypercall_for_tlb_shootdown) printf(" HV_HINT_HYPERCALL_FOR_TLB_SHOOTDOWN");
			if (info.hv_hint_msr_for_apic_access) printf(" HV_HINT_MSR_FOR_APIC_ACCESS");
			if (info.hv_hint_msr_for_sys_reset) printf(" HV_HINT_MSR_FOR_SYS_RESET");
			if (info.hv_hint_relax_time_checks) printf(" HV_HINT_RELAX_TIME_CHECKS");
			if (info.hv_hint_dma_remapping) printf(" HV_HINT_DMA_REMAPPING");
			if (info.hv_hint_interrupt_remapping) printf(" HV_HINT_INTERRUPT_REMAPPING");
			if (info.hv_hint_x2apic_msrs) printf(" HV_HINT_X2APIC_MSRS");
			if (info.hv_hint_deprecate_auto_eoi) printf(" HV_HINT_DEPRECATE_AUTO_EOI");
			if (info.hv_hint_synth_cluster_ipi_hypercall) printf(" HV_HINT_SYNTH_CLUSTER_IPI_HYPERCALL");
			if (info.hv_hint_ex_proc_masks_interface) printf(" HV_HINT_EX_PROC_MASKS_INTERFACE");
			if (info.hv_hint_nested_hyperv) printf(" HV_HINT_NESTED_HYPERV");
			if (info.hv_hint_int_for_mbec_syscalls) printf(" HV_HINT_INT_FOR_MBEC_SYSCALLS");
			if (info.hv_hint_nested_enlightened_vmcs_interface) printf(" HV_HINT_NESTED_ENLIGHTENED_VMCS_INTERFACE");
			if (info.hv_host_feat_avic) printf(" HV_HOST_FEAT_AVIC");
			if (info.hv_host_feat_msr_bitmap) printf(" HV_HOST_FEAT_MSR_BITMAP");
			if (info.hv_host_feat_perf_counter) printf(" HV_HOST_FEAT_PERF_COUNTER");
			if (info.hv_host_feat_nested_paging) printf(" HV_HOST_FEAT_NESTED_PAGING");
			if (info.hv_host_feat_dma_remapping) printf(" HV_HOST_FEAT_DMA_REMAPPING");
			if (info.hv_host_feat_interrupt_remapping) printf(" HV_HOST_FEAT_INTERRUPT_REMAPPING");
			if (info.hv_host_feat_mem_patrol_scrubber) printf(" HV_HOST_FEAT_MEM_PATROL_SCRUBBER");
			if (info.hv_host_feat_dma_prot_in_use) printf(" HV_HOST_FEAT_DMA_PROT_IN_USE");
			if (info.hv_host_feat_hpet_requested) printf(" HV_HOST_FEAT_HPET_REQUESTED");
			if (info.hv_host_feat_stimer_volatile) printf(" HV_HOST_FEAT_STIMER_VOLATILE");
			break;
		case VIRT_VENDOR_KVM:
			if (info.kvm_feature_clocksource) printf(" KVM_FEATURE_CLOCKSOURCE");
			if (info.kvm_feature_nop_io_delay) printf(" KVM_FEATURE_NOP_IO_DELAY");
			if (info.kvm_feature_mmu_op) printf(" KVM_FEATURE_MMU_OP");
			if (info.kvm_feature_clocksource2) printf(" KVM_FEATURE_CLOCKSOURCE2");
			if (info.kvm_feature_async_pf) printf(" KVM_FEATURE_ASYNC_PF");
			if (info.kvm_feature_steal_time) printf(" KVM_FEATURE_STEAL_TIME");
			if (info.kvm_feature_pv_eoi) printf(" KVM_FEATURE_PV_EOI");
			if (info.kvm_feature_pv_unhault) printf(" KVM_FEATURE_PV_UNHAULT");
			if (info.kvm_feature_pv_tlb_flush) printf(" KVM_FEATURE_PV_TLB_FLUSH");
			if (info.kvm_feature_async_pf_vmexit) printf(" KVM_FEATURE_ASYNC_PF_VMEXIT");
			if (info.kvm_feature_pv_send_ipi) printf(" KVM_FEATURE_PV_SEND_IPI");
			if (info.kvm_feature_pv_poll_control) printf(" KVM_FEATURE_PV_POLL_CONTROL");
			if (info.kvm_feature_pv_sched_yield) printf(" KVM_FEATURE_PV_SCHED_YIELD");
			if (info.kvm_feature_clocsource_stable_bit) printf(" KVM_FEATURE_CLOCSOURCE_STABLE_BIT");
			if (info.kvm_hints_realtime) printf(" KVM_HINTS_REALTIME");
			break;
		default:
		}
	}

	printf("\nMemory      :");
	if (info.phys_bits) printf(" P-Bits=%u", info.phys_bits);
	if (info.line_bits) printf(" L-Bits=%u", info.line_bits);
	if (info.pae) printf(" PAE");
	if (info.pse) printf(" PSE");
	if (info.pse_36) printf(" PSE-36");
	if (info.page1gb) printf(" Page1GB");
	if (info.nx)
		switch (info.vendor_id) {
		case VENDOR_INTEL: printf(" Intel-XD/NX"); break;
		case VENDOR_AMD: printf(" AMD-EVP/NX"); break;
		default: printf(" NX");
		}
	if (info.dca) printf(" DCA");
	if (info.pat) printf(" PAT");
	if (info.mtrr) printf(" MTRR");
	if (info.pge) printf(" PGE");
	if (info.smep) printf(" SMEP");
	if (info.smap) printf(" SMAP");
	if (info.pku) printf(" PKU");
	if (info._5pl) printf(" 5PL");
	if (info.fsrepmov) printf(" FSRM");
	if (info.lam) printf(" LAM");

	printf("\nDebugging   :");
	if (info.mca) printf(" MCA");
	if (info.mce) printf(" MCE");
	if (info.de) printf(" DE");
	if (info.ds) printf(" DS");
	if (info.ds_cpl) printf(" DS-CPL");
	if (info.dtes64) printf(" DTES64");
	if (info.pdcm) printf(" PDCM");
	if (info.sdbg) printf(" SDBG");
	if (info.pbe) printf(" PBE");

	printf("\nSecurity    :");
	if (info.ibpb) printf(" IBPB");
	if (info.ibrs) printf(" IBRS");
	if (info.stibp) printf(" STIBP");
	if (info.ssbd) printf(" SSBD");

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		if (info.l1d_flush) printf(" L1D_FLUSH");
		if (info.md_clear) printf(" MD_CLEAR");
		if (info.cet_ibt) printf(" CET_IBT");
		if (info.cet_ss) printf(" CET_SS");
		break;
	case VENDOR_AMD:
		if (info.ibrs_on) printf(" IBRS_ON");
		if (info.ibrs_pref) printf(" IBRS_PREF");
		if (info.stibp_on) printf(" STIBP_ON");
		break;
	default:
	}

	printf("\nMisc.       : HLeaf=%Xh HVLeaf=%Xh HELeaf=%Xh Type=%s Index=%u",
		info.max_leaf, info.max_virt_leaf, info.max_ext_leaf,
		PROCESSOR_TYPE[info.type], info.brand_index);
	if (info.xtpr) printf(" xTPR");
	if (info.psn) printf(" PSN");
	if (info.pcid) printf(" PCID");
	if (info.ia32_arch_capabilities) printf(" IA32_ARCH_CAPABILITIES");
	if (info.fsgsbase) printf(" FSGSBASE");
	if (info.uintr) printf(" UINTR");

	putchar('\n');

	return 0;
} // main

/// Reset CPUINFO fields.
/// Params: info = CPUINFO structure
void reset(CPUINFO *info) {
	size_t left = (CPUINFO.sizeof / size_t.sizeof) - 1;
	size_t *p = cast(size_t*)info;
	for (; left > 0; --left)
		p[left] = 0;
}

/// Fetch CPU info
/// Params: info = CPUINFO structure
void getInfo(ref CPUINFO info) {
	// Position Independant Code compliant
	size_t __A = cast(size_t)&info.vendor;
	size_t __B = cast(size_t)&info.brand;

	// Get processor vendor and processor brand string
	version (X86_64) {
		version (GNU) asm {
			// vendor string
			"mov %0, %%rdi\n"~
			"mov $0, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n"~
			"mov %%edx, 4(%%rdi)\n"~
			"mov %%ecx, 8(%%rdi)\n"~
			// brand string
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
			: "m" (__A), "m" (__B);
		} else asm {
			// vendor string
			mov RDI, __A;
			mov EAX, 0;
			cpuid;
			mov [RDI], EBX;
			mov [RDI+4], EDX;
			mov [RDI+8], ECX;
			// brand string
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
			// vendor string
			"mov %0, %%edi\n"~
			"mov $0, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, disp(%%edi)\n"~
			"mov %%edx, disp(%%edi+4)\n"~
			"mov %%ecx, disp(%%edi+8)\n"~
			// brand string
			"mov %1, %%edi\n"~
			"mov $0x80000002, %%eax\n"~
			"cpuid\n"~
			"mov %%eax, disp(%%edi)\n"~
			"mov %%ebx, disp(%%edi+4)\n"~
			"mov %%ecx, disp(%%edi+8)\n"~
			"mov %%edx, disp(%%edi+12)\n"~
			"mov $0x80000003, %%eax\n"~
			"cpuid\n"~
			"mov %%eax, disp(%%edi+16)\n"~
			"mov %%ebx, disp(%%edi+20)\n"~
			"mov %%ecx, disp(%%edi+24)\n"~
			"mov %%edx, disp(%%edi+28)\n"~
			"mov $0x80000004, %%eax\n"~
			"cpuid\n"~
			"mov %%eax, disp(%%edi+32)\n"~
			"mov %%ebx, disp(%%edi+36)\n"~
			"mov %%ecx, disp(%%edi+40)\n"~
			"mov %%edx, disp(%%edi+44)"
			:
			: "m" (__A), "m" (__B);
		} else asm {
			// vendor string
			mov EDI, __A;
			mov EAX, 0;
			cpuid;
			mov [EDI], EBX;
			mov [EDI+4], EDX;
			mov [EDI+8], ECX;
			// brand string
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
	
	// Vendor string verification
	// If the rest of the string doesn't correspond, the id is unset
	switch (info.vendor_id) {
	case VENDOR_INTEL:	// "GenuineIntel"
		if (info.vendor32[1] != ID!("ineI")) goto default;
		if (info.vendor32[2] != ID!("ntel")) goto default;
		break;
	case VENDOR_AMD:	// "AuthenticAMD"
		if (info.vendor32[1] != ID!("enti")) goto default;
		if (info.vendor32[2] != ID!("cAMD")) goto default;
		break;
	case VENDOR_VIA:	// "VIA VIA VIA "
		if (info.vendor32[1] != ID!("VIA ")) goto default;
		if (info.vendor32[2] != ID!("VIA ")) goto default;
		break;
	default:
		info.vendor_id = 0;
	}
	
	//
	// Cache information
	//
	
	uint l; /// Cache level
	CACHEINFO *ca = cast(CACHEINFO*)info.cache;
	
	uint a = void, b = void, c = void, d = void; // EAX to EDX
	
	switch (info.vendor_id) { // CACHE INFORMATION
	case VENDOR_INTEL:
		version (GNU) asm {
			"mov $4, %%eax\n"~
			"mov %4, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"~
			"mov %%ebx, %1\n"~
			"mov %%ecx, %2\n"~
			"mov %%edx, %3"
			: "=a" (a), "=b" (b), "=c" (c), "=d" (d)
			: "m" (l);
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
		if (a == 0) break;
		
		ca.type = (a & 0xF);
		ca.level = cast(ubyte)((a >> 5) & 7);
		ca.linesize = cast(ubyte)((b & 0x7FF) + 1);
		ca.partitions = cast(ubyte)(((b >> 12) & 0x7FF) + 1);
		ca.ways = cast(ubyte)((b >> 22) + 1);
		ca.sets = cast(ushort)(c + 1);
		if (a & BIT!(8)) ca.feat = 1;
		if (a & BIT!(9)) ca.feat |= BIT!(1);
		if (d & BIT!(0)) ca.feat |= BIT!(2);
		if (d & BIT!(1)) ca.feat |= BIT!(3);
		if (d & BIT!(2)) ca.feat |= BIT!(4);
		ca.size = (ca.sets * ca.linesize * ca.partitions * ca.ways) >> 10;

		debug printf("| %8X | %8X | %8X | %8X | %8X |\n", l, a, b, c, d);
		++l; ++ca;
		goto case VENDOR_INTEL;
	case VENDOR_AMD:
		ubyte _amd_ways_l2 = void; // please the compiler (for further goto)

		if (info.max_ext_leaf < 0x8000_001D) {
			version (GNU) asm {
				"mov $0x80000005, %%eax\n"~
				"cpuid\n"~
				"mov %%ecx, %0\n"~
				"mov %%edx, %1"
				: "=c" (c), "=d" (d);
			} else asm {
				mov EAX, 0x8000_0005;
				cpuid;
				mov c, ECX;
				mov d, EDX;
			}
			info.cache[0].level = info.cache[1].level = 1; // L1
			info.cache[0].type = 1; // data
			info.cache[0].__bundle1 = c;
			info.cache[0].size = info.cache[0]._amdsize;
			info.cache[1].__bundle1 = d;
			info.cache[1].size = info.cache[1]._amdsize;

			if (info.max_ext_leaf < 0x8000_0006)
				break; // No L2/L3

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
				: "=c" (c), "=d" (d);
			} else asm { // AMD olde way
				mov EAX, 0x8000_0006;
				cpuid;
				mov c, ECX;
				mov d, EDX;
			}

			_amd_ways_l2 = (c >> 12) & 7;
			if (_amd_ways_l2) {
				info.cache[2].level = 2; // L2
				info.cache[2].type = 3; // unified
				info.cache[2].ways = _amd_ways(_amd_ways_l2);
				info.cache[2].size = c >> 16;
				info.cache[2].sets = (c >> 8) & 7;
				info.cache[2].linesize = cast(ubyte)c;

				ubyte _amd_ways_l3 = (d >> 12) & 0b111;
				if (_amd_ways_l3) {
					info.cache[3].level = 3; // L2
					info.cache[3].type = 3; // unified
					info.cache[3].ways = _amd_ways(_amd_ways_l3);
					info.cache[3].size = ((d >> 18) + 1) * 512;
					info.cache[3].sets = (d >> 8) & 7;
					info.cache[3].linesize = cast(ubyte)(d & 0x7F);
				}
			}
			break;
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
			: "=a" (a), "=b" (b), "=c" (c), "=d" (d)
			: "m" (l);
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
		if (a == 0) break;

		ca.type = (a & 0xF); // Same as Intel
		ca.level = cast(ubyte)((a >> 5) & 7);
		ca.linesize = cast(ubyte)((b & 0x7FF) + 1);
		ca.partitions = cast(ubyte)(((b >> 12) & 0x7FF) + 1);
		ca.ways = cast(ubyte)((b >> 22) + 1);
		ca.sets = cast(ushort)(c + 1);
		if (a & BIT!(8)) ca.feat = 1;
		if (a & BIT!(9)) ca.feat |= BIT!(1);
		if (d & BIT!(0)) ca.feat |= BIT!(2);
		if (d & BIT!(1)) ca.feat |= BIT!(3);
		ca.size = (ca.sets * ca.linesize * ca.partitions * ca.ways) >> 10;

		debug printf("| %8X | %8X | %8X | %8X | %8X |\n", l, a, b, c, d);
		++l; ++ca;
		goto CACHE_AMD_NEWER;
	default:
	}
	
	//
	// Leaf 1H
	//

	version (GNU) asm {
		"mov $1, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%ebx, %1\n"~
		"mov %%ecx, %2\n"~
		"mov %%edx, %3"
		: "=a" (a), "=b" (b), "=c" (c), "=d" (d);
	} else asm {
		mov EAX, 1;
		cpuid;
		mov a, EAX;
		mov b, EBX;
		mov c, ECX;
		mov d, EDX;
	}

	// EAX
	info.stepping    = a & 0xF;        // EAX[3:0]
	info.base_model  = a >>  4 &  0xF; // EAX[7:4]
	info.base_family = a >>  8 &  0xF; // EAX[11:8]
	info.type        = a >> 12 & 0b11; // EAX[13:12]
	info.ext_model   = a >> 16 &  0xF; // EAX[19:16]
	info.ext_family  = cast(ubyte)(a >> 20); // EAX[27:20]

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		info.family = info.base_family != 0 ?
			info.base_family :
			cast(ubyte)(info.ext_family + info.base_family);

		info.model = info.base_family == 6 || info.base_family == 0 ?
			cast(ubyte)((info.ext_model << 4) + info.base_model) :
			info.base_model; // DisplayModel = Model_ID;

		// ECX
		info.dtes64	= (c & BIT!(2)) != 0;
		info.ds_cpl	= (c & BIT!(4)) != 0;
		info.virt	= (c & BIT!(5)) != 0;
		info.smx	= (c & BIT!(6)) != 0;
		info.eist	= (c & BIT!(7)) != 0;
		info.tm2	= (c & BIT!(8)) != 0;
		info.cnxt_id	= (c & BIT!(10)) != 0;
		info.sdbg	= (c & BIT!(11)) != 0;
		info.xtpr	= (c & BIT!(14)) != 0;
		info.pdcm	= (c & BIT!(15)) != 0;
		info.pcid	= (c & BIT!(17)) != 0;
		info.mca	= (c & BIT!(18)) != 0;
		info.x2apic	= (c & BIT!(21)) != 0;
		info.rdtsc_deadline	= (c & BIT!(24)) != 0;

		// EDX
		info.psn	= (d & BIT!(18)) != 0;
		info.ds	= (d & BIT!(21)) != 0;
		info.acpi	= (d & BIT!(22)) != 0;
		info.ss	= (d & BIT!(27)) != 0;
		info.tm	= (d & BIT!(29)) != 0;
		info.pbe	= d >= BIT!(31);
		break;
	case VENDOR_AMD:
		if (info.base_family < 0xF) {
			info.family = info.base_family;
			info.model = info.base_model;
		} else {
			info.family = cast(ubyte)(info.ext_family + info.base_family);
			info.model = cast(ubyte)((info.ext_model << 4) + info.base_model);
		}
		break;
	default:
	}
	
	// EBX
	info.b_01_ebx = b; // BrandIndex, CLFLUSHLineSize, MaxIDs, InitialAPICID
	
	// ECX
	info.sse3	= (c & BIT!(0)) != 0;
	info.pclmulqdq	= (c & BIT!(1)) != 0;
	info.monitor	= (c & BIT!(3)) != 0;
	info.ssse3	= (c & BIT!(9)) != 0;
	info.fma3	= (c & BIT!(12)) != 0;
	info.cmpxchg16b	= (c & BIT!(13)) != 0;
	info.sse41	= (c & BIT!(15)) != 0;
	info.sse42	= (c & BIT!(20)) != 0;
	info.movbe	= (c & BIT!(22)) != 0;
	info.popcnt	= (c & BIT!(23)) != 0;
	info.aes_ni	= (c & BIT!(25)) != 0;
	info.xsave	= (c & BIT!(26)) != 0;
	info.osxsave	= (c & BIT!(27)) != 0;
	info.avx	= (c & BIT!(28)) != 0;
	info.f16c	= (c & BIT!(29)) != 0;
	info.rdrand	= (c & BIT!(30)) != 0;
	
	// EDX
	info.fpu	= (d & BIT!(0)) != 0;
	info.vme	= (d & BIT!(1)) != 0;
	info.de	= (d & BIT!(2)) != 0;
	info.pse	= (d & BIT!(3)) != 0;
	info.rdtsc	= (d & BIT!(4)) != 0;
	info.rdmsr	= (d & BIT!(5)) != 0;
	info.pae	= (d & BIT!(6)) != 0;
	info.mce	= (d & BIT!(7)) != 0;
	info.cmpxchg8b	= (d & BIT!(8)) != 0;
	info.apic	= (d & BIT!(9)) != 0;
	info.sysenter	= (d & BIT!(11)) != 0;
	info.mtrr	= (d & BIT!(12)) != 0;
	info.pge	= (d & BIT!(13)) != 0;
	info.mca	= (d & BIT!(14)) != 0;
	info.cmov	= (d & BIT!(15)) != 0;
	info.pat	= (d & BIT!(16)) != 0;
	info.pse_36	= (d & BIT!(17)) != 0;
	info.clflush	= (d & BIT!(19)) != 0;
	info.mmx	= (d & BIT!(23)) != 0;
	info.fxsr	= (d & BIT!(24)) != 0;
	info.sse	= (d & BIT!(25)) != 0;
	info.sse2	= (d & BIT!(26)) != 0;
	info.htt	= (d & BIT!(28)) != 0;
	
	if (info.max_leaf < 5) goto EXTENDED_LEAVES;
	
	//
	// Leaf 5H
	//
	
	version (GNU) asm {
		"mov $5, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%ebx, %1\n"
		: "=a" (a), "=b" (b);
	} else asm {
		mov EAX, 5;
		cpuid;
		mov a, EAX;
		mov b, EBX;
	}
	
	info.mwait_min = cast(ushort)a;
	info.mwait_max = cast(ushort)b;
	
	if (info.max_leaf < 6) goto EXTENDED_LEAVES;
	
	//
	// Leaf 6H
	//
	
	version (GNU) asm {
		"mov $6, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0"
		: "=a" (a);
	} else asm {
		mov EAX, 6;
		cpuid;
		mov a, EAX;
	}

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		 info.turboboost	= (a & BIT!(1)) != 0;
		info.turboboost30	= (a & BIT!(14)) != 0;
		break;
	default:
	}

	info.arat	= (a & BIT!(2)) != 0;

	if (info.max_leaf < 7) goto EXTENDED_LEAVES;
	
	//
	// Leaf 7H
	//

	version (GNU) asm {
		"mov $7, %%eax\n"~
		"mov $0, %%ecx\n"~
		"cpuid\n"~
		"mov %%ebx, %0\n"~
		"mov %%ecx, %1\n"~
		"mov %%edx, %2\n"
		: "=b" (b), "=c" (c), "=d" (d);
	} else asm {
		mov EAX, 7;
		mov ECX, 0;
		cpuid;
		mov b, EBX;
		mov c, ECX;
		mov d, EDX;
	}

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		// EBX
		info.sgx	= (b & BIT!(2)) != 0;
		info.hle	= (b & BIT!(4)) != 0;
		info.invpcid	= (b & BIT!(10)) != 0;
		info.rtm	= (b & BIT!(11)) != 0;
		info.avx512f	= (b & BIT!(16)) != 0;
		info.smap	= (b & BIT!(20)) != 0;
		info.avx512er	= (b & BIT!(27)) != 0;
		info.avx512pf	= (b & BIT!(26)) != 0;
		info.avx512cd	= (b & BIT!(28)) != 0;
		info.avx512dq	= (b & BIT!(17)) != 0;
		info.avx512bw	= (b & BIT!(30)) != 0;
		info.avx512_ifma	= (b & BIT!(21)) != 0;
		info.avx512_vbmi	= b >= BIT!(31);
		// ECX
		info.avx512vl	= (c & BIT!(1)) != 0;
		info.pku	= (c & BIT!(3)) != 0;
		info.fsrepmov	= (c & BIT!(4)) != 0;
		info.waitpkg	= (c & BIT!(5)) != 0;
		info.avx512_vbmi2	= (c & BIT!(6)) != 0;
		info.cet_ss	= (c & BIT!(7)) != 0;
		info.avx512_gfni	= (c & BIT!(8)) != 0;
		info.avx512_vaes	= (c & BIT!(9)) != 0;
		info.avx512_vnni	= (c & BIT!(11)) != 0;
		info.avx512_bitalg	= (c & BIT!(12)) != 0;
		info.avx512_vpopcntdq	= (c & BIT!(14)) != 0;
		info._5pl	= (c & BIT!(16)) != 0;
		info.cldemote	= (c & BIT!(25)) != 0;
		info.movdiri	= (c & BIT!(27)) != 0;
		info.movdir64b	= (c & BIT!(28)) != 0;
		info.enqcmd	= (c & BIT!(29)) != 0;
		// EDX
		info.avx512_4vnniw	= (d & BIT!(2)) != 0;
		info.avx512_4fmaps	= (d & BIT!(3)) != 0;
		info.uintr	= (d & BIT!(5)) != 0;
		info.avx512_vp2intersect	= (d & BIT!(8)) != 0;
		info.md_clear	= (d & BIT!(10)) != 0;
		info.serialize	= (d & BIT!(14)) != 0;
		info.tsxldtrk	= (d & BIT!(16)) != 0;
		info.pconfig	= (d & BIT!(18)) != 0;
		info.cet_ibt	= (d & BIT!(20)) != 0;
		info.amx_bf16	= (d & BIT!(22)) != 0;
		info.amx	= (d & BIT!(24)) != 0;
		info.amx_int8	= (d & BIT!(25)) != 0;
		info.ibrs = (d & BIT!(26)) != 0;
		info.stibp	= (d & BIT!(27)) != 0;
		info.l1d_flush	= (d & BIT!(28)) != 0;
		info.ia32_arch_capabilities	= (d & BIT!(29)) != 0;
		info.ssbd	= d >= BIT!(31);
		break;
	default:
	}

	// b
	info.fsgsbase	= (b & BIT!(0)) != 0;
	info.bmi1	= (b & BIT!(3)) != 0;
	info.avx2	= (b & BIT!(5)) != 0;
	info.smep	= (b & BIT!(7)) != 0;
	info.bmi2	= (b & BIT!(8)) != 0;
	info.rdseed	= (b & BIT!(18)) != 0;
	info.adx	= (b & BIT!(19)) != 0;
	info.clflushopt	= (b & BIT!(23)) != 0;
	info.sha	= (b & BIT!(29)) != 0;
	// c
	info.rdpid	= (c & BIT!(22)) != 0;
	
	//
	// Leaf 7H(ECX=01h)
	//

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		version (GNU) asm {
			"mov $7, %%eax\n"~
			"mov $1, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"
			: "=a" (a);
		} else asm {
			mov EAX, 7;
			mov ECX, 1;
			cpuid;
			mov a, EAX;
		}
		// a
		info.avx512_bf16	= (a & BIT!(5)) != 0;
		info.lam	= (a & BIT!(26)) != 0;
		break;
	default:
	}
	
	//
	// Leaf DH
	//

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		version (GNU) asm {
			"mov $0xD, %%eax\n"~
			"mov $0, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"
			: "=a" (a);
		} else asm {
			mov EAX, 0xD;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
		}
		info.amx_xtilecfg	= (a & BIT!(17)) != 0;
		info.amx_xtiledata	= (a & BIT!(18)) != 0;
		break;
	default:
	}
	
	//
	// Leaf DH(ECX=01h)
	//

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		version (GNU) asm {
			"mov $0xD, %%eax\n"~
			"mov $1, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"
			: "=a" (a);
		} else asm {
			mov EAX, 0xD;
			mov ECX, 1;
			cpuid;
			mov a, EAX;
		}
		info.amx_xfd	= (a & BIT!(18)) != 0;
		break;
	default:
	}
	
	if (info.max_virt_leaf < 0x4000_0000) goto EXTENDED_LEAVES;
	
	//
	// Leaf 4000_000H
	//

	__A = cast(size_t)&info.virt_vendor;
	version (X86_64) {
		version (GNU) asm {
			"mov %0, %%rdi\n"~
			"mov $0x40000000, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n"~
			"mov %%ecx, 4(%%rdi)\n"~
			"mov %%edx, 8(%%rdi)\n"
			: "=m" (__A);
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
			: "m" (__A);
		} else asm {
			mov EDI, __A;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [EDI], EBX;
			mov [EDI+4], ECX;
			mov [EDI+8], EDX;
		}
	}
	
	// Paravirtual vendor string verification
	// If the rest of the string doesn't correspond, the id is unset
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_KVM:	// "KVMKVMKVMKVM"
		if (info.virt_vendor32[1] != ID!("VMKV")) goto default;
		if (info.virt_vendor32[2] != ID!("MKVM")) goto default;
		break;
	case VIRT_VENDOR_VBOX_HV:	// "VBoxVBoxVBox"
		if (info.virt_vendor32[1] != ID!("VBox")) goto default;
		if (info.virt_vendor32[2] != ID!("VBox")) goto default;
		break;
	default:
		info.vendor_id = 0;
	}

	if (info.max_virt_leaf < 0x4000_0001) goto EXTENDED_LEAVES;
	
	//
	// Leaf 4000_0001H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_KVM:
		version (GNU) asm {
			"mov $0x40000001, %%eax\n"~
			"mov $0, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"~
			"mov %%edx, %1\n"
			: "=a" (a), "=d" (d);
		} else asm {
			mov EAX, 0x4000_0001;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
			mov d, EDX;
		}
		info.kvm_feature_clocksource	= (a & BIT!(0)) != 0;
		info.kvm_feature_nop_io_delay	= (a & BIT!(1)) != 0;
		info.kvm_feature_mmu_op	= (a & BIT!(2)) != 0;
		info.kvm_feature_clocksource2	= (a & BIT!(3)) != 0;
		info.kvm_feature_async_pf	= (a & BIT!(4)) != 0;
		info.kvm_feature_steal_time	= (a & BIT!(5)) != 0;
		info.kvm_feature_pv_eoi	= (a & BIT!(6)) != 0;
		info.kvm_feature_pv_unhault	= (a & BIT!(7)) != 0;
		info.kvm_feature_pv_tlb_flush	= (a & BIT!(9)) != 0;
		info.kvm_feature_async_pf_vmexit	= (a & BIT!(10)) != 0;
		info.kvm_feature_pv_send_ipi	= (a & BIT!(11)) != 0;
		info.kvm_feature_pv_poll_control	= (a & BIT!(12)) != 0;
		info.kvm_feature_pv_sched_yield	= (a & BIT!(13)) != 0;
		info.kvm_feature_clocsource_stable_bit	= (a & BIT!(24)) != 0;
		info.kvm_hints_realtime	= (d & BIT!(0)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0002) goto EXTENDED_LEAVES;
	
	//
	// Leaf 4000_002H
	//

	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		version (GNU) asm {
			"mov $0x40000002, %%eax\n"~
			"mov $0, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"~
			"mov %%edx, %1\n"
			: "=a" (a), "=d" (d);
		} else asm {
			mov EAX, 0x4000_0002;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
			mov d, EDX;
		}
		info.vbox_guest_opensource = d >= BIT!(31);
		info.vbox_guest_vendor_id = (d >> 16) & 0xFFF;
		info.vbox_guest_os = cast(ubyte)(d >> 8);
		info.vbox_guest_major = cast(ubyte)d;
		info.vbox_guest_minor = cast(ubyte)(a >> 24);
		info.vbox_guest_service = cast(ubyte)(a >> 16);
		info.vbox_guest_build = cast(ushort)a;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0003) goto EXTENDED_LEAVES;
	
	//
	// Leaf 4000_0003H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		version (GNU) asm {
			"mov $0x40000003, %%eax\n"~
			"mov $0, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"~
			"mov %%ebx, %1\n"~
			"mov %%ecx, %2\n"~
			"mov %%edx, %3\n"
			: "=a" (a), "=b" (b), "=c" (c), "=d" (d);
		} else asm {
			mov EAX, 0x4000_0003;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
			mov b, EBX;
			mov c, ECX;
			mov d, EDX;
		}
		info.hv_base_feat_vp_runtime_msr	= (a & BIT!(0)) != 0;
		info.hv_base_feat_part_time_ref_count_msr	= (a & BIT!(1)) != 0;
		info.hv_base_feat_basic_synic_msrs	= (a & BIT!(2)) != 0;
		info.hv_base_feat_stimer_msrs	= (a & BIT!(3)) != 0;
		info.hv_base_feat_apic_access_msrs	= (a & BIT!(4)) != 0;
		info.hv_base_feat_hypercall_msrs	= (a & BIT!(5)) != 0;
		info.hv_base_feat_vp_id_msr	= (a & BIT!(6)) != 0;
		info.hv_base_feat_virt_sys_reset_msr	= (a & BIT!(7)) != 0;
		info.hv_base_feat_stat_pages_msr	= (a & BIT!(8)) != 0;
		info.hv_base_feat_part_ref_tsc_msr	= (a & BIT!(9)) != 0;
		info.hv_base_feat_guest_idle_state_msr	= (a & BIT!(10)) != 0;
		info.hv_base_feat_timer_freq_msrs	= (a & BIT!(11)) != 0;
		info.hv_base_feat_debug_msrs	= (a & BIT!(12)) != 0;
		info.hv_part_flags_create_part	= (b & BIT!(0)) != 0;
		info.hv_part_flags_access_part_id	= (b & BIT!(1)) != 0;
		info.hv_part_flags_access_memory_pool	= (b & BIT!(2)) != 0;
		info.hv_part_flags_adjust_msg_buffers	= (b & BIT!(3)) != 0;
		info.hv_part_flags_post_msgs	= (b & BIT!(4)) != 0;
		info.hv_part_flags_signal_events	= (b & BIT!(5)) != 0;
		info.hv_part_flags_create_port	= (b & BIT!(6)) != 0;
		info.hv_part_flags_connect_port	= (b & BIT!(7)) != 0;
		info.hv_part_flags_access_stats	= (b & BIT!(8)) != 0;
		info.hv_part_flags_debugging	= (b & BIT!(11)) != 0;
		info.hv_part_flags_cpu_mgmt	= (b & BIT!(12)) != 0;
		info.hv_part_flags_cpu_profiler	= (b & BIT!(13)) != 0;
		info.hv_part_flags_expanded_stack_walk	= (b & BIT!(14)) != 0;
		info.hv_part_flags_access_vsm	= (b & BIT!(16)) != 0;
		info.hv_part_flags_access_vp_regs	= (b & BIT!(17)) != 0;
		info.hv_part_flags_extended_hypercalls	= (b & BIT!(20)) != 0;
		info.hv_part_flags_start_vp	= (b & BIT!(21)) != 0;
		info.hv_pm_max_cpu_power_state_c0	= (c & BIT!(0)) != 0;
		info.hv_pm_max_cpu_power_state_c1	= (c & BIT!(1)) != 0;
		info.hv_pm_max_cpu_power_state_c2	= (c & BIT!(2)) != 0;
		info.hv_pm_max_cpu_power_state_c3	= (c & BIT!(3)) != 0;
		info.hv_pm_hpet_reqd_for_c3	= (c & BIT!(4)) != 0;
		info.hv_misc_feat_mwait	= (a & BIT!(0)) != 0;
		info.hv_misc_feat_guest_debugging	= (a & BIT!(1)) != 0;
		info.hv_misc_feat_perf_mon	= (a & BIT!(2)) != 0;
		info.hv_misc_feat_pcpu_dyn_part_event	= (a & BIT!(3)) != 0;
		info.hv_misc_feat_xmm_hypercall_input	= (a & BIT!(4)) != 0;
		info.hv_misc_feat_guest_idle_state	= (a & BIT!(5)) != 0;
		info.hv_misc_feat_hypervisor_sleep_state	= (a & BIT!(6)) != 0;
		info.hv_misc_feat_query_numa_distance	= (a & BIT!(7)) != 0;
		info.hv_misc_feat_timer_freq	= (a & BIT!(8)) != 0;
		info.hv_misc_feat_inject_synmc_xcpt	= (a & BIT!(9)) != 0;
		info.hv_misc_feat_guest_crash_msrs	= (a & BIT!(10)) != 0;
		info.hv_misc_feat_debug_msrs	= (a & BIT!(11)) != 0;
		info.hv_misc_feat_npiep1	= (a & BIT!(12)) != 0;
		info.hv_misc_feat_disable_hypervisor	= (a & BIT!(13)) != 0;
		info.hv_misc_feat_ext_gva_range_for_flush_va_list	= (a & BIT!(14)) != 0;
		info.hv_misc_feat_hypercall_output_xmm	= (a & BIT!(15)) != 0;
		info.hv_misc_feat_sint_polling_mode	= (a & BIT!(17)) != 0;
		info.hv_misc_feat_hypercall_msr_lock	= (a & BIT!(18)) != 0;
		info.hv_misc_feat_use_direct_synth_msrs	= (a & BIT!(19)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0004) goto EXTENDED_LEAVES;
	
	//
	// Leaf 4000_0004H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		version (GNU) asm {
			"mov $0x40000004, %%eax\n"~
			"mov $0, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"
			: "=a" (a);
		} else asm {
			mov EAX, 0x4000_0004;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
		}
		info.hv_hint_hypercall_for_process_switch	= (a & BIT!(0)) != 0;
		info.hv_hint_hypercall_for_tlb_flush	= (a & BIT!(1)) != 0;
		info.hv_hint_hypercall_for_tlb_shootdown	= (a & BIT!(2)) != 0;
		info.hv_hint_msr_for_apic_access	= (a & BIT!(3)) != 0;
		info.hv_hint_msr_for_sys_reset	= (a & BIT!(4)) != 0;
		info.hv_hint_relax_time_checks	= (a & BIT!(5)) != 0;
		info.hv_hint_dma_remapping	= (a & BIT!(6)) != 0;
		info.hv_hint_interrupt_remapping	= (a & BIT!(7)) != 0;
		info.hv_hint_x2apic_msrs	= (a & BIT!(8)) != 0;
		info.hv_hint_deprecate_auto_eoi	= (a & BIT!(9)) != 0;
		info.hv_hint_synth_cluster_ipi_hypercall	= (a & BIT!(10)) != 0;
		info.hv_hint_ex_proc_masks_interface	= (a & BIT!(11)) != 0;
		info.hv_hint_nested_hyperv	= (a & BIT!(12)) != 0;
		info.hv_hint_int_for_mbec_syscalls	= (a & BIT!(13)) != 0;
		info.hv_hint_nested_enlightened_vmcs_interface	= (a & BIT!(14)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0006) goto EXTENDED_LEAVES;
	
	//
	// Leaf 4000_0006H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		version (GNU) asm {
			"mov $0x40000006, %%eax\n"~
			"mov $0, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"
			: "=a" (a);
		} else asm {
			mov EAX, 0x4000_0006;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
		}
		info.hv_host_feat_avic	= (a & BIT!(0)) != 0;
		info.hv_host_feat_msr_bitmap	= (a & BIT!(1)) != 0;
		info.hv_host_feat_perf_counter	= (a & BIT!(2)) != 0;
		info.hv_host_feat_nested_paging	= (a & BIT!(3)) != 0;
		info.hv_host_feat_dma_remapping	= (a & BIT!(4)) != 0;
		info.hv_host_feat_interrupt_remapping	= (a & BIT!(5)) != 0;
		info.hv_host_feat_mem_patrol_scrubber	= (a & BIT!(6)) != 0;
		info.hv_host_feat_dma_prot_in_use	= (a & BIT!(7)) != 0;
		info.hv_host_feat_hpet_requested	= (a & BIT!(8)) != 0;
		info.hv_host_feat_stimer_volatile	= (a & BIT!(9)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0010) goto EXTENDED_LEAVES;
	
	//
	// Leaf 4000_0010H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_MIN: // VBox Minimal
		version (GNU) asm {
			"mov $0x40000010, %%eax\n"~
			"mov $0, %%ecx\n"~
			"cpuid\n"~
			"mov %%eax, %0\n"~
			"mov %%ebx, %1\n"
			: "=a" (a), "=b" (b);
		} else asm {
			mov EAX, 0x4000_0010;
			mov ECX, 0;
			cpuid;
			mov a, EAX;
			mov b, EBX;
		}
		info.vbox_tsc_freq_khz = a;
		info.vbox_apic_freq_khz = b;
		break;
	default:
	}

	//
	// Leaf 8000_0001H
	//

EXTENDED_LEAVES:

	version (GNU) asm {
		"mov $0x80000001, %%eax\n"~
		"cpuid\n"~
		"mov %%ecx, %0\n"~
		"mov %%edx, %1"
		: "=c" (c), "=d" (d);
	} else asm {
		mov EAX, 0x8000_0001;
		cpuid;
		mov c, ECX;
		mov d, EDX;
	}

	switch (info.vendor_id) {
	case VENDOR_AMD:
		info.virt	= (c & BIT!(2)) != 0;
		info.x2apic	= (c & BIT!(3)) != 0;
		info.sse4a	= (c & BIT!(6)) != 0;
		info.xop	= (c & BIT!(11)) != 0;
		info.skinit	= (c & BIT!(12)) != 0;
		info.fma4	= (c & BIT!(16)) != 0;
		info.tbm	= (c & BIT!(21)) != 0;
		info.monitorx	= (c & BIT!(29)) != 0;
		info.mmxext	= (d & BIT!(22)) != 0;
		info._3dnowext	= (d & BIT!(30)) != 0;
		info._3dnow	= d >= BIT!(31);
		break;
	default:
	}

	info.lahf64	= (c & BIT!(0)) != 0;
	info.lzcnt	= (c & BIT!(5)) != 0;
	info.prefetchw	= (c & BIT!(8)) != 0;
	info.syscall	= (d & BIT!(11)) != 0;
	info.nx	= (d & BIT!(20)) != 0;
	info.page1gb	= (d & BIT!(26)) != 0;
	info.rdtscp	= (d & BIT!(27)) != 0;
	info.x86_64	= (d & BIT!(29)) != 0;

	if (info.max_ext_leaf < 0x8000_0007) return;
	
	//
	// Leaf 8000_0007H
	//

	version (GNU) asm {
		"mov $0x80000007, %%eax\n"~
		"cpuid\n"~
		"mov %%ebx, %0\n"~
		"mov %%edx, %1"
		: "=b" (b), "=d" (d);
	} else asm {
		mov EAX, 0x8000_0007;
		cpuid;
		mov b, EBX;
		mov d, EDX;
	}

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		info.rdseed	= (b & BIT!(28)) != 0;
		break;
	case VENDOR_AMD:
		info.tm	= (d & BIT!(4)) != 0;
		info.turboboost	= (d & BIT!(9)) != 0;
		break;
	default:
	}

	info.rdtsc_invariant	= (d & BIT!(8)) != 0;

	if (info.max_ext_leaf < 0x8000_0008) return;
	
	//
	// Leaf 8000_0008H
	//

	version (GNU) asm {
		"mov $0x80000008, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%ebx, %1\n"
		: "=a" (a), "=b" (b);
	} else asm {
		mov EAX, 0x8000_0008;
		cpuid;
		mov a, EAX;
		mov b, EBX;
	}

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		info.wbnoinvd	= (b & BIT!(9)) != 0;
		break;
	case VENDOR_AMD:
		info.ibpb	= (b & BIT!(12)) != 0;
		info.ibrs	= (b & BIT!(14)) != 0;
		info.stibp	= (b & BIT!(15)) != 0;
		info.ibrs_on	= (b & BIT!(16)) != 0;
		info.stibp_on	= (b & BIT!(17)) != 0;
		info.ibrs_pref	= (b & BIT!(18)) != 0;
		info.ssbd	= (b & BIT!(24)) != 0;
		break;
	default:
	}

	info.b_8000_0008_ax = cast(ushort)a; // info.addr_phys_bits, info.addr_line_bits

	if (info.max_ext_leaf < 0x8000_000A) return;
	
	//
	// Leaf 8000_000AH
	//

	version (GNU) asm {
		"mov $0x8000000a, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0"
		: "=a" (a);
	} else asm {
		mov EAX, 0x8000_000A;
		cpuid;
		mov a, EAX;
	}

	switch (info.vendor_id) {
	case VENDOR_AMD:
		info.virt_version = cast(ubyte)a; // EAX[7:0]
		break;
	default:
	}

	//if (info.max_ext_leaf < ...) return;
}

/// (Internal) Get CPU leafs
/// Params: info = CPUINFO structure
void getLeaves(ref CPUINFO info) {
	version (GNU) { // GDC
		asm {
			"mov $0, %%eax\n"~
			"cpuid"
			: "=a" (info.max_leaf);
		}
		asm {
			"mov $0x40000000, %%eax\n"~
			"cpuid"
			: "=a" (info.max_virt_leaf);
		}
		asm {
			"mov $0x80000000, %%eax\n"~
			"cpuid"
			: "=a" (info.max_ext_leaf);
		}
	} else
	version (LDC) { // LDC2
		version (X86) asm {
			lea EDI, info;
			mov EAX, 0;
			cpuid;
			mov [EDI + info.max_leaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [EDI + info.max_virt_leaf.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [EDI + info.max_ext_leaf.offsetof], EAX;
		}
		else
		version (X86_64) asm {
			lea RDI, info;
			mov EAX, 0;
			cpuid;
			mov [RDI + info.max_leaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [RDI + info.max_virt_leaf.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [RDI + info.max_ext_leaf.offsetof], EAX;
		}
	} else { // DMD
		version (X86) asm {
			mov EDI, info;
			mov EAX, 0;
			cpuid;
			mov [EDI + info.max_leaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [EDI + info.max_virt_leaf.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [EDI + info.max_ext_leaf.offsetof], EAX;
		}
		else
		version (X86_64) asm {
			mov RDI, info;
			mov EAX, 0;
			cpuid;
			mov [RDI + info.max_leaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [RDI + info.max_virt_leaf.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [RDI + info.max_ext_leaf.offsetof], EAX;
		}
	}
}

debug pragma(msg, "* CPUINFO.sizeof: ", CPUINFO.sizeof);
debug pragma(msg, "* CACHE.sizeof: ", CACHEINFO.sizeof);