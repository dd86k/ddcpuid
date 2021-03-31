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
template BIT(int n) { enum { BIT = 1 << n } }

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
	bool fpu;	/// 
	bool f16c;	/// 
	bool mmx;	/// 
	bool mmxext;	/// 
	bool _3dnow;	/// 
	bool _3dnowext;	/// 
	bool aes_ni;	/// 
	bool sha;	/// 
	bool fma3;	/// 
	bool fma4;	/// 
	bool bmi1;	/// 
	bool bmi2;	/// 
	bool x86_64;	/// long mode
	bool lahf64;	/// 
	bool waitpkg;	/// 
	bool xop;	/// 
	bool tbm;	/// 
	bool adx;	/// 
	
	// SSE
	
	bool sse;	/// 
	bool sse2;	/// 
	bool sse3;	/// 
	bool ssse3;	/// 
	bool sse41;	/// 
	bool sse42;	/// 
	bool sse4a;	/// 
	
	// AVX
	
	bool avx;	/// 
	bool avx2;	/// 
	bool avx512f;	/// 
	bool avx512er;	/// 
	bool avx512pf;	/// 
	bool avx512cd;	/// 
	bool avx512dq;	/// 
	bool avx512bw;	/// 
	bool avx512vl;	/// 
	bool avx512_ifma;	/// 
	bool avx512_vbmi;	/// 
	bool avx512_vbmi2;	/// 
	bool avx512_gfni;	/// 
	bool avx512_vaes;	/// 
	bool avx512_vnni;	/// 
	bool avx512_bitalg;	/// 
	bool avx512_vpopcntdq;	/// 
	bool avx512_4vnniw;	/// 
	bool avx512_4fmaps;	/// 
	bool avx512_bf16;	/// 
	bool avx512_vp2intersect;	/// 
	
	// AMX
	
	bool amx;	/// 
	bool amx_bf16;	/// 
	bool amx_int8;	/// 
	bool amx_xtilecfg;	/// 0Dh.EAX[17]
	bool amx_xtiledata;	/// 0Dh.EAX[18]
	bool amx_xfd;	/// 0Dh(ECX=01h).EAX[18]
	
	//
	// Extra instructions
	//
	
	bool monitor;	/// 
	bool pclmulqdq;	/// 
	bool cmpxchg8b;	/// 
	bool cmpxchg16b;	/// 
	bool movbe;	/// 
	bool rdrand;	/// 
	bool rdseed;	/// 
	bool rdmsr;	/// 
	bool sysenter;	/// 
	bool tsc;	/// 
	bool tsc_deadline;	/// 
	bool tsc_invariant;	/// 
	bool rdtscp;	/// 
	bool rdpid;	/// 
	bool cmov;	/// 
	bool lzcnt;	/// 
	bool popcnt;	/// 
	bool xsave;	/// 
	bool osxsave;	/// 
	bool fxsr;	/// 
	bool pconfig;	/// 
	bool cldemote;	/// 
	bool movdiri;	/// 
	bool movdir64b;	/// 
	bool enqcmd;	/// 
	bool syscall;	/// 
	bool monitorx;	/// 
	bool skinit;	/// 
	bool clflushopt;	/// 
	bool serialize;	/// 
	
	//
	// Technologies
	//
	
	bool eist;	/// 
	bool turboboost;	/// 
	bool turboboost30;	/// 
	bool smx;	/// 
	bool sgx;	/// 
	bool htt;	/// 
	
	//
	// Cache
	//
	
	CACHEINFO [6]cache;
	bool clflush;	/// 
	bool cnxt_id;	/// 
	bool ss;	/// selfsnoop
	bool prefetchw;	/// 
	bool invpcid;	/// 
	bool wbnoinvd;	/// 

	
	//
	// ACPI
	//
	
	bool acpi;
	bool apic;
	bool x2apic;
	bool arat;
	bool tm;
	bool tm2;
	union { // 01h.EBX
		uint b_01_ebx;
		struct {
			ubyte brand_index;
			ubyte clflush_linesize;
			ubyte max_apic_id;
			ubyte apic_id;
		}
	}
	ushort mwait_min;
	ushort mwait_max;
	
	//
	// Virtualization
	//
	
	bool virt;
	ubyte virt_version;
	bool vme;
	
	union {
		char[12] virt_vendor;
		uint virt_vendor_id;
	}
	
	// VBox
	
	uint vbox_tsc_freq_khz;
	uint vbox_apic_freq_khz;
	ushort vbox_guest_vendor_id;
	ushort vbox_guest_build;
	ubyte vbox_guest_os;
	ubyte vbox_guest_major;
	ubyte vbox_guest_minor;
	ubyte vbox_guest_service;
	bool vbox_guest_opensource;
	
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
	
	bool pae;	/// 
	bool pse;	/// 
	bool pse_36;	/// 
	bool page1gb;	/// 
	bool mtrr;	/// 
	bool pat;	/// 
	bool pge;	/// 
	bool dca;	/// 
	bool nx;	/// 
	bool hle;	/// 
	bool rtm;	/// 
	bool smep;	/// 
	bool smap;	/// 
	bool pku;	/// 
	bool _5pl;	/// 
	bool fsrepmov;	/// 
	bool tsxldtrk;	/// 
	bool lam;	/// 
	union {
		ushort b_8000_0008_ax;
		struct {
			ubyte phys_bits;	// EAX[7 :0]
			ubyte line_bits;	// EAX[15:8]
		}
	}
	
	// Debugging
	
	bool mca;	/// 
	bool mce;	/// 
	bool de;	/// 
	bool ds;	/// 
	bool ds_cpl;	/// 
	bool dtes64;	/// 
	bool pdcm;	/// 
	bool sdbg;	/// 
	bool pbe;	/// 
	
	// Security
	
	bool ibpb;	/// 
	bool ibrs;	/// 
	bool ibrs_on;	/// 
	bool ibrs_pref;	/// 
	bool stibp;	/// 
	bool stibp_on;	/// 
	bool ssbd;	/// 
	bool l1d_flush;	/// 
	bool md_clear;	/// 
	bool cet_ibt;	/// 
	bool cet_ss;	/// 
	
	// Misc.
	
	bool psn;	/// 
	bool pcid;	/// 
	bool xtpr;	/// 
	bool ia32_arch_capabilities;	/// 
	bool fsgsbase;	/// 
	bool uintr;	/// 
	
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
	VIRT_VENDOR_VBOX_MIN = 0, /// VirtualBox: Minimal interface
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
	"  -s    (with -r) subleaf to loop to (ECX)\n"~
	"  -o    Override leaves to 20h, 4000_0002h, and 8000_0020h\n"~
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
	if (info.tsc) {
		printf(" RDTSC");
		if (info.tsc_deadline)
			printf(" +TSC-Deadline");
		if (info.tsc_invariant)
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
		if (c & BIT!(2)) info.dtes64	= true;
		if (c & BIT!(4)) info.ds_cpl	= true;
		if (c & BIT!(5)) info.virt	= true;
		if (c & BIT!(6)) info.smx	= true;
		if (c & BIT!(7)) info.eist	= true;
		if (c & BIT!(8)) info.tm2	= true;
		if (c & BIT!(10)) info.cnxt_id	= true;
		if (c & BIT!(11)) info.sdbg	= true;
		if (c & BIT!(14)) info.xtpr	= true;
		if (c & BIT!(15)) info.pdcm	= true;
		if (c & BIT!(17)) info.pcid	= true;
		if (c & BIT!(18)) info.mca	= true;
		if (c & BIT!(21)) info.x2apic	= true;
		if (c & BIT!(24)) info.tsc_deadline	= true;

		// EDX
		if (d & BIT!(18)) info.psn	= true;
		if (d & BIT!(21)) info.ds	= true;
		if (d & BIT!(22)) info.acpi	= true;
		if (d & BIT!(27)) info.ss	= true;
		if (d & BIT!(29)) info.tm	= true;
		if (d & BIT!(31)) info.pbe	= true;
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
	if (c & BIT!(0)) info.sse3	= true;
	if (c & BIT!(1)) info.pclmulqdq	= true;
	if (c & BIT!(3)) info.monitor	= true;
	if (c & BIT!(9)) info.ssse3	= true;
	if (c & BIT!(12)) info.fma3	= true;
	if (c & BIT!(13)) info.cmpxchg16b	= true;
	if (c & BIT!(15)) info.sse41	= true;
	if (c & BIT!(20)) info.sse42	= true;
	if (c & BIT!(22)) info.movbe	= true;
	if (c & BIT!(23)) info.popcnt	= true;
	if (c & BIT!(25)) info.aes_ni	= true;
	if (c & BIT!(26)) info.xsave	= true;
	if (c & BIT!(27)) info.osxsave	= true;
	if (c & BIT!(28)) info.avx	= true;
	if (c & BIT!(29)) info.f16c	= true;
	if (c & BIT!(30)) info.rdrand	= true;
	
	// EDX
	if (d & BIT!(0)) info.fpu	= true;
	if (d & BIT!(1)) info.vme	= true;
	if (d & BIT!(2)) info.de	= true;
	if (d & BIT!(3)) info.pse	= true;
	if (d & BIT!(4)) info.tsc	= true;
	if (d & BIT!(5)) info.rdmsr	= true;
	if (d & BIT!(6)) info.pae	= true;
	if (d & BIT!(7)) info.mce	= true;
	if (d & BIT!(8)) info.cmpxchg8b	= true;
	if (d & BIT!(9)) info.apic	= true;
	if (d & BIT!(11)) info.sysenter	= true;
	if (d & BIT!(12)) info.mtrr	= true;
	if (d & BIT!(13)) info.pge	= true;
	if (d & BIT!(14)) info.mca	= true;
	if (d & BIT!(15)) info.cmov	= true;
	if (d & BIT!(16)) info.pat	= true;
	if (d & BIT!(17)) info.pse_36	= true;
	if (d & BIT!(19)) info.clflush	= true;
	if (d & BIT!(23)) info.mmx	= true;
	if (d & BIT!(24)) info.fxsr	= true;
	if (d & BIT!(25)) info.sse	= true;
	if (d & BIT!(26)) info.sse2	= true;
	if (d & BIT!(28)) info.htt	= true;
	
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
		if (a & BIT!(1))  info.turboboost	= true;
		if (a & BIT!(14)) info.turboboost30	= true;
		break;
	default:
	}

	if (a & BIT!(2)) info.arat	= true;

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
		if (b & BIT!(2)) info.sgx	= true;
		if (b & BIT!(4)) info.hle	= true;
		if (b & BIT!(10)) info.invpcid	= true;
		if (b & BIT!(11)) info.rtm	= true;
		if (b & BIT!(16)) info.avx512f	= true;
		if (b & BIT!(20)) info.smap	= true;
		if (b & BIT!(27)) info.avx512er	= true;
		if (b & BIT!(26)) info.avx512pf	= true;
		if (b & BIT!(28)) info.avx512cd	= true;
		if (b & BIT!(17)) info.avx512dq	= true;
		if (b & BIT!(30)) info.avx512bw	= true;
		if (b & BIT!(21)) info.avx512_ifma	= true;
		if (b & BIT!(31)) info.avx512_vbmi	= true;
		// ECX
		if (c & BIT!(1)) info.avx512vl	= true;
		if (c & BIT!(3)) info.pku	= true;
		if (c & BIT!(4)) info.fsrepmov	= true;
		if (c & BIT!(5)) info.waitpkg	= true;
		if (c & BIT!(6)) info.avx512_vbmi2	= true;
		if (c & BIT!(7)) info.cet_ss	= true;
		if (c & BIT!(8)) info.avx512_gfni	= true;
		if (c & BIT!(9)) info.avx512_vaes	= true;
		if (c & BIT!(11)) info.avx512_vnni	= true;
		if (c & BIT!(12)) info.avx512_bitalg	= true;
		if (c & BIT!(14)) info.avx512_vpopcntdq	= true;
		if (c & BIT!(16)) info._5pl	= true;
		if (c & BIT!(25)) info.cldemote	= true;
		if (c & BIT!(27)) info.movdiri	= true;
		if (c & BIT!(28)) info.movdir64b	= true;
		if (c & BIT!(29)) info.enqcmd	= true;
		// EDX
		if (d & BIT!(2)) info.avx512_4vnniw	= true;
		if (d & BIT!(3)) info.avx512_4fmaps	= true;
		if (d & BIT!(5)) info.uintr	= true;
		if (d & BIT!(8)) info.avx512_vp2intersect	= true;
		if (d & BIT!(10)) info.md_clear	= true;
		if (d & BIT!(14)) info.serialize	= true;
		if (d & BIT!(16)) info.tsxldtrk	= true;
		if (d & BIT!(18)) info.pconfig	= true;
		if (d & BIT!(20)) info.cet_ibt	= true;
		if (d & BIT!(22)) info.amx_bf16	= true;
		if (d & BIT!(24)) info.amx	= true;
		if (d & BIT!(25)) info.amx_int8	= true;
		if (d & BIT!(26)) info.ibrs = info.ibpb = true;
		if (d & BIT!(27)) info.stibp	= true;
		if (d & BIT!(28)) info.l1d_flush	= true;
		if (d & BIT!(29)) info.ia32_arch_capabilities	= true;
		if (d & BIT!(31)) info.ssbd	= true;
		break;
	default:
	}

	// b
	if (b & BIT!(0)) info.fsgsbase	= true;
	if (b & BIT!(3)) info.bmi1	= true;
	if (b & BIT!(5)) info.avx2	= true;
	if (b & BIT!(7)) info.smep	= true;
	if (b & BIT!(8)) info.bmi2	= true;
	if (b & BIT!(18)) info.rdseed	= true;
	if (b & BIT!(19)) info.adx	= true;
	if (b & BIT!(23)) info.clflushopt	= true;
	if (b & BIT!(29)) info.sha	= true;
	// c
	if (c & BIT!(22)) info.rdpid	= true;
	
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
		if (a & BIT!(5))  info.avx512_bf16	= true;
		if (a & BIT!(26)) info.lam	= true;
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
		if (a & BIT!(17)) info.amx_xtilecfg	= true;
		if (a & BIT!(18)) info.amx_xtiledata	= true;
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
		if (a & BIT!(18)) info.amx_xfd	= true;
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
		if (a & BIT!(0)) info.kvm_feature_clocksource	= true;
		if (a & BIT!(1)) info.kvm_feature_nop_io_delay	= true;
		if (a & BIT!(2)) info.kvm_feature_mmu_op	= true;
		if (a & BIT!(3)) info.kvm_feature_clocksource2	= true;
		if (a & BIT!(4)) info.kvm_feature_async_pf	= true;
		if (a & BIT!(5)) info.kvm_feature_steal_time	= true;
		if (a & BIT!(6)) info.kvm_feature_pv_eoi	= true;
		if (a & BIT!(7)) info.kvm_feature_pv_unhault	= true;
		if (a & BIT!(9)) info.kvm_feature_pv_tlb_flush	= true;
		if (a & BIT!(10)) info.kvm_feature_async_pf_vmexit	= true;
		if (a & BIT!(11)) info.kvm_feature_pv_send_ipi	= true;
		if (a & BIT!(12)) info.kvm_feature_pv_poll_control	= true;
		if (a & BIT!(13)) info.kvm_feature_pv_sched_yield	= true;
		if (a & BIT!(24)) info.kvm_feature_clocsource_stable_bit	= true;
		if (d & BIT!(0)) info.kvm_hints_realtime	= true;
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
		if (d >= 0x8000_0000) info.vbox_guest_opensource = true;
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
		if (a & BIT!(0)) info.hv_base_feat_vp_runtime_msr	= true;
		if (a & BIT!(1)) info.hv_base_feat_part_time_ref_count_msr	= true;
		if (a & BIT!(2)) info.hv_base_feat_basic_synic_msrs	= true;
		if (a & BIT!(3)) info.hv_base_feat_stimer_msrs	= true;
		if (a & BIT!(4)) info.hv_base_feat_apic_access_msrs	= true;
		if (a & BIT!(5)) info.hv_base_feat_hypercall_msrs	= true;
		if (a & BIT!(6)) info.hv_base_feat_vp_id_msr	= true;
		if (a & BIT!(7)) info.hv_base_feat_virt_sys_reset_msr	= true;
		if (a & BIT!(8)) info.hv_base_feat_stat_pages_msr	= true;
		if (a & BIT!(9)) info.hv_base_feat_part_ref_tsc_msr	= true;
		if (a & BIT!(10)) info.hv_base_feat_guest_idle_state_msr	= true;
		if (a & BIT!(11)) info.hv_base_feat_timer_freq_msrs	= true;
		if (a & BIT!(12)) info.hv_base_feat_debug_msrs	= true;
		if (b & BIT!(0)) info.hv_part_flags_create_part	= true;
		if (b & BIT!(1)) info.hv_part_flags_access_part_id	= true;
		if (b & BIT!(2)) info.hv_part_flags_access_memory_pool	= true;
		if (b & BIT!(3)) info.hv_part_flags_adjust_msg_buffers	= true;
		if (b & BIT!(4)) info.hv_part_flags_post_msgs	= true;
		if (b & BIT!(5)) info.hv_part_flags_signal_events	= true;
		if (b & BIT!(6)) info.hv_part_flags_create_port	= true;
		if (b & BIT!(7)) info.hv_part_flags_connect_port	= true;
		if (b & BIT!(8)) info.hv_part_flags_access_stats	= true;
		if (b & BIT!(11)) info.hv_part_flags_debugging	= true;
		if (b & BIT!(12)) info.hv_part_flags_cpu_mgmt	= true;
		if (b & BIT!(13)) info.hv_part_flags_cpu_profiler	= true;
		if (b & BIT!(14)) info.hv_part_flags_expanded_stack_walk	= true;
		if (b & BIT!(16)) info.hv_part_flags_access_vsm	= true;
		if (b & BIT!(17)) info.hv_part_flags_access_vp_regs	= true;
		if (b & BIT!(20)) info.hv_part_flags_extended_hypercalls	= true;
		if (b & BIT!(21)) info.hv_part_flags_start_vp	= true;
		if (c & BIT!(0)) info.hv_pm_max_cpu_power_state_c0	= true;
		if (c & BIT!(1)) info.hv_pm_max_cpu_power_state_c1	= true;
		if (c & BIT!(2)) info.hv_pm_max_cpu_power_state_c2	= true;
		if (c & BIT!(3)) info.hv_pm_max_cpu_power_state_c3	= true;
		if (c & BIT!(4)) info.hv_pm_hpet_reqd_for_c3	= true;
		if (a & BIT!(0)) info.hv_misc_feat_mwait	= true;
		if (a & BIT!(1)) info.hv_misc_feat_guest_debugging	= true;
		if (a & BIT!(2)) info.hv_misc_feat_perf_mon	= true;
		if (a & BIT!(3)) info.hv_misc_feat_pcpu_dyn_part_event	= true;
		if (a & BIT!(4)) info.hv_misc_feat_xmm_hypercall_input	= true;
		if (a & BIT!(5)) info.hv_misc_feat_guest_idle_state	= true;
		if (a & BIT!(6)) info.hv_misc_feat_hypervisor_sleep_state	= true;
		if (a & BIT!(7)) info.hv_misc_feat_query_numa_distance	= true;
		if (a & BIT!(8)) info.hv_misc_feat_timer_freq	= true;
		if (a & BIT!(9)) info.hv_misc_feat_inject_synmc_xcpt	= true;
		if (a & BIT!(10)) info.hv_misc_feat_guest_crash_msrs	= true;
		if (a & BIT!(11)) info.hv_misc_feat_debug_msrs	= true;
		if (a & BIT!(12)) info.hv_misc_feat_npiep1	= true;
		if (a & BIT!(13)) info.hv_misc_feat_disable_hypervisor	= true;
		if (a & BIT!(14)) info.hv_misc_feat_ext_gva_range_for_flush_va_list	= true;
		if (a & BIT!(15)) info.hv_misc_feat_hypercall_output_xmm	= true;
		if (a & BIT!(17)) info.hv_misc_feat_sint_polling_mode	= true;
		if (a & BIT!(18)) info.hv_misc_feat_hypercall_msr_lock	= true;
		if (a & BIT!(19)) info.hv_misc_feat_use_direct_synth_msrs	= true;
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
		if (a & BIT!(0)) info.hv_hint_hypercall_for_process_switch	= true;
		if (a & BIT!(1)) info.hv_hint_hypercall_for_tlb_flush	= true;
		if (a & BIT!(2)) info.hv_hint_hypercall_for_tlb_shootdown	= true;
		if (a & BIT!(3)) info.hv_hint_msr_for_apic_access	= true;
		if (a & BIT!(4)) info.hv_hint_msr_for_sys_reset	= true;
		if (a & BIT!(5)) info.hv_hint_relax_time_checks	= true;
		if (a & BIT!(6)) info.hv_hint_dma_remapping	= true;
		if (a & BIT!(7)) info.hv_hint_interrupt_remapping	= true;
		if (a & BIT!(8)) info.hv_hint_x2apic_msrs	= true;
		if (a & BIT!(9)) info.hv_hint_deprecate_auto_eoi	= true;
		if (a & BIT!(10)) info.hv_hint_synth_cluster_ipi_hypercall	= true;
		if (a & BIT!(11)) info.hv_hint_ex_proc_masks_interface	= true;
		if (a & BIT!(12)) info.hv_hint_nested_hyperv	= true;
		if (a & BIT!(13)) info.hv_hint_int_for_mbec_syscalls	= true;
		if (a & BIT!(14)) info.hv_hint_nested_enlightened_vmcs_interface	= true;
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
		if (a & BIT!(0)) info.hv_host_feat_avic	= true;
		if (a & BIT!(1)) info.hv_host_feat_msr_bitmap	= true;
		if (a & BIT!(2)) info.hv_host_feat_perf_counter	= true;
		if (a & BIT!(3)) info.hv_host_feat_nested_paging	= true;
		if (a & BIT!(4)) info.hv_host_feat_dma_remapping	= true;
		if (a & BIT!(5)) info.hv_host_feat_interrupt_remapping	= true;
		if (a & BIT!(6)) info.hv_host_feat_mem_patrol_scrubber	= true;
		if (a & BIT!(7)) info.hv_host_feat_dma_prot_in_use	= true;
		if (a & BIT!(8)) info.hv_host_feat_hpet_requested	= true;
		if (a & BIT!(9)) info.hv_host_feat_stimer_volatile	= true;
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
		if (c & BIT!(2)) info.virt	= true;
		if (c & BIT!(3)) info.x2apic	= true;
		if (c & BIT!(6)) info.sse4a	= true;
		if (c & BIT!(11)) info.xop	= true;
		if (c & BIT!(12)) info.skinit	= true;
		if (c & BIT!(16)) info.fma4	= true;
		if (c & BIT!(21)) info.tbm	= true;
		if (c & BIT!(29)) info.monitorx	= true;
		if (d & BIT!(22)) info.mmxext	= true;
		if (d & BIT!(30)) info._3dnowext	= true;
		if (d & BIT!(31)) info._3dnow	= true;
		break;
	default:
	}

	if (c & BIT!(0)) info.lahf64	= true;
	if (c & BIT!(5)) info.lzcnt	= true;
	if (c & BIT!(8)) info.prefetchw	= true;
	if (d & BIT!(11)) info.syscall	= true;
	if (d & BIT!(20)) info.nx	= true;
	if (d & BIT!(26)) info.page1gb	= true;
	if (d & BIT!(27)) info.rdtscp	= true;
	if (d & BIT!(29)) info.x86_64	= true;

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
		if (b & BIT!(28)) info.rdseed	= true;
		break;
	case VENDOR_AMD:
		if (d & BIT!(4)) info.tm	= true;
		if (d & BIT!(9)) info.turboboost	= true;
		break;
	default:
	}

	if (d & BIT!(8)) info.tsc_invariant	= true;

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
		if (b & BIT!(9)) info.wbnoinvd	= true;
		break;
	case VENDOR_AMD:
		if (b & BIT!(12)) info.ibpb	= true;
		if (b & BIT!(14)) info.ibrs	= true;
		if (b & BIT!(15)) info.stibp	= true;
		if (b & BIT!(16)) info.ibrs_on	= true;
		if (b & BIT!(17)) info.stibp_on	= true;
		if (b & BIT!(18)) info.ibrs_pref	= true;
		if (b & BIT!(24)) info.ssbd	= true;
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