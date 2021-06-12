/**
 * x86 CPU Identification tool
 *
 * This was initially used internally, so it's pretty unfriendly.
 *
 * The best way to use this module would be:
 * ---
 * CPUINFO info;     // Important to let the struct init to zero!
 * getLeaves(info);  // Get maximum CPUID leaves (mandatory step before info)
 * getVendor(info);  // Get vendor string (mandatory step before info)
 * getInfo(info);    // Fill CPUINFO structure (optional)
 * ---
 *
 * Then checking the corresponding field:
 * ---
 * if (info.amx_xfd) {
 *   // Feature available
 * } else {
 *   // Feature unavailable
 * }
 * ---
 *
 * See the CPUINFO structure for available fields.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: © 2016-2021 dd86k
 * License: MIT
 */
module ddcpuid;

// GAS syntax reminder
// asm { "asm;\n" : "constraint" output : "constraint" input : clobbers }

@system:
extern (C):

version (DigitalMars)
	version = DMD;
version (GNU)
	version = GDC;

version (X86) enum DDCPUID_PLATFORM = "x86"; /// Target platform
else version (X86_64) enum DDCPUID_PLATFORM = "amd64"; /// Target platform
else static assert(0, "ddcpuid is only supported on x86 platforms");

version (GDC) pragma(msg, "* warning: GDC support is experimental");

enum DDCPUID_VERSION	= "0.18.0";	/// Library version
enum DDCPUID_CACHE_MAX	= 6;	/// 

/// Make a bit mask of one bit at n position
private
template BIT(int n) if (n <= 31) { enum uint BIT = 1 << n; }

/// Vendor ID template
// Little-endian only, unless x86 gets any crazier
private
template ID(char[4] c) {
	enum uint ID = c[0] | c[1] << 8 | c[2] << 16 | c[3] << 24;
}

// Self-made vendor "IDs" for faster look-ups, LSB-based.
enum : uint {
	VENDOR_OTHER = 0,	/// Other or unknown (zero)
	VENDOR_INTEL = ID!("Genu"),	/// "GenuineIntel": Intel
	VENDOR_AMD   = ID!("Auth"),	/// "AuthenticAMD": AMD
	VENDOR_VIA   = ID!("VIA "),	/// "VIA VIA VIA ": VIA
	VIRT_VENDOR_KVM      = ID!("KVMK"), /// "KVMKVMKVM\0\0\0": KVM
	VIRT_VENDOR_VBOX_HV  = ID!("VBox"), /// "VBoxVBoxVBox": VirtualBox/Hyper-V interface
	VIRT_VENDOR_VBOX_MIN = 0, /// VirtualBox minimal interface (zero)
}

struct REGISTERS { align(1): uint eax, ebx, ecx, edx; }

/// CPU cache entry
struct CACHEINFO { align(1):
	union {
		package uint __bundle1;
		struct {
			ubyte linesize; /// Size of the line in bytes
			ubyte partitions;	/// Number of partitions
			ubyte ways;	/// Number of ways per line
			ubyte _amdsize;	/// (Legacy AMD) Size in KiB
		}
	}
	/// Cache Size in kilobytes.
	// (Ways + 1) * (Partitions + 1) * (Line_Size + 1) * (Sets + 1)
	// (EBX[31:22] + 1) * (EBX[21:12] + 1) * (EBX[11:0] + 1) * (ECX + 1)
	uint size;
	/// Number of cache sets.
	ushort sets;
	/// Number of CPU cores sharing this cache.
	ushort sharedCores;
	/// Cache feature, bit flags.
	/// - Bit 0: Self Initializing cache
	/// - Bit 1: Fully Associative cache
	/// - Bit 2: No Write-Back Invalidation (toggle)
	/// - Bit 3:  Cache Inclusiveness (toggle)
	/// - Bit 4: Complex Cache Indexing (toggle)
	ushort feat;
	ubyte level;	/// Cache level: L1, L2, etc.
	char type = 0;	/// Type entry character: 'D'=Data, 'I'=Instructions, 'U'=Unified
}

/// CPU information structure
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
	
	union {
		package uint[3] vendor32;	/// Vendor 32-bit parts
		char[12] vendor;	/// Vendor String
	}
	uint vendor_id;	/// Vendor "ID"
	union {
		package uint[12] brand32;
		char[48] brand;	/// Processor Brand String
	}
	
	//
	// Core
	//
	
//	ushort cores_physical;	/// Physical cores in the processor
	ushort cores_logical;	/// Logical cores in the processor
	
	//
	// Identifier
	//

	ubyte family;	/// Effective family identifier
	ubyte base_family;	/// Base family identifier
	ubyte ext_family;	/// Extended family identifier
	ubyte model;	/// Effective model identifier
	ubyte base_model;	/// Base model identifier
	ubyte ext_model;	/// Extended model identifier
	ubyte stepping;	/// Stepping revision
	ubyte type;	/// Processor type number
	/// Processor type string.
	/// No longer used by modern processors.
	const(char) *type_string;
	
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
	private bool res_avx;	// for alignment
	
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
	
	uint cache_level;	/// Number of cache levels
	CACHEINFO [DDCPUID_CACHE_MAX]cache;	/// Cache information
	bool clflush;	/// CLFLUSH instruction
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
		package uint b_01_ebx;
		struct {
			ubyte brand_index;	/// Processor brand index. No longer used.
			ubyte clflush_linesize;	/// Linesize of CLFLUSH in bytes
			ubyte max_apic_id;	/// Maximum APIC ID
			ubyte apic_id;	/// Initial APIC ID (running core where CPUID was called)
		}
	}
	ushort mwait_min;	/// MWAIT minimum size in bytes
	ushort mwait_max;	/// MWAIT maximum size in bytes
	
	//
	// Virtualization
	//
	
	bool virt;	/// VT-x/AMD-V
	ubyte virt_version;	/// (AMD) Virtualization platform version
	bool vme;	/// vm8086 enhanced
	bool apivc;	/// (AMD) APICv
	
	union {
		uint[3] virt_vendor32;
		char[12] virt_vendor;	/// Paravirtualization vendor
	}
	uint virt_vendor_id;
	
	//TODO: Consider bit flags for paravirtualization flags
	
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
	private bool vbox_guest_res;	// for alignment
	
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
	bool kvm_hint_realtime;
	private bool kvm_hint_res;	// for alignment
	
	// Hyper-V
	
	bool hv_base_feat_vp_runtime_msr;
	bool hv_base_feat_part_time_ref_count_msr;
	bool hv_base_feat_basic_synic_msrs;
	bool hv_base_feat_stimer_msrs;
	bool hv_base_feat_apic_access_msrs;
	bool hv_base_feat_hypercall_msrs;
	bool hv_base_feat_vp_id_msr;
	bool hv_base_feat_virt_sys_reset_msr;
	bool hv_base_feat_stat_pages_msr;
	bool hv_base_feat_part_ref_tsc_msr;
	bool hv_base_feat_guest_idle_state_msr;
	bool hv_base_feat_timer_freq_msrs;
	bool hv_base_feat_debug_msrs;
	bool hv_part_flags_create_part;
	bool hv_part_flags_access_part_id;
	bool hv_part_flags_access_memory_pool;
	bool hv_part_flags_adjust_msg_buffers;
	bool hv_part_flags_post_msgs;
	bool hv_part_flags_signal_events;
	bool hv_part_flags_create_port;
	bool hv_part_flags_connect_port;
	bool hv_part_flags_access_stats;
	bool hv_part_flags_debugging;
	bool hv_part_flags_cpu_mgmt;
	bool hv_part_flags_cpu_profiler;
	bool hv_part_flags_expanded_stack_walk;
	bool hv_part_flags_access_vsm;
	bool hv_part_flags_access_vp_regs;
	bool hv_part_flags_extended_hypercalls;
	bool hv_part_flags_start_vp;
	bool hv_pm_max_cpu_power_state_c0;
	bool hv_pm_max_cpu_power_state_c1;
	bool hv_pm_max_cpu_power_state_c2;
	bool hv_pm_max_cpu_power_state_c3;
	bool hv_pm_hpet_reqd_for_c3;
	bool hv_misc_feat_mwait;
	bool hv_misc_feat_guest_debugging;
	bool hv_misc_feat_perf_mon;
	bool hv_misc_feat_pcpu_dyn_part_event;
	bool hv_misc_feat_xmm_hypercall_input;
	bool hv_misc_feat_guest_idle_state;
	bool hv_misc_feat_hypervisor_sleep_state;
	bool hv_misc_feat_query_numa_distance;
	bool hv_misc_feat_timer_freq;
	bool hv_misc_feat_inject_synmc_xcpt;
	bool hv_misc_feat_guest_crash_msrs;
	bool hv_misc_feat_debug_msrs;
	bool hv_misc_feat_npiep1;
	bool hv_misc_feat_disable_hypervisor;
	bool hv_misc_feat_ext_gva_range_for_flush_va_list;
	bool hv_misc_feat_hypercall_output_xmm;
	bool hv_misc_feat_sint_polling_mode;
	bool hv_misc_feat_hypercall_msr_lock;
	bool hv_misc_feat_use_direct_synth_msrs;
	bool hv_hint_hypercall_for_process_switch;
	bool hv_hint_hypercall_for_tlb_flush;
	bool hv_hint_hypercall_for_tlb_shootdown;
	bool hv_hint_msr_for_apic_access;
	bool hv_hint_msr_for_sys_reset;
	bool hv_hint_relax_time_checks;
	bool hv_hint_dma_remapping;
	bool hv_hint_interrupt_remapping;
	bool hv_hint_x2apic_msrs;
	bool hv_hint_deprecate_auto_eoi;
	bool hv_hint_synth_cluster_ipi_hypercall;
	bool hv_hint_ex_proc_masks_interface;
	bool hv_hint_nested_hyperv;
	bool hv_hint_int_for_mbec_syscalls;
	bool hv_hint_nested_enlightened_vmcs_interface;
	bool hv_host_feat_avic;
	bool hv_host_feat_msr_bitmap;
	bool hv_host_feat_perf_counter;
	bool hv_host_feat_nested_paging;
	bool hv_host_feat_dma_remapping;
	bool hv_host_feat_interrupt_remapping;
	bool hv_host_feat_mem_patrol_scrubber;
	bool hv_host_feat_dma_prot_in_use;
	bool hv_host_feat_hpet_requested;
	bool hv_host_feat_stimer_volatile;
	private bool hv_host_feat_res;	// for alignment
	
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
		package ushort b_8000_0008_ax;
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
	private bool dbg_res;	// for alignment
	
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
	private bool security_res;	// for alignment
	
	// Misc.
	
	bool psn;	/// Processor Serial Number (Pentium III only)
	bool pcid;	/// PCID
	bool xtpr;	/// xTPR
	bool ia32_arch_capabilities;	/// IA32_ARCH_CAPABILITIES MSR
	bool fsgsbase;	/// FS and GS register base
	bool uintr;	/// User Interrupts
	
	// This padding is important for the __initZ function optimization.
	// When initiated, compilers (i.e., GDC) are more likely to 
	align(8) private ubyte padding;
}

private
immutable char[] CACHE_TYPE = [ // EAX[4:0] -- 0-31
	'?', 'D', 'I', 'U', '?', '?', '?', '?',
	'?', '?', '?', '?', '?', '?', '?', '?',
	'?', '?', '?', '?', '?', '?', '?', '?',
	'?', '?', '?', '?', '?', '?', '?', '?'
];

private
immutable const(char)*[] PROCESSOR_TYPE = [ "Original", "OverDrive", "Dual", "Reserved" ];

pragma(inline, false)
void asmcpuid(ref REGISTERS regs, uint level, uint sublevel = 0) {
	// I'd rather deal with a bit of prolog and epilog than slamming
	// my head into my desk violently trying to match every operating
	// system ABI, compiler versions, and major compilers.
	version (DMD) {
		version (X86) asm {
			mov EDI, regs;
			mov EAX, level;
			mov ECX, sublevel;
			cpuid;
			mov [EDI + regs.eax.offsetof], EAX;
			mov [EDI + regs.ebx.offsetof], EBX;
			mov [EDI + regs.ecx.offsetof], ECX;
			mov [EDI + regs.edx.offsetof], EDX;
		} else version (X86_64) asm {
			mov RDI, regs;
			mov EAX, level;
			mov ECX, sublevel;
			cpuid;
			mov [RDI + regs.eax.offsetof], EAX;
			mov [RDI + regs.ebx.offsetof], EBX;
			mov [RDI + regs.ecx.offsetof], ECX;
			mov [RDI + regs.edx.offsetof], EDX;
		}
	} else version (GDC) {
		asm {
			"cpuid"
			: "=a" (regs.eax), "=b" (regs.ebx), "=c" (regs.ecx), "=d" (regs.edx)
			: "a" (level), "c" (sublevel)
			;
		}
	} else version (LDC) {
		version (X86) asm {
			lea EDI, regs;
			mov EAX, level;
			mov ECX, sublevel;
			cpuid;
			mov [EDI + regs.eax.offsetof], EAX;
			mov [EDI + regs.ebx.offsetof], EBX;
			mov [EDI + regs.ecx.offsetof], ECX;
			mov [EDI + regs.edx.offsetof], EDX;
		} else version (X86_64) asm {
			lea RDI, regs;
			mov EAX, level;
			mov ECX, sublevel;
			cpuid;
			mov [RDI + regs.eax.offsetof], EAX;
			mov [RDI + regs.ebx.offsetof], EBX;
			mov [RDI + regs.ecx.offsetof], ECX;
			mov [RDI + regs.edx.offsetof], EDX;
		}
	} else static assert(0, "asmcpuid: Unsupported compiler");
}

/// Get CPU leaf levels.
/// Params: info = CPUINFO structure
//TODO: Move to a pointer
void getLeaves(ref CPUINFO info) {
	version (DMD) {
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
		} else version (X86_64) asm {
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
	} else version (GDC) {
		asm {
			"mov $0, %%eax\n\t"~
			"cpuid"
			: "=a" (info.max_leaf);
		}
		asm {
			"mov $0x40000000, %%eax\n\t"~
			"cpuid"
			: "=a" (info.max_virt_leaf);
		}
		asm {
			"mov $0x80000000, %%eax\n\t"~
			"cpuid"
			: "=a" (info.max_ext_leaf);
		}
	} else version (LDC) {
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
		} else version (X86_64) asm {
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
	} else static assert(0, "getLeaves: Unsupported compiler");
}

/// Fetch CPU vendor
void getVendor(ref CPUINFO info) {
	// PIC compatible
	size_t vendor_ptr = cast(size_t)&info.vendor;
	
	version (X86_64) {
		version (GDC) asm {
			// vendor string
			"mov %0, %%rdi\n\t"~
			"mov $0, %%eax\n\t"~
			"cpuid\n\t"~
			"mov %%ebx, (%%rdi)\n\t"~
			"mov %%edx, 4(%%rdi)\n\t"~
			"mov %%ecx, 8(%%rdi)"
			:
			: "m" (vendor_ptr);
		} else asm {
			// vendor string
			mov RDI, vendor_ptr;
			mov EAX, 0;
			cpuid;
			mov [RDI], EBX;
			mov [RDI+4], EDX;
			mov [RDI+8], ECX;
		}
	} else { // version X86
		version (GDC) asm {
			"mov %0, %%edi\n\t"~
			"mov $0, %%eax\n\t"~
			"cpuid\n"~
			"mov %%ebx, (%%edi)\n\t"~
			"mov %%edx, 4(%%edi)\n\t"~
			"mov %%ecx, 8(%%edi)"
			:
			: "m" (vendor_ptr);
		} else asm {
			mov EDI, vendor_ptr;
			mov EAX, 0;
			cpuid;
			mov [EDI], EBX;
			mov [EDI+4], EDX;
			mov [EDI+8], ECX;
		}
	}
	
	// Vendor string verification
	// If the rest of the string doesn't correspond, the id is unset
	switch (info.vendor32[0]) {
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
	default: // Unknown
		info.vendor_id = 0;
		return;
	}
	
	info.vendor_id = info.vendor32[0];
}

private
void getBrand(ref CPUINFO info) {
	
	version (DMD) {
		version (X86) asm {
			mov EDI, info;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [EDI + info.brand.offsetof], EAX;
			mov [EDI + info.brand.offsetof +  4], EBX;
			mov [EDI + info.brand.offsetof +  8], ECX;
			mov [EDI + info.brand.offsetof + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [EDI + info.brand.offsetof + 16], EAX;
			mov [EDI + info.brand.offsetof + 20], EBX;
			mov [EDI + info.brand.offsetof + 24], ECX;
			mov [EDI + info.brand.offsetof + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [EDI + info.brand.offsetof + 32], EAX;
			mov [EDI + info.brand.offsetof + 36], EBX;
			mov [EDI + info.brand.offsetof + 40], ECX;
			mov [EDI + info.brand.offsetof + 44], EDX;
		} else version (X86_64) asm {
			mov RDI, info;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [RDI + info.brand.offsetof], EAX;
			mov [RDI + info.brand.offsetof +  4], EBX;
			mov [RDI + info.brand.offsetof +  8], ECX;
			mov [RDI + info.brand.offsetof + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [RDI + info.brand.offsetof + 16], EAX;
			mov [RDI + info.brand.offsetof + 20], EBX;
			mov [RDI + info.brand.offsetof + 24], ECX;
			mov [RDI + info.brand.offsetof + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [RDI + info.brand.offsetof + 32], EAX;
			mov [RDI + info.brand.offsetof + 36], EBX;
			mov [RDI + info.brand.offsetof + 40], ECX;
			mov [RDI + info.brand.offsetof + 44], EDX;
		}
	} else version (GDC) {
		size_t p = cast(size_t)info.brand.ptr; // PIC, somehow
		
		version (X86) asm {
			"mov $0x80000002, %%eax\n\t"~
			"cpuid\n\t"
			;
		} else version (X86_64) asm {
			"mov %0, %%rdi\n\t"~
			"mov $0x80000002, %%eax\n\t"~
			"cpuid\n\t"~
			"mov %%eax, (%%rdi)\n\t"~
			"mov %%ebx, 4(%%rdi)\n\t"~
			"mov %%ecx, 8(%%rdi)\n\t"~
			"mov %%edx, 12(%%rdi)\n\t"~
			"mov $0x80000003, %%eax\n\t"~
			"cpuid\n\t"~
			"mov %%eax, 16(%%rdi)\n\t"~
			"mov %%ebx, 20(%%rdi)\n\t"~
			"mov %%ecx, 24(%%rdi)\n\t"~
			"mov %%edx, 28(%%rdi)\n\t"~
			"mov $0x80000004, %%eax\n\t"~
			"cpuid\n\t"~
			"mov %%eax, 32(%%rdi)\n\t"~
			"mov %%ebx, 36(%%rdi)\n\t"~
			"mov %%ecx, 40(%%rdi)\n\t"~
			"mov %%edx, 44(%%rdi)"
			:
			: "m" (p)
			;
		}
	} else version (LDC) {
		version (X86) asm {
			lea EDI, info;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [EDI + info.brand.offsetof], EAX;
			mov [EDI + info.brand.offsetof +  4], EBX;
			mov [EDI + info.brand.offsetof +  8], ECX;
			mov [EDI + info.brand.offsetof + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [EDI + info.brand.offsetof + 16], EAX;
			mov [EDI + info.brand.offsetof + 20], EBX;
			mov [EDI + info.brand.offsetof + 24], ECX;
			mov [EDI + info.brand.offsetof + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [EDI + info.brand.offsetof + 32], EAX;
			mov [EDI + info.brand.offsetof + 36], EBX;
			mov [EDI + info.brand.offsetof + 40], ECX;
			mov [EDI + info.brand.offsetof + 44], EDX;
		} else version (X86_64) asm {
			lea RDI, info;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [RDI + info.brand.offsetof], EAX;
			mov [RDI + info.brand.offsetof +  4], EBX;
			mov [RDI + info.brand.offsetof +  8], ECX;
			mov [RDI + info.brand.offsetof + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [RDI + info.brand.offsetof + 16], EAX;
			mov [RDI + info.brand.offsetof + 20], EBX;
			mov [RDI + info.brand.offsetof + 24], ECX;
			mov [RDI + info.brand.offsetof + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [RDI + info.brand.offsetof + 32], EAX;
			mov [RDI + info.brand.offsetof + 36], EBX;
			mov [RDI + info.brand.offsetof + 40], ECX;
			mov [RDI + info.brand.offsetof + 44], EDX;
		}
	} else static assert(0, "getBrand: Unsupported compiler");
}

/// Fetch CPU information.
/// Params: info = CPUINFO structure
// There are essentially 5 sections to this function:
// - Brand String
// - Normal leaf information
// - Paravirtualization leaf information
// - Extended leaf information
// - Cache information
void getInfo(ref CPUINFO info) {
	getVendor(info);
	getBrand(info);
	
	REGISTERS regs = void;
	
	//
	// Leaf 1H
	//
	
	asmcpuid(regs, 1);
	
	// EAX
	info.stepping    = regs.eax & 0xF;        // EAX[3:0]
	info.base_model  = regs.eax >>  4 &  0xF; // EAX[7:4]
	info.base_family = regs.eax >>  8 &  0xF; // EAX[11:8]
	info.type        = regs.eax >> 12 & 0b11; // EAX[13:12]
	info.type_string = PROCESSOR_TYPE[info.type];
	info.ext_model   = regs.eax >> 16 &  0xF; // EAX[19:16]
	info.ext_family  = cast(ubyte)(regs.eax >> 20); // EAX[27:20]
	
	switch (info.vendor_id) {
	case VENDOR_INTEL:
		info.family = info.base_family != 0 ?
			info.base_family :
			cast(ubyte)(info.ext_family + info.base_family);
		
		info.model = info.base_family == 6 || info.base_family == 0 ?
			cast(ubyte)((info.ext_model << 4) + info.base_model) :
			info.base_model; // DisplayModel = Model_ID;
		
		// ECX
		info.dtes64	= (regs.ecx & BIT!(2)) != 0;
		info.ds_cpl	= (regs.ecx & BIT!(4)) != 0;
		info.virt	= (regs.ecx & BIT!(5)) != 0;
		info.smx	= (regs.ecx & BIT!(6)) != 0;
		info.eist	= (regs.ecx & BIT!(7)) != 0;
		info.tm2	= (regs.ecx & BIT!(8)) != 0;
		info.cnxt_id	= (regs.ecx & BIT!(10)) != 0;
		info.sdbg	= (regs.ecx & BIT!(11)) != 0;
		info.xtpr	= (regs.ecx & BIT!(14)) != 0;
		info.pdcm	= (regs.ecx & BIT!(15)) != 0;
		info.pcid	= (regs.ecx & BIT!(17)) != 0;
		info.mca	= (regs.ecx & BIT!(18)) != 0;
		info.x2apic	= (regs.ecx & BIT!(21)) != 0;
		info.rdtsc_deadline	= (regs.ecx & BIT!(24)) != 0;
		
		// EDX
		info.psn	= (regs.edx & BIT!(18)) != 0;
		info.ds	= (regs.edx & BIT!(21)) != 0;
		info.acpi	= (regs.edx & BIT!(22)) != 0;
		info.ss	= (regs.edx & BIT!(27)) != 0;
		info.tm	= (regs.edx & BIT!(29)) != 0;
		info.pbe	= regs.edx >= BIT!(31);
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
	info.b_01_ebx = regs.ebx; // BrandIndex, CLFLUSHLineSize, MaxIDs, InitialAPICID
	
	// ECX
	info.sse3	= (regs.ecx & BIT!(0)) != 0;
	info.pclmulqdq	= (regs.ecx & BIT!(1)) != 0;
	info.monitor	= (regs.ecx & BIT!(3)) != 0;
	info.ssse3	= (regs.ecx & BIT!(9)) != 0;
	info.fma3	= (regs.ecx & BIT!(12)) != 0;
	info.cmpxchg16b	= (regs.ecx & BIT!(13)) != 0;
	info.sse41	= (regs.ecx & BIT!(15)) != 0;
	info.sse42	= (regs.ecx & BIT!(20)) != 0;
	info.movbe	= (regs.ecx & BIT!(22)) != 0;
	info.popcnt	= (regs.ecx & BIT!(23)) != 0;
	info.aes_ni	= (regs.ecx & BIT!(25)) != 0;
	info.xsave	= (regs.ecx & BIT!(26)) != 0;
	info.osxsave	= (regs.ecx & BIT!(27)) != 0;
	info.avx	= (regs.ecx & BIT!(28)) != 0;
	info.f16c	= (regs.ecx & BIT!(29)) != 0;
	info.rdrand	= (regs.ecx & BIT!(30)) != 0;
	
	// EDX
	info.fpu	= (regs.edx & BIT!(0)) != 0;
	info.vme	= (regs.edx & BIT!(1)) != 0;
	info.de	= (regs.edx & BIT!(2)) != 0;
	info.pse	= (regs.edx & BIT!(3)) != 0;
	info.rdtsc	= (regs.edx & BIT!(4)) != 0;
	info.rdmsr	= (regs.edx & BIT!(5)) != 0;
	info.pae	= (regs.edx & BIT!(6)) != 0;
	info.mce	= (regs.edx & BIT!(7)) != 0;
	info.cmpxchg8b	= (regs.edx & BIT!(8)) != 0;
	info.apic	= (regs.edx & BIT!(9)) != 0;
	info.sysenter	= (regs.edx & BIT!(11)) != 0;
	info.mtrr	= (regs.edx & BIT!(12)) != 0;
	info.pge	= (regs.edx & BIT!(13)) != 0;
	info.mca	= (regs.edx & BIT!(14)) != 0;
	info.cmov	= (regs.edx & BIT!(15)) != 0;
	info.pat	= (regs.edx & BIT!(16)) != 0;
	info.pse_36	= (regs.edx & BIT!(17)) != 0;
	info.clflush	= (regs.edx & BIT!(19)) != 0;
	info.mmx	= (regs.edx & BIT!(23)) != 0;
	info.fxsr	= (regs.edx & BIT!(24)) != 0;
	info.sse	= (regs.edx & BIT!(25)) != 0;
	info.sse2	= (regs.edx & BIT!(26)) != 0;
	info.htt	= (regs.edx & BIT!(28)) != 0;
	
	switch (info.vendor_id) {
	case VENDOR_AMD:
		if (info.htt)
			info.cores_logical = info.max_apic_id;
		break;
	default:
	}
	
	if (info.max_leaf < 5) goto L_VIRT;
	
	//
	// Leaf 5H
	//
	
	asmcpuid(regs, 5);
	
	info.mwait_min = cast(ushort)regs.eax;
	info.mwait_max = cast(ushort)regs.ebx;
	
	if (info.max_leaf < 6) goto L_VIRT;
	
	//
	// Leaf 6H
	//
	
	asmcpuid(regs, 6);
	
	switch (info.vendor_id) {
	case VENDOR_INTEL:
		info.turboboost	= (regs.eax & BIT!(1)) != 0;
		info.turboboost30	= (regs.eax & BIT!(14)) != 0;
		break;
	default:
	}
	
	info.arat	= (regs.eax & BIT!(2)) != 0;
	
	if (info.max_leaf < 7) goto L_VIRT;
	
	//
	// Leaf 7H
	//
	
	asmcpuid(regs, 7);
	
	switch (info.vendor_id) {
	case VENDOR_INTEL:
		// EBX
		info.sgx	= (regs.ebx & BIT!(2)) != 0;
		info.hle	= (regs.ebx & BIT!(4)) != 0;
		info.invpcid	= (regs.ebx & BIT!(10)) != 0;
		info.rtm	= (regs.ebx & BIT!(11)) != 0;
		info.avx512f	= (regs.ebx & BIT!(16)) != 0;
		info.smap	= (regs.ebx & BIT!(20)) != 0;
		info.avx512er	= (regs.ebx & BIT!(27)) != 0;
		info.avx512pf	= (regs.ebx & BIT!(26)) != 0;
		info.avx512cd	= (regs.ebx & BIT!(28)) != 0;
		info.avx512dq	= (regs.ebx & BIT!(17)) != 0;
		info.avx512bw	= (regs.ebx & BIT!(30)) != 0;
		info.avx512_ifma	= (regs.ebx & BIT!(21)) != 0;
		info.avx512_vbmi	= regs.ebx >= BIT!(31);
		// ECX
		info.avx512vl	= (regs.ecx & BIT!(1)) != 0;
		info.pku	= (regs.ecx & BIT!(3)) != 0;
		info.fsrepmov	= (regs.ecx & BIT!(4)) != 0;
		info.waitpkg	= (regs.ecx & BIT!(5)) != 0;
		info.avx512_vbmi2	= (regs.ecx & BIT!(6)) != 0;
		info.cet_ss	= (regs.ecx & BIT!(7)) != 0;
		info.avx512_gfni	= (regs.ecx & BIT!(8)) != 0;
		info.avx512_vaes	= (regs.ecx & BIT!(9)) != 0;
		info.avx512_vnni	= (regs.ecx & BIT!(11)) != 0;
		info.avx512_bitalg	= (regs.ecx & BIT!(12)) != 0;
		info.avx512_vpopcntdq	= (regs.ecx & BIT!(14)) != 0;
		info._5pl	= (regs.ecx & BIT!(16)) != 0;
		info.cldemote	= (regs.ecx & BIT!(25)) != 0;
		info.movdiri	= (regs.ecx & BIT!(27)) != 0;
		info.movdir64b	= (regs.ecx & BIT!(28)) != 0;
		info.enqcmd	= (regs.ecx & BIT!(29)) != 0;
		// EDX
		info.avx512_4vnniw	= (regs.edx & BIT!(2)) != 0;
		info.avx512_4fmaps	= (regs.edx & BIT!(3)) != 0;
		info.uintr	= (regs.edx & BIT!(5)) != 0;
		info.avx512_vp2intersect	= (regs.edx & BIT!(8)) != 0;
		info.md_clear	= (regs.edx & BIT!(10)) != 0;
		info.serialize	= (regs.edx & BIT!(14)) != 0;
		info.tsxldtrk	= (regs.edx & BIT!(16)) != 0;
		info.pconfig	= (regs.edx & BIT!(18)) != 0;
		info.cet_ibt	= (regs.edx & BIT!(20)) != 0;
		info.amx_bf16	= (regs.edx & BIT!(22)) != 0;
		info.amx	= (regs.edx & BIT!(24)) != 0;
		info.amx_int8	= (regs.edx & BIT!(25)) != 0;
		info.ibrs = (regs.edx & BIT!(26)) != 0;
		info.stibp	= (regs.edx & BIT!(27)) != 0;
		info.l1d_flush	= (regs.edx & BIT!(28)) != 0;
		info.ia32_arch_capabilities	= (regs.edx & BIT!(29)) != 0;
		info.ssbd	= regs.edx >= BIT!(31);
		break;
	default:
	}

	// b
	info.fsgsbase	= (regs.ebx & BIT!(0)) != 0;
	info.bmi1	= (regs.ebx & BIT!(3)) != 0;
	info.avx2	= (regs.ebx & BIT!(5)) != 0;
	info.smep	= (regs.ebx & BIT!(7)) != 0;
	info.bmi2	= (regs.ebx & BIT!(8)) != 0;
	info.rdseed	= (regs.ebx & BIT!(18)) != 0;
	info.adx	= (regs.ebx & BIT!(19)) != 0;
	info.clflushopt	= (regs.ebx & BIT!(23)) != 0;
	info.sha	= (regs.ebx & BIT!(29)) != 0;
	// c
	info.rdpid	= (regs.ecx & BIT!(22)) != 0;
	
	//
	// Leaf 7H(ECX=01h)
	//
	
	switch (info.vendor_id) {
	case VENDOR_INTEL:
		asmcpuid(regs, 7, 1);
		// a
		info.avx512_bf16	= (regs.eax & BIT!(5)) != 0;
		info.lam	= (regs.eax & BIT!(26)) != 0;
		break;
	default:
	}
	
	if (info.max_leaf < 0xD) goto L_VIRT;
	
	//
	// Leaf DH
	//
	
	switch (info.vendor_id) {
	case VENDOR_INTEL:
		asmcpuid(regs, 0xd);
		info.amx_xtilecfg	= (regs.eax & BIT!(17)) != 0;
		info.amx_xtiledata	= (regs.eax & BIT!(18)) != 0;
		break;
	default:
	}
	
	//
	// Leaf DH(ECX=01h)
	//

	switch (info.vendor_id) {
	case VENDOR_INTEL:
		asmcpuid(regs, 0xd, 1);
		info.amx_xfd	= (regs.eax & BIT!(18)) != 0;
		break;
	default:
	}
	
	if (info.max_virt_leaf < 0x4000_0000) goto L_VIRT;
	
	//
	// Leaf 4000_000H
	//
	
L_VIRT:
	//TODO: Consider moving this to a function
	// PIC compatible
	size_t virt_vendor_ptr = cast(size_t)&info.virt_vendor;
	version (X86_64) {
		version (GDC) asm {
			"mov %0, %%rdi\n\t"~
			"mov $0x40000000, %%eax\n\t"~
			"cpuid\n\t"~
			"mov %%ebx, (%%rdi)\n\t"~
			"mov %%ecx, 4(%%rdi)\n\t"~
			"mov %%edx, 8(%%rdi)"
			:
			: "m" (virt_vendor_ptr);
		} else asm {
			mov RDI, virt_vendor_ptr;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [RDI], EBX;
			mov [RDI+4], ECX;
			mov [RDI+8], EDX;
		}
	} else {
		version (GDC) asm {
			"mov %0, %%edi\n\t"~
			"mov $0x40000000, %%eax\n\t"~
			"cpuid\n"~
			"mov %%ebx, (%%edi)\n\t"~
			"mov %%ecx, 4(%%edi)\n\t"~
			"mov %%edx, 8(%%edi)"
			:
			: "m" (virt_vendor_ptr);
		} else asm {
			mov EDI, virt_vendor_ptr;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [EDI], EBX;
			mov [EDI+4], ECX;
			mov [EDI+8], EDX;
		}
	}
	
	// Paravirtual vendor string verification
	// If the rest of the string doesn't correspond, the id is unset
	switch (info.virt_vendor32[0]) {
	case VIRT_VENDOR_KVM:	// "KVMKVMKVM\0\0\0"
		if (info.virt_vendor32[1] != ID!("VMKV")) goto default;
		if (info.virt_vendor32[2] != ID!("M\0\0\0")) goto default;
		info.virt_vendor_id = VIRT_VENDOR_KVM;
		break;
	case VIRT_VENDOR_VBOX_HV:	// "VBoxVBoxVBox"
		if (info.virt_vendor32[1] != ID!("VBox")) goto default;
		if (info.virt_vendor32[2] != ID!("VBox")) goto default;
		info.virt_vendor_id = VIRT_VENDOR_VBOX_HV;
		break;
	default:
		info.virt_vendor_id = 0;
	}

	if (info.max_virt_leaf < 0x4000_0001) goto L_EXTENDED;
	
	//
	// Leaf 4000_0001H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_KVM:
		asmcpuid(regs, 0x4000_0001);
		info.kvm_feature_clocksource	= (regs.eax & BIT!(0)) != 0;
		info.kvm_feature_nop_io_delay	= (regs.eax & BIT!(1)) != 0;
		info.kvm_feature_mmu_op	= (regs.eax & BIT!(2)) != 0;
		info.kvm_feature_clocksource2	= (regs.eax & BIT!(3)) != 0;
		info.kvm_feature_async_pf	= (regs.eax & BIT!(4)) != 0;
		info.kvm_feature_steal_time	= (regs.eax & BIT!(5)) != 0;
		info.kvm_feature_pv_eoi	= (regs.eax & BIT!(6)) != 0;
		info.kvm_feature_pv_unhault	= (regs.eax & BIT!(7)) != 0;
		info.kvm_feature_pv_tlb_flush	= (regs.eax & BIT!(9)) != 0;
		info.kvm_feature_async_pf_vmexit	= (regs.eax & BIT!(10)) != 0;
		info.kvm_feature_pv_send_ipi	= (regs.eax & BIT!(11)) != 0;
		info.kvm_feature_pv_poll_control	= (regs.eax & BIT!(12)) != 0;
		info.kvm_feature_pv_sched_yield	= (regs.eax & BIT!(13)) != 0;
		info.kvm_feature_clocsource_stable_bit	= (regs.eax & BIT!(24)) != 0;
		info.kvm_hint_realtime	= (regs.edx & BIT!(0)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0002) goto L_EXTENDED;
	
	//
	// Leaf 4000_002H
	//

	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		asmcpuid(regs, 0x4000_0002);
		info.vbox_guest_minor	= cast(ubyte)(regs.eax >> 24);
		info.vbox_guest_service	= cast(ubyte)(regs.eax >> 16);
		info.vbox_guest_build	= cast(ushort)regs.eax;
		info.vbox_guest_opensource	= regs.edx >= BIT!(31);
		info.vbox_guest_vendor_id	= (regs.edx >> 16) & 0xFFF;
		info.vbox_guest_os	= cast(ubyte)(regs.edx >> 8);
		info.vbox_guest_major	= cast(ubyte)regs.edx;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0003) goto L_EXTENDED;
	
	//
	// Leaf 4000_0003H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		asmcpuid(regs, 0x4000_0003);
		info.hv_base_feat_vp_runtime_msr	= (regs.eax & BIT!(0)) != 0;
		info.hv_base_feat_part_time_ref_count_msr	= (regs.eax & BIT!(1)) != 0;
		info.hv_base_feat_basic_synic_msrs	= (regs.eax & BIT!(2)) != 0;
		info.hv_base_feat_stimer_msrs	= (regs.eax & BIT!(3)) != 0;
		info.hv_base_feat_apic_access_msrs	= (regs.eax & BIT!(4)) != 0;
		info.hv_base_feat_hypercall_msrs	= (regs.eax & BIT!(5)) != 0;
		info.hv_base_feat_vp_id_msr	= (regs.eax & BIT!(6)) != 0;
		info.hv_base_feat_virt_sys_reset_msr	= (regs.eax & BIT!(7)) != 0;
		info.hv_base_feat_stat_pages_msr	= (regs.eax & BIT!(8)) != 0;
		info.hv_base_feat_part_ref_tsc_msr	= (regs.eax & BIT!(9)) != 0;
		info.hv_base_feat_guest_idle_state_msr	= (regs.eax & BIT!(10)) != 0;
		info.hv_base_feat_timer_freq_msrs	= (regs.eax & BIT!(11)) != 0;
		info.hv_base_feat_debug_msrs	= (regs.eax & BIT!(12)) != 0;
		info.hv_part_flags_create_part	= (regs.ebx & BIT!(0)) != 0;
		info.hv_part_flags_access_part_id	= (regs.ebx & BIT!(1)) != 0;
		info.hv_part_flags_access_memory_pool	= (regs.ebx & BIT!(2)) != 0;
		info.hv_part_flags_adjust_msg_buffers	= (regs.ebx & BIT!(3)) != 0;
		info.hv_part_flags_post_msgs	= (regs.ebx & BIT!(4)) != 0;
		info.hv_part_flags_signal_events	= (regs.ebx & BIT!(5)) != 0;
		info.hv_part_flags_create_port	= (regs.ebx & BIT!(6)) != 0;
		info.hv_part_flags_connect_port	= (regs.ebx & BIT!(7)) != 0;
		info.hv_part_flags_access_stats	= (regs.ebx & BIT!(8)) != 0;
		info.hv_part_flags_debugging	= (regs.ebx & BIT!(11)) != 0;
		info.hv_part_flags_cpu_mgmt	= (regs.ebx & BIT!(12)) != 0;
		info.hv_part_flags_cpu_profiler	= (regs.ebx & BIT!(13)) != 0;
		info.hv_part_flags_expanded_stack_walk	= (regs.ebx & BIT!(14)) != 0;
		info.hv_part_flags_access_vsm	= (regs.ebx & BIT!(16)) != 0;
		info.hv_part_flags_access_vp_regs	= (regs.ebx & BIT!(17)) != 0;
		info.hv_part_flags_extended_hypercalls	= (regs.ebx & BIT!(20)) != 0;
		info.hv_part_flags_start_vp	= (regs.ebx & BIT!(21)) != 0;
		info.hv_pm_max_cpu_power_state_c0	= (regs.ecx & BIT!(0)) != 0;
		info.hv_pm_max_cpu_power_state_c1	= (regs.ecx & BIT!(1)) != 0;
		info.hv_pm_max_cpu_power_state_c2	= (regs.ecx & BIT!(2)) != 0;
		info.hv_pm_max_cpu_power_state_c3	= (regs.ecx & BIT!(3)) != 0;
		info.hv_pm_hpet_reqd_for_c3	= (regs.ecx & BIT!(4)) != 0;
		info.hv_misc_feat_mwait	= (regs.eax & BIT!(0)) != 0;
		info.hv_misc_feat_guest_debugging	= (regs.eax & BIT!(1)) != 0;
		info.hv_misc_feat_perf_mon	= (regs.eax & BIT!(2)) != 0;
		info.hv_misc_feat_pcpu_dyn_part_event	= (regs.eax & BIT!(3)) != 0;
		info.hv_misc_feat_xmm_hypercall_input	= (regs.eax & BIT!(4)) != 0;
		info.hv_misc_feat_guest_idle_state	= (regs.eax & BIT!(5)) != 0;
		info.hv_misc_feat_hypervisor_sleep_state	= (regs.eax & BIT!(6)) != 0;
		info.hv_misc_feat_query_numa_distance	= (regs.eax & BIT!(7)) != 0;
		info.hv_misc_feat_timer_freq	= (regs.eax & BIT!(8)) != 0;
		info.hv_misc_feat_inject_synmc_xcpt	= (regs.eax & BIT!(9)) != 0;
		info.hv_misc_feat_guest_crash_msrs	= (regs.eax & BIT!(10)) != 0;
		info.hv_misc_feat_debug_msrs	= (regs.eax & BIT!(11)) != 0;
		info.hv_misc_feat_npiep1	= (regs.eax & BIT!(12)) != 0;
		info.hv_misc_feat_disable_hypervisor	= (regs.eax & BIT!(13)) != 0;
		info.hv_misc_feat_ext_gva_range_for_flush_va_list	= (regs.eax & BIT!(14)) != 0;
		info.hv_misc_feat_hypercall_output_xmm	= (regs.eax & BIT!(15)) != 0;
		info.hv_misc_feat_sint_polling_mode	= (regs.eax & BIT!(17)) != 0;
		info.hv_misc_feat_hypercall_msr_lock	= (regs.eax & BIT!(18)) != 0;
		info.hv_misc_feat_use_direct_synth_msrs	= (regs.eax & BIT!(19)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0004) goto L_EXTENDED;
	
	//
	// Leaf 4000_0004H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		asmcpuid(regs, 0x4000_0004);
		info.hv_hint_hypercall_for_process_switch	= (regs.eax & BIT!(0)) != 0;
		info.hv_hint_hypercall_for_tlb_flush	= (regs.eax & BIT!(1)) != 0;
		info.hv_hint_hypercall_for_tlb_shootdown	= (regs.eax & BIT!(2)) != 0;
		info.hv_hint_msr_for_apic_access	= (regs.eax & BIT!(3)) != 0;
		info.hv_hint_msr_for_sys_reset	= (regs.eax & BIT!(4)) != 0;
		info.hv_hint_relax_time_checks	= (regs.eax & BIT!(5)) != 0;
		info.hv_hint_dma_remapping	= (regs.eax & BIT!(6)) != 0;
		info.hv_hint_interrupt_remapping	= (regs.eax & BIT!(7)) != 0;
		info.hv_hint_x2apic_msrs	= (regs.eax & BIT!(8)) != 0;
		info.hv_hint_deprecate_auto_eoi	= (regs.eax & BIT!(9)) != 0;
		info.hv_hint_synth_cluster_ipi_hypercall	= (regs.eax & BIT!(10)) != 0;
		info.hv_hint_ex_proc_masks_interface	= (regs.eax & BIT!(11)) != 0;
		info.hv_hint_nested_hyperv	= (regs.eax & BIT!(12)) != 0;
		info.hv_hint_int_for_mbec_syscalls	= (regs.eax & BIT!(13)) != 0;
		info.hv_hint_nested_enlightened_vmcs_interface	= (regs.eax & BIT!(14)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0006) goto L_EXTENDED;
	
	//
	// Leaf 4000_0006H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_HV:
		asmcpuid(regs, 0x4000_0006);
		info.hv_host_feat_avic	= (regs.eax & BIT!(0)) != 0;
		info.hv_host_feat_msr_bitmap	= (regs.eax & BIT!(1)) != 0;
		info.hv_host_feat_perf_counter	= (regs.eax & BIT!(2)) != 0;
		info.hv_host_feat_nested_paging	= (regs.eax & BIT!(3)) != 0;
		info.hv_host_feat_dma_remapping	= (regs.eax & BIT!(4)) != 0;
		info.hv_host_feat_interrupt_remapping	= (regs.eax & BIT!(5)) != 0;
		info.hv_host_feat_mem_patrol_scrubber	= (regs.eax & BIT!(6)) != 0;
		info.hv_host_feat_dma_prot_in_use	= (regs.eax & BIT!(7)) != 0;
		info.hv_host_feat_hpet_requested	= (regs.eax & BIT!(8)) != 0;
		info.hv_host_feat_stimer_volatile	= (regs.eax & BIT!(9)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0010) goto L_EXTENDED;
	
	//
	// Leaf 4000_0010H
	//
	
	switch (info.virt_vendor_id) {
	case VIRT_VENDOR_VBOX_MIN: // VBox Minimal
		asmcpuid(regs, 0x4000_0010);
		info.vbox_tsc_freq_khz = regs.eax;
		info.vbox_apic_freq_khz = regs.ebx;
		break;
	default:
	}

	//
	// Leaf 8000_0001H
	//
	
L_EXTENDED:
	asmcpuid(regs, 0x8000_0001);
	
	switch (info.vendor_id) {
	case VENDOR_AMD:
		info.virt	= (regs.ecx & BIT!(2)) != 0;
		info.x2apic	= (regs.ecx & BIT!(3)) != 0;
		info.sse4a	= (regs.ecx & BIT!(6)) != 0;
		info.xop	= (regs.ecx & BIT!(11)) != 0;
		info.skinit	= (regs.ecx & BIT!(12)) != 0;
		info.fma4	= (regs.ecx & BIT!(16)) != 0;
		info.tbm	= (regs.ecx & BIT!(21)) != 0;
		info.monitorx	= (regs.ecx & BIT!(29)) != 0;
		info.mmxext	= (regs.edx & BIT!(22)) != 0;
		info._3dnowext	= (regs.edx & BIT!(30)) != 0;
		info._3dnow	= regs.edx >= BIT!(31);
		break;
	default:
	}
	
	info.lahf64	= (regs.ecx & BIT!(0)) != 0;
	info.lzcnt	= (regs.ecx & BIT!(5)) != 0;
	info.prefetchw	= (regs.ecx & BIT!(8)) != 0;
	info.syscall	= (regs.edx & BIT!(11)) != 0;
	info.nx	= (regs.edx & BIT!(20)) != 0;
	info.page1gb	= (regs.edx & BIT!(26)) != 0;
	info.rdtscp	= (regs.edx & BIT!(27)) != 0;
	info.x86_64	= (regs.edx & BIT!(29)) != 0;
	
	if (info.max_ext_leaf < 0x8000_0007) goto L_CACHE_INFO;
	
	//
	// Leaf 8000_0007H
	//
	
	asmcpuid(regs, 0x8000_0007);
	
	switch (info.vendor_id) {
	case VENDOR_INTEL:
		info.rdseed	= (regs.ebx & BIT!(28)) != 0;
		break;
	case VENDOR_AMD:
		info.tm	= (regs.edx & BIT!(4)) != 0;
		info.turboboost	= (regs.edx & BIT!(9)) != 0;
		break;
	default:
	}
	
	info.rdtsc_invariant	= (regs.edx & BIT!(8)) != 0;
	
	if (info.max_ext_leaf < 0x8000_0008) goto L_CACHE_INFO;
	
	//
	// Leaf 8000_0008H
	//
	
	asmcpuid(regs, 0x8000_0008);
	
	switch (info.vendor_id) {
	case VENDOR_INTEL:
		info.wbnoinvd	= (regs.ebx & BIT!(9)) != 0;
		break;
	case VENDOR_AMD:
		info.ibpb	= (regs.ebx & BIT!(12)) != 0;
		info.ibrs	= (regs.ebx & BIT!(14)) != 0;
		info.stibp	= (regs.ebx & BIT!(15)) != 0;
		info.ibrs_on	= (regs.ebx & BIT!(16)) != 0;
		info.stibp_on	= (regs.ebx & BIT!(17)) != 0;
		info.ibrs_pref	= (regs.ebx & BIT!(18)) != 0;
		info.ssbd	= (regs.ebx & BIT!(24)) != 0;
		info.cores_logical	= (cast(ubyte)regs.ecx) + 1;
		break;
	default:
	}

	info.b_8000_0008_ax = cast(ushort)regs.eax; // info.addr_phys_bits, info.addr_line_bits

	if (info.max_ext_leaf < 0x8000_000A) goto L_CACHE_INFO;
	
	//
	// Leaf 8000_000AH
	//
	
	asmcpuid(regs, 0x8000_000A);
	
	switch (info.vendor_id) {
	case VENDOR_AMD:
		info.virt_version	= cast(ubyte)regs.eax; // EAX[7:0]
		info.apivc	= (regs.edx & BIT!(13)) != 0;
		break;
	default:
	}

	//if (info.max_ext_leaf < ...) goto L_CACHE_INFO;
	
L_CACHE_INFO:
	// Cache information
	// - done at the very end since we may need prior information
	//   - e.g. amd cpuid.8000_0008h
	// - maxleaf < 4 is too old/rare these days (es. for D programs)
	
	info.cache_level = 0;
	CACHEINFO *ca = cast(CACHEINFO*)info.cache;
	
	ushort sc = void;	/// raw cores shared across cache level
	ushort crshrd = void;	/// actual count of shared cores
	ubyte type = void;
	switch (info.vendor_id) {
	case VENDOR_INTEL:
		asmcpuid(regs, 4, info.cache_level);
		
		type = regs.eax & 31; // EAX[4:0]
		if (type == 0) break;
		if (info.cache_level >= DDCPUID_CACHE_MAX) break;
		
		ca.type = CACHE_TYPE[type];
		ca.level = cast(ubyte)((regs.eax >> 5) & 7);
		ca.linesize = cast(ubyte)((regs.ebx & 0x7FF) + 1);
		ca.partitions = cast(ubyte)(((regs.ebx >> 12) & 0x7FF) + 1);
		ca.ways = cast(ubyte)((regs.ebx >> 22) + 1);
		ca.sets = cast(ushort)(regs.ecx + 1);
		if (regs.eax & BIT!(8)) ca.feat = 1;
		if (regs.eax & BIT!(9)) ca.feat |= BIT!(1);
		if (regs.edx & BIT!(0)) ca.feat |= BIT!(2);
		if (regs.edx & BIT!(1)) ca.feat |= BIT!(3);
		if (regs.edx & BIT!(2)) ca.feat |= BIT!(4);
		ca.size = (ca.sets * ca.linesize * ca.partitions * ca.ways) >> 10;
		
		info.cores_logical = (regs.eax >> 26) + 1;	// EAX[31:26]
		crshrd = (((regs.eax >> 14) & 2047) + 1);	// EAX[25:14]
		sc = cast(ushort)(info.cores_logical / crshrd); // cast for ldc 0.17.1
		ca.sharedCores = sc ? sc : 1;
		
		++info.cache_level; ++ca;
		goto case VENDOR_INTEL;
	case VENDOR_AMD:
		if (info.max_ext_leaf < 0x8000_001D)
			goto L_CACHE_AMD_LEGACY;
		
		//
		// AMD newer cache method
		//
		
L_CACHE_AMD_EXT_1DH: // Almost the same as Intel's
		asmcpuid(regs, 0x8000_001D, info.cache_level);
		
		type = regs.eax & 31; // EAX[4:0]
		if (type == 0) break;
		if (info.cache_level >= DDCPUID_CACHE_MAX) break;
		
		ca.type = CACHE_TYPE[type];
		ca.level = cast(ubyte)((regs.eax >> 5) & 7);
		ca.linesize = cast(ubyte)((regs.ebx & 0x7FF) + 1);
		ca.partitions = cast(ubyte)(((regs.ebx >> 12) & 0x7FF) + 1);
		ca.ways = cast(ubyte)((regs.ebx >> 22) + 1);
		ca.sets = cast(ushort)(regs.ecx + 1);
		if (regs.eax & BIT!(8)) ca.feat = 1;
		if (regs.eax & BIT!(9)) ca.feat |= BIT!(1);
		if (regs.edx & BIT!(0)) ca.feat |= BIT!(2);
		if (regs.edx & BIT!(1)) ca.feat |= BIT!(3);
		ca.size = (ca.sets * ca.linesize * ca.partitions * ca.ways) >> 10;
		
		crshrd = (((regs.eax >> 14) & 2047) + 1);	// EAX[25:14]
		sc = cast(ushort)(info.cores_logical / crshrd); // cast for ldc 0.17.1
		ca.sharedCores = sc ? sc : 1;
		
		++info.cache_level; ++ca;
		goto L_CACHE_AMD_EXT_1DH;
		
		//
		// AMD legacy cache
		//
		
L_CACHE_AMD_LEGACY:
		asmcpuid(regs, 0x8000_0005);
		
		info.cache[0].level = 1; // L1
		info.cache[0].type = 'D'; // data
		info.cache[0].__bundle1 = regs.ecx;
		info.cache[0].size = info.cache[0]._amdsize;
		info.cache[1].level = 1; // L1
		info.cache[1].type = 'I'; // instructions
		info.cache[1].__bundle1 = regs.edx;
		info.cache[1].size = info.cache[1]._amdsize;
		
		info.cache_level = 2;
		
		if (info.max_ext_leaf < 0x8000_0006)
			break; // No L2/L3
		
		// See Table E-4. L2/L3 Cache and TLB Associativity Field Encoding
		static immutable ubyte[16] _amd_cache_ways = [
			// 7h is reserved
			// 9h mentions 8000_001D but that's already supported
			0, 1, 2, 3, 4, 6, 8, 0, 16, 0, 32, 48, 64, 96, 128, 255
		];
		
		asmcpuid(regs, 0x8000_0006);
		
		ubyte _amd_ways_l2 = (regs.ecx >> 12) & 15;
		if (_amd_ways_l2) {
			info.cache[2].level = 2; // L2
			info.cache[2].type = 'U'; // unified
			info.cache[2].ways = _amd_cache_ways[_amd_ways_l2];
			info.cache[2].size = regs.ecx >> 16;
			info.cache[2].sets = (regs.ecx >> 8) & 7;
			info.cache[2].linesize = cast(ubyte)regs.ecx;
			
			info.cache_level = 3;
			
			ubyte _amd_ways_l3 = (regs.edx >> 12) & 15;
			if (_amd_ways_l3) {
				info.cache[3].level = 3;  // L3
				info.cache[3].type = 'U'; // unified
				info.cache[3].ways = _amd_cache_ways[_amd_ways_l3];
				info.cache[3].size = ((regs.edx >> 18) + 1) * 512;
				info.cache[3].sets = (regs.edx >> 8) & 7;
				info.cache[3].linesize = cast(ubyte)(regs.edx & 0x7F);
				
				info.cache_level = 4;
			}
		}
		break;
	default:
	}
}

debug pragma(msg, "* CPUINFO.sizeof: ", CPUINFO.sizeof);
debug pragma(msg, "* CACHE.sizeof: ", CACHEINFO.sizeof);