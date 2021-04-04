/**
 * x86 CPU Identification tool
 *
 * This was initially used internally, so it's pretty unfriendly.
 *
 * The best way to use this module would be:
 * ---
 * CPUINFO info = void;
 * getLeaves(info);	// Get maximum CPUID leaves (first mandatory step)
 * getVendor(info);	// Get vendor string (second mandatory step)
 * getInfo(info);	// Fill CPUINFO structure (optional)
 * getLogicalCores(info);	// Get number of cores (optional)
 * ---
 *
 * Then checking the corresponding field:
 * ---
 * if (info.amx_xfd) {
 *   // ...
 * }
 * ---
 *
 * Check the CPUINFO structure for more information.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: See LICENSE
 * License: MIT
 */
module ddcpuid;

//TODO: Consider making a template that populates registers on-demand
// GAS syntax reminder
// asm { "asm;\n" : "constraint" output : "constraint" input : clobbers }

@system:
extern (C):
__gshared:

version (X86) enum DDCPUID_PLATFORM = "x86"; /// Target platform
else version (X86_64) enum DDCPUID_PLATFORM = "amd64"; /// Target platform
else static assert(0, "ddcpuid is only supported on x86 platforms");

version (GNU) pragma(msg, "warning: GDC support is experimental");

enum DDCPUID_VERSION = "0.18.0";	/// Library version

/// Make a bit mask of one bit at n position
private
template BIT(int n) if (n <= 31) { enum uint BIT = 1 << n; }

/// Vendor ID template
private
template ID(char[4] c) {
	enum uint ID = c[0] | c[1] << 8 | c[2] << 16 | c[3] << 24;
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

/// CPU cache entry
struct CACHEINFO {
	union {
		uint __bundle1;
		struct {
			ubyte linesize; /// Size of the line in bytes
			ubyte partitions;	/// Number of partitions
			ubyte ways;	/// Number of ways per line
			ubyte _amdsize;	/// (Legacy AMD) Size in KiB
		}
	}
	/// Cache Size in bytes.
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
	char type;	/// Type entry character: 'D'=Data, 'I'=Instructions, 'U'=Unified
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
	
	union { align(1):
		char[12] vendor;	/// Vendor String
		uint[3] vendor32;	/// Vendor 32-bit parts
	}
	uint vendor_id;	/// Vendor "ID"
	char[48] brand;	/// Processor Brand String
	
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
			ubyte brand_index;	/// Processor brand index. No longer used.
			ubyte clflush_linesize;	/// Linesize of CLFLUSH in bits
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
	
	//TODO: Consider bit flags
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
	
	//TODO: Consider bit flags
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
	
	align(8) private ubyte padding;
}

private
immutable char[] CACHE_TYPE = [ '?', 'D', 'I', 'U', '?', '?', '?', '?' ];

private
const(char)*[] PROCESSOR_TYPE = [ "Original", "OverDrive", "Dual", "Reserved" ];

/// (Internal) Reset CPUINFO fields.
/// This is called in the `getInfo` function. It unsets all fields after
/// the vendor string.
/// Params: info = CPUINFO structure
private
void clear(ref CPUINFO info) {
	//TODO: A "smart" unset would be aware of the maximum leaf
	enum HDRSZ = (	// stopper
		(4 * 3) +	// leaf/virtleaf/extleaf
		(12) +	// Vendor string
		(4)	// Vendor ID
		) / size_t.sizeof;
	/*size_t left = (CPUINFO.sizeof / size_t.sizeof) - 1;
	for (size_t *p = cast(size_t*)&info; left > STOP; --left)
		p[left] = 0;*/
	size_t *p = cast(size_t*)&info.brand;
	const size_t end = (CPUINFO.sizeof - HDRSZ) / size_t.sizeof;
	for (size_t i; i < end; ++i)
		p[i] = 0;
}

/// Get CPU leafs
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

/// Fetch CPU vendor
void getVendor(ref CPUINFO info) {
	// PIC compatible
	size_t vendor_ptr = cast(size_t)&info.vendor;
	
	version (X86_64) {
		version (GNU) asm {
			// vendor string
			"mov %0, %%rdi\n"~
			"mov $0, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n"~
			"mov %%edx, 4(%%rdi)\n"~
			"mov %%ecx, 8(%%rdi)\n"
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
		version (GNU) asm {
			"mov %0, %%edi\n"~
			"mov $0, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, disp(%%edi)\n"~
			"mov %%edx, disp(%%edi+4)\n"~
			"mov %%ecx, disp(%%edi+8)\n"
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

/// Fetch CPU information.
/// Params: info = CPUINFO structure
// There are essentially 5 sections to this function:
// - Brand String
// - Normal leaf information
// - Paravirtualization leaf information
// - Extended leaf information
// - Cache information
void getInfo(ref CPUINFO info) {
	clear(info); // failsafe
	
	// PIC compatible
	size_t brand_ptr = cast(size_t)&info.brand;
	size_t virt_vendor_ptr = void;

	// Get processor brand string
	version (X86_64) {
		version (GNU) asm {
			"mov %0, %%rdi\n"~
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
			: "m" (brand_ptr);
		} else asm {
			mov RDI, brand_ptr;
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
			: "m" (brand_ptr);
		} else asm {
			mov EDI, brand_ptr;
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
	
	uint a = void, b = void, c = void, d = void; // EAX to EDX
	
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
	info.type_string = PROCESSOR_TYPE[info.type];
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
	
	if (info.max_leaf < 5) goto L_VIRT;
	
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
	
	if (info.max_leaf < 6) goto L_VIRT;
	
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

	if (info.max_leaf < 7) goto L_VIRT;
	
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
	
	if (info.max_leaf < 0xD) goto L_VIRT;
	
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
	
	if (info.max_virt_leaf < 0x4000_0000) goto L_VIRT;
	
	//
	// Leaf 4000_000H
	//

L_VIRT:
	// PIC compatible
	virt_vendor_ptr = cast(size_t)&info.virt_vendor;
	version (X86_64) {
		version (GNU) asm {
			"mov %0, %%rdi\n"~
			"mov $0x40000000, %%eax\n"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n"~
			"mov %%ecx, 4(%%rdi)\n"~
			"mov %%edx, 8(%%rdi)\n"
			: "=m" (virt_vendor_ptr);
		} else asm {
			mov RDI, virt_vendor_ptr;
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
		info.virt_vendor_id = 0;
	}

	if (info.max_virt_leaf < 0x4000_0001) goto L_EXTENDED;
	
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

	if (info.max_virt_leaf < 0x4000_0002) goto L_VIRT;
	
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

	if (info.max_virt_leaf < 0x4000_0003) goto L_EXTENDED;
	
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

	if (info.max_virt_leaf < 0x4000_0004) goto L_EXTENDED;
	
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

	if (info.max_virt_leaf < 0x4000_0006) goto L_EXTENDED;
	
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

	if (info.max_virt_leaf < 0x4000_0010) goto L_EXTENDED;
	
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

L_EXTENDED:
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

	if (info.max_ext_leaf < 0x8000_0007) goto L_CACHE_INFO;
	
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

	if (info.max_ext_leaf < 0x8000_0008) goto L_CACHE_INFO;
	
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

	if (info.max_ext_leaf < 0x8000_000A) goto L_CACHE_INFO;
	
	//
	// Leaf 8000_000AH
	//

	version (GNU) asm {
		"mov $0x8000000a, %%eax\n"~
		"cpuid\n"~
		"mov %%eax, %0\n"~
		"mov %%edx, %1"
		: "=a" (a), "=d" (d);
	} else asm {
		mov EAX, 0x8000_000A;
		cpuid;
		mov a, EAX;
		mov d, EDX;
	}

	switch (info.vendor_id) {
	case VENDOR_AMD:
		info.virt_version	= cast(ubyte)a; // EAX[7:0]
		info.apivc	= (d & BIT!(13)) != 0;
		break;
	default:
	}

	//if (info.max_ext_leaf < ...) goto L_CACHE_INFO;
	
L_CACHE_INFO:
	//
	// Cache information
	// - Done at the end since we need the local APIC ID
	// - maxleaf < 4 is too old/rare
	//
	
	uint l; /// Cache level
	CACHEINFO *ca = cast(CACHEINFO*)info.cache;
	
	switch (info.vendor_id) {
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
		
		ca.type = CACHE_TYPE[a & 3]; // 0xF
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
		
		ushort lcores = (a >> 26) + 1;	// EAX[31:26]
		ushort crshrd = (((a >> 14) & 2047)+1);	// EAX[25:14]
		ushort sc = lcores / crshrd;
		ca.sharedCores = sc ? sc : 1;
		
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
			info.cache[0].type = 'D'; // data
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
				info.cache[2].type = 'U'; // unified
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
		
		// Almost as same as Intel
		ca.type = CACHE_TYPE[a & 3];
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
		
		++l; ++ca;
		goto CACHE_AMD_NEWER;
	default:
	}
}

debug pragma(msg, "* CPUINFO.sizeof: ", CPUINFO.sizeof);
debug pragma(msg, "* CACHE.sizeof: ", CACHEINFO.sizeof);