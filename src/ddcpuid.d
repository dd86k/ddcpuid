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
 * if (info.ext.amx_xfd) {
 *   // Intel AMX is available
 * } else {
 *   // Feature unavailable
 * }
 * ---
 *
 * See the CPUINFO structure for available fields.
 *
 * For more information, it's encouraged to consult the technical manual.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: © 2016-2021 dd86k
 * License: MIT
 */
module ddcpuid;

//TODO: Consider moving all lone instructions into extras (again?)
//      And probs have an argument to show them (to ouput)
//      Why again?

// NOTE: Please no naked assembler.
//       I'd rather let the compiler deal with a little bit of prolog and
//       epilog than slamming my head into my desk violently trying to match
//       every operating system ABI, compiler versions, and major compilers.
//       Besides, final compiled binary is plenty fine on every compiler.
// NOTE: GAS syntax reminder
//       asm { "asm;\n\t" : "constraint" output : "constraint" input : clobbers }
// NOTE: bhyve doesn't not emit cpuid bits past 0x40000000, so not supported

@system:
extern (C):

version (X86)
	enum DDCPUID_PLATFORM = "x86"; /// Target platform
else version (X86_64)
	enum DDCPUID_PLATFORM = "amd64"; /// Target platform
else static assert(0, "Unsupported platform");

version (DigitalMars) {
	version = DMD;
} else version (GNU) {
	version = GDC;
} else version (LDC) {
	
} else static assert(0, "Unsupported compiler");

enum DDCPUID_VERSION   = "0.18.1";	/// Library version
private enum CACHE_LEVELS = 6;	/// For buffer
private enum CACHE_MAX_LEVEL = CACHE_LEVELS - 1;
private enum VENDOR_OFFSET     = CPUINFO.vendor.offsetof;
private enum BRAND_OFFSET      = CPUINFO.brand.offsetof;
private enum VIRTVENDOR_OFFSET = CPUINFO.virt.offsetof + CPUINFO.virt.vendor.offsetof;

version (PrintInfo) {
	pragma(msg, "VENDOR_OFFSET\t", VENDOR_OFFSET);
	pragma(msg, "BRAND_OFFSET\t", BRAND_OFFSET);
	pragma(msg, "VIRTVENDOR_OFFSET\t", VIRTVENDOR_OFFSET);
	pragma(msg, "CPUINFO.sizeof\t", CPUINFO.sizeof);
	pragma(msg, "CACHE.sizeof\t", CACHEINFO.sizeof);
}

/// Make a bit mask of one bit at n position
private
template BIT(int n) if (n <= 31) { enum uint BIT = 1 << n; }

/// Vendor ID template
// Little-endian only, unless x86 gets any crazier
private
template ID(char[4] c) {
	enum uint ID = c[0] | c[1] << 8 | c[2] << 16 | c[3] << 24;
}

/// Vendor ID.
///
/// The CPUINFO.vendor_id field is set according to the Vendor String.
/// They are validated in the getVendor function, so they are safe to use.
enum Vendor {
	Other = 0,
	Intel = ID!("Genu"),	/// `"GenuineIntel"`: Intel
	AMD   = ID!("Auth"),	/// `"AuthenticAMD"`: AMD
	VIA   = ID!("VIA "),	/// `"VIA VIA VIA "`: VIA
}

/// Virtual Vendor ID, used as the interface type.
///
/// The CPUINFO.virt.vendor_id field is set according to the Vendor String.
/// They are validated in the getVendor function, so they are safe to use.
/// The VBoxHyperV ID will be adjusted for HyperV since it's the same interface,
/// but simply a different implementation.
enum VirtVendor {
	Other = 0,
	KVM        = ID!("KVMK"), /// `"KVMKVMKVM\0\0\0"`: KVM
	HyperV     = ID!("Micr"), /// `"Microsoft Hv"`: Hyper-V interface
	VBoxHyperV = ID!("VBox"), /// `"VBoxVBoxVBox"`: VirtualBox's Hyper-V interface
	VBoxMin    = 0, /// Unset: VirtualBox minimal interface
}

private
union __01ebx_t { // 01h.EBX internal
	uint all;
	struct {
		ubyte brand_index;	/// Processor brand index. No longer used.
		ubyte clflush_linesize;	/// Linesize of CLFLUSH in bytes
		ubyte max_apic_id;	/// Maximum APIC ID
		ubyte apic_id;	/// Initial APIC ID (running core where CPUID was called)
	}
}

/// Registers structure used with the asmcpuid function.
struct REGISTERS { uint eax, ebx, ecx, edx; }

/// CPU cache entry
struct CACHEINFO { align(1):
	union {
		package uint __bundle1;
		struct {
			ubyte linesize; /// Size of the line in bytes
			ubyte partitions;	/// Number of partitions
			ubyte ways;	/// Number of ways per line
			package ubyte _amdsize;	/// (AMD, legacy) Size in KiB
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
	uint max_leaf;	/// Highest cpuid leaf
	uint max_virt_leaf;	/// Highest cpuid virtualization leaf
	uint max_ext_leaf;	/// Highest cpuid extended leaf
	
	// Vendor strings
	
	union {
		package uint[3] vendor32;	/// Vendor 32-bit parts
		char[12] vendor;	/// Vendor String
	}
	union {
		package uint[12] brand32;	// For init
		char[48] brand;	/// Processor Brand String
	}
	union {
		package uint vendor_id32;
		Vendor vendor_id;	/// Validated vendor ID
	}
	ubyte brand_index;	/// Brand string index (not used)
	
	// Core
	
	/// Contains the information on the number of cores.
	struct Cores {
		//TODO: Physical cores
//		ushort physical;	/// Physical cores in this processor
		ushort logical;	/// Logical cores in this processor
	}
	align(2) Cores cores;	/// Processor package cores
	
	// Identifier

	ubyte family;	/// Effective family identifier
	ubyte family_base;	/// Base family identifier
	ubyte family_ext;	/// Extended family identifier
	ubyte model;	/// Effective model identifier
	ubyte model_base;	/// Base model identifier
	ubyte model_ext;	/// Extended model identifier
	ubyte stepping;	/// Stepping revision
	ubyte type;	/// Processor type number
	const(char) *type_string;	/// Processor type string.
	
	//TODO: Consider bit flags for some families
	//      Like MMX, SSE, AVX, AMX, you get the gist
	//TODO: OR Consider bool array
	//      has[EXTENSION_AVX2]
	//      align(4) ;-)
	/// Contains processor extensions.
	/// Extensions contain a variety of instructions to aid particular
	/// tasks.
	struct Extensions {
		bool fpu;	/// On-Chip x87 FPU
		bool f16c;	/// Float16 Conversions
		bool mmx;	/// MMX
		bool mmxext;	/// MMX Extended
		bool _3dnow;	/// 3DNow!
		bool _3dnowext;	/// 3DNow! Extended
		bool aes_ni;	/// Advanced Encryption Standard New Instructions
		bool sha;	/// SHA-1
		bool fma3;	/// Fused Multiply-Add
		bool fma4;	/// FMA4
		bool bmi1;	/// BMI1
		bool bmi2;	/// BMI2
		bool x86_64;	/// 64-bit mode (Long mode)
		bool lahf64;	/// LAHF+SAHF in 64-bit mode
		bool waitpkg;	/// User Level Monitor Wait (UMWAIT)
		bool xop;	/// AMD eXtended OPerations
		bool tbm;	/// Trailing Bit Manipulation
		bool adx;	/// Multi-precision Add-Carry (ADCX+ADOX)
		
		// SSE
		bool sse;	/// Streaming SIMD Extensions
		bool sse2;	/// SSE2
		bool sse3;	/// SSE3
		bool ssse3;	/// SSSE3
		bool sse41;	/// SSE4.1
		bool sse42;	/// SSE4.2
		bool sse4a;	/// SSE4a
		
		// AVX
		bool avx;	/// Advanced Vector eXtension
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
		bool amx;	/// Advanced Matrix eXtension
		bool amx_bf16;	/// AMX-BF16
		bool amx_int8;	/// AMX-INT8
		bool amx_xtilecfg;	/// AMX-XTILECFG
		bool amx_xtiledata;	/// AMX-XTILEDATA
		bool amx_xfd;	/// AMX-XFD
	}
	align(2) Extensions ext;	/// Extensions
	
	/// Additional instructions. Often not part of extensions.
	struct Extras {
		bool pclmulqdq;	/// PCLMULQDQ instruction
		bool monitor;	/// MONITOR and MWAIT instructions
		ushort mwait_min;	/// (With MONITOR+MWAIT) MWAIT minimum size in bytes
		ushort mwait_max;	/// (With MONITOR+MWAIT) MWAIT maximum size in bytes
		bool cmpxchg8b;	/// CMPXCHG8B
		bool cmpxchg16b;	/// CMPXCHG16B instruction
		bool movbe;	/// MOVBE instruction
		bool rdrand;	/// RDRAND instruction
		bool rdseed;	/// RDSEED instruction
		bool rdmsr;	/// RDMSR instruction
		bool sysenter;	/// SYSENTER and SYSEXIT instructions
		bool rdtsc;	/// RDTSC instruction
		bool rdtsc_deadline;	/// (With RDTSC) IA32_TSC_DEADLINE MSR
		bool rdtsc_invariant;	/// (With RDTSC) Timestamp counter invariant of C/P/T-state
		bool rdtscp;	/// RDTSCP instruction
		bool rdpid;	/// RDPID instruction
		bool cmov;	/// CMOVcc instruction
		bool lzcnt;	/// LZCNT instruction
		bool popcnt;	/// POPCNT instruction
		bool xsave;	/// XSAVE and XRSTOR instructions
		bool osxsave;	/// OSXSAVE and XGETBV instructions
		bool fxsr;	/// FXSAVE and FXRSTOR instructions
		bool pconfig;	/// PCONFIG instruction
		bool cldemote;	/// CLDEMOTE instruction
		bool movdiri;	/// MOVDIRI instruction
		bool movdir64b;	/// MOVDIR64B instruction
		bool enqcmd;	/// ENQCMD instruction
		bool syscall;	/// SYSCALL and SYSRET instructions
		bool monitorx;	/// MONITORX and MWAITX instructions
		bool skinit;	/// SKINIT instruction
		bool serialize;	/// SERIALIZE instruction
	}
	align(2) Extras extras;	/// Additional instructions
	
	/// Processor technologies.
	struct Technologies {
		bool eist;	/// Intel SpeedStep/AMD PowerNow/AMD Cool'n'Quiet
		bool turboboost;	/// Intel TurboBoost/AMD CorePerformanceBoost
		bool turboboost30;	/// Intel TurboBoost 3.0
		bool smx;	/// Intel TXT
		bool sgx;	/// Intel SGX
		bool htt;	/// (HTT) HyperThreading Technology
	}
	align(2) Technologies tech;	/// Processor technologies
	
	/// Cache information.
	struct CacheInfo {
		uint levels;
		CACHEINFO[CACHE_LEVELS] level;
		bool clflush;	/// CLFLUSH instruction
		ubyte clflush_linesize;	/// Linesize of CLFLUSH in bytes
		bool clflushopt;	/// CLFLUSH instruction
		bool cnxt_id;	/// L1 Context ID
		bool ss;	/// SelfSnoop
		bool prefetchw;	/// PREFETCHW instruction
		bool invpcid;	/// INVPCID instruction
		bool wbnoinvd;	/// WBNOINVD instruction
	}
	align(2) CacheInfo cache;	/// Cache information
	
	/// ACPI information.
	struct AcpiInfo {
		bool available;	/// ACPI
		bool apic;	/// APIC
		bool x2apic;	/// x2APIC
		bool arat;	/// Always-Running-APIC-Timer
		bool tm;	/// Thermal Monitor
		bool tm2;	/// Thermal Monitor 2
		ubyte max_apic_id;	/// Maximum APIC ID
		ubyte apic_id;	/// Initial APIC ID (running core where CPUID was called)
	}
	align(2) AcpiInfo acpi;	/// ACPI features
	
	/// Virtualization features. If a paravirtual interface is available,
	/// its information will be found here.
	struct Virtualization {
		bool available;	/// Intel VT-x/AMD-V
		ubyte version_;	/// (AMD) Virtualization platform version
		bool vme;	/// Enhanced vm8086
		bool apivc;	/// (AMD) APICv. Intel's is available via a MSR.
		union {
			package uint[3] vendor32;
			char[12] vendor;	/// Paravirtualization interface vendor string
		}
		union {
			package uint vendor_id32;
			VirtVendor vendor_id;	/// Effective paravirtualization vendor id
		}
		
		//TODO: Consider bit flags for paravirtualization flags
		
		// VBox
		
		uint vbox_tsc_freq_khz;	/// (VBox) Timestamp counter frequency in KHz
		uint vbox_apic_freq_khz;	/// (VBox) Paravirtualization API KHz frequency
		
		// KVM
		
		bool kvm_feature_clocksource;	/// (KVM) kvmclock interface
		bool kvm_feature_nop_io_delay;	/// (KVM) No delays required on I/O operations
		bool kvm_feature_mmu_op;	/// (KVM) Deprecated
		bool kvm_feature_clocksource2;	/// (KVM) Remapped kvmclock interface
		bool kvm_feature_async_pf;	/// (KVM) Asynchronous Page Fault
		bool kvm_feature_steal_time;	/// (KVM) Steal time
		bool kvm_feature_pv_eoi;	/// (KVM) Paravirtualized End Of the Interrupt handler
		bool kvm_feature_pv_unhault;	/// (KVM) Paravirtualized spinlock
		bool kvm_feature_pv_tlb_flush;	/// (KVM) Paravirtualized TLB flush
		bool kvm_feature_async_pf_vmexit;	/// (KVM) Asynchronous Page Fault at VM exit
		bool kvm_feature_pv_send_ipi;	/// (KVM) Paravirtualized SEBD inter-processor-interrupt
		bool kvm_feature_pv_poll_control;	/// (KVM) Host-side polling on HLT
		bool kvm_feature_pv_sched_yield;	/// (KVM) paravirtualized scheduler yield
		bool kvm_feature_clocsource_stable_bit;	/// (KVM) kvmclock warning
		bool kvm_hint_realtime;	/// (KVM) vCPUs are never preempted for an unlimited amount of time
		
		// Hyper-V
		
		ushort hv_guest_vendor_id;	/// (Hyper-V) Paravirtualization Guest Vendor ID
		ushort hv_guest_build;	/// (Hyper-V) Paravirtualization Guest Build number
		ubyte hv_guest_os;	/// (Hyper-V) Paravirtualization Guest OS ID
		ubyte hv_guest_major;	/// (Hyper-V) Paravirtualization Guest OS Major version
		ubyte hv_guest_minor;	/// (Hyper-V) Paravirtualization Guest OS Minor version
		ubyte hv_guest_service;	/// (Hyper-V) Paravirtualization Guest Service ID
		bool hv_guest_opensource;	/// (Hyper-V) Paravirtualization Guest additions open-source
		bool hv_base_feat_vp_runtime_msr;	/// (Hyper-V) Virtual processor runtime MSR
		bool hv_base_feat_part_time_ref_count_msr;	/// (Hyper-V) Partition reference counter MSR
		bool hv_base_feat_basic_synic_msrs;	/// (Hyper-V) Basic Synthetic Interrupt Controller MSRs
		bool hv_base_feat_stimer_msrs;	/// (Hyper-V) Synthetic Timer MSRs
		bool hv_base_feat_apic_access_msrs;	/// (Hyper-V) APIC access MSRs (EOI, ICR, TPR)
		bool hv_base_feat_hypercall_msrs;	/// (Hyper-V) Hypercalls API MSRs
		bool hv_base_feat_vp_id_msr;	/// (Hyper-V) vCPU index MSR
		bool hv_base_feat_virt_sys_reset_msr;	/// (Hyper-V) Virtual system reset MSR
		bool hv_base_feat_stat_pages_msr;	/// (Hyper-V) Statistic pages MSRs
		bool hv_base_feat_part_ref_tsc_msr;	/// (Hyper-V) Partition reference timestamp counter MSR
		bool hv_base_feat_guest_idle_state_msr;	/// (Hyper-V) Virtual guest idle state MSR
		bool hv_base_feat_timer_freq_msrs;	/// (Hyper-V) Timer frequency MSRs (TSC and APIC)
		bool hv_base_feat_debug_msrs;	/// (Hyper-V) Debug MSRs
		bool hv_part_flags_create_part;	/// (Hyper-V) Partitions can be created
		bool hv_part_flags_access_part_id;	/// (Hyper-V) Partitions IDs can be accessed
		bool hv_part_flags_access_memory_pool;	/// (Hyper-V) Memory pool can be accessed
		bool hv_part_flags_adjust_msg_buffers;	/// (Hyper-V) Possible to adjust message buffers
		bool hv_part_flags_post_msgs;	/// (Hyper-V) Possible to send messages
		bool hv_part_flags_signal_events;	/// (Hyper-V) Possible to signal events
		bool hv_part_flags_create_port;	/// (Hyper-V) Possible to create ports
		bool hv_part_flags_connect_port;	/// (Hyper-V) Possible to connect to ports
		bool hv_part_flags_access_stats;	/// (Hyper-V) Can access statistics
		bool hv_part_flags_debugging;	/// (Hyper-V) Debugging features available
		bool hv_part_flags_cpu_mgmt;	/// (Hyper-V) Processor management available
		bool hv_part_flags_cpu_profiler;	/// (Hyper-V) Processor profiler available
		bool hv_part_flags_expanded_stack_walk;	/// (Hyper-V) Extended stack walking available
		bool hv_part_flags_access_vsm;	/// (Hyper-V) Virtual system monitor available
		bool hv_part_flags_access_vp_regs;	/// (Hyper-V) Virtual private registers available
		bool hv_part_flags_extended_hypercalls;	/// (Hyper-V) Extended hypercalls API available
		bool hv_part_flags_start_vp;	/// (Hyper-V) Virtual processor has started
		bool hv_pm_max_cpu_power_state_c0;	/// (Hyper-V) Processor C0 is maximum state
		bool hv_pm_max_cpu_power_state_c1;	/// (Hyper-V) Processor C1 is maximum state
		bool hv_pm_max_cpu_power_state_c2;	/// (Hyper-V) Processor C2 is maximum state
		bool hv_pm_max_cpu_power_state_c3;	/// (Hyper-V) Processor C3 is maximum state
		bool hv_pm_hpet_reqd_for_c3;	/// (Hyper-V) High-precision event timer required for C3 state
		bool hv_misc_feat_mwait;	/// (Hyper-V) MWAIT instruction available for guest
		bool hv_misc_feat_guest_debugging;	/// (Hyper-V) Guest supports debugging
		bool hv_misc_feat_perf_mon;	/// (Hyper-V) Performance monitor support available
		bool hv_misc_feat_pcpu_dyn_part_event;	/// (Hyper-V) Physicap CPU dynamic partitioning event available
		bool hv_misc_feat_xmm_hypercall_input;	/// (Hyper-V) Hypercalls via XMM registers available
		bool hv_misc_feat_guest_idle_state;	/// (Hyper-V) Virtual guest supports idle state
		bool hv_misc_feat_hypervisor_sleep_state;	/// (Hyper-V) Hypervisor supports sleep
		bool hv_misc_feat_query_numa_distance;	/// (Hyper-V) NUMA distance query available
		bool hv_misc_feat_timer_freq;	/// (Hyper-V) Determining timer frequencies available
		bool hv_misc_feat_inject_synmc_xcpt;	/// (Hyper-V) Support for injecting synthetic machine checks
		bool hv_misc_feat_guest_crash_msrs;	/// (Hyper-V) Guest crash MSR available
		bool hv_misc_feat_debug_msrs;	/// (Hyper-V) Debug MSR available
		bool hv_misc_feat_npiep1;	/// (Hyper-V) Documentation unavailable
		bool hv_misc_feat_disable_hypervisor;	/// (Hyper-V) Hypervisor can be disabled
		bool hv_misc_feat_ext_gva_range_for_flush_va_list;	/// (Hyper-V) Extended guest virtual address (GVA) ranges for FlushVirtualAddressList available
		bool hv_misc_feat_hypercall_output_xmm;	/// (Hyper-V) Returning hypercall output via XMM registers available
		bool hv_misc_feat_sint_polling_mode;	/// (Hyper-V) Synthetic interrupt source polling mode available
		bool hv_misc_feat_hypercall_msr_lock;	/// (Hyper-V) Hypercall MISR lock feature available
		bool hv_misc_feat_use_direct_synth_msrs;	/// (Hyper-V) Possible to directly use synthetic MSRs
		bool hv_hint_hypercall_for_process_switch;	/// (Hyper-V) Guest should use the Hypercall API for address space switches rather than MOV CR3
		bool hv_hint_hypercall_for_tlb_flush;	/// (Hyper-V) Guest should use the Hypercall API for local TLB flushes rather than INVLPG/MOV CR3
		bool hv_hint_hypercall_for_tlb_shootdown;	/// (Hyper-V) Guest should use the Hypercall API for inter-CPU TLB flushes rather than inter-processor-interrupts (IPI)
		bool hv_hint_msr_for_apic_access;	/// (Hyper-V) Guest should use the MSRs for APIC access (EOI, ICR, TPR) rather than memory-mapped input/output (MMIO)
		bool hv_hint_msr_for_sys_reset;	/// (Hyper-V) Guest should use the hypervisor-provided MSR for a system reset instead of traditional methods
		bool hv_hint_relax_time_checks;	/// (Hyper-V) Guest should relax timer-related checks (watchdogs/deadman timeouts) that rely on timely deliver of external interrupts
		bool hv_hint_dma_remapping;	/// (Hyper-V) Guest should use the direct memory access (DMA) remapping
		bool hv_hint_interrupt_remapping;	/// (Hyper-V) Guest should use the interrupt remapping
		bool hv_hint_x2apic_msrs;	/// (Hyper-V) Guest should use the X2APIC MSRs rather than memory mapped input/output (MMIO)
		bool hv_hint_deprecate_auto_eoi;	/// (Hyper-V) Guest should deprecate Auto EOI (End Of Interrupt) features
		bool hv_hint_synth_cluster_ipi_hypercall;	/// (Hyper-V) Guest should use the SyntheticClusterIpi Hypercall
		bool hv_hint_ex_proc_masks_interface;	/// (Hyper-V) Guest should use the newer ExProcessMasks interface over ProcessMasks
		bool hv_hint_nested_hyperv;	/// (Hyper-V) Hyper-V instance is nested within a Hyper-V partition
		bool hv_hint_int_for_mbec_syscalls;	/// (Hyper-V) Guest should use the INT instruction for Mode Based Execution Control (MBEC) system calls
		bool hv_hint_nested_enlightened_vmcs_interface;	/// (Hyper-V) Guest should use enlightened Virtual Machine Control Structure (VMCS) interfaces and nested enlightenment
		bool hv_host_feat_avic;	/// (Hyper-V) Hypervisor is using the Advanced Virtual Interrupt Controller (AVIC) overlay
		bool hv_host_feat_msr_bitmap;	/// (Hyper-V) Hypervisor is using MSR bitmaps
		bool hv_host_feat_perf_counter;	/// (Hyper-V) Hypervisor supports the architectural performance counter
		bool hv_host_feat_nested_paging;	/// (Hyper-V) Hypervisor is using nested paging
		bool hv_host_feat_dma_remapping;	/// (Hyper-V) Hypervisor is using direct memory access (DMA) remapping
		bool hv_host_feat_interrupt_remapping;	/// (Hyper-V) Hypervisor is using interrupt remapping
		bool hv_host_feat_mem_patrol_scrubber;	/// (Hyper-V) Hypervisor's memory patrol scrubber is present
		bool hv_host_feat_dma_prot_in_use;	/// (Hyper-V) Hypervisor is using direct memory access (DMA) protection
		bool hv_host_feat_hpet_requested;	/// (Hyper-V) Hypervisor requires a High Precision Event Timer (HPET)
		bool hv_host_feat_stimer_volatile;	/// (Hyper-V) Hypervisor's synthetic timers are volatile
	}
	align(2) Virtualization virt;	/// Virtualization features
	
	/// Memory features.
	struct Memory {
		bool pae;	/// Physical Address Extension 
		bool pse;	/// Page Size Extension
		bool pse_36;	/// 36-bit PSE
		bool page1gb;	/// 1GiB pages in 4-level paging and higher
		bool mtrr;	/// Memory Type Range Registers
		bool pat;	/// Page Attribute Table
		bool pge;	/// Page Global Bit
		bool dca;	/// Direct Cache Access
		bool nx;	/// Intel XD (No eXecute bit)
		union {
			uint tsx;	/// Intel TSX. If set, has one of HLE, RTM, or TSXLDTRK.
			struct {
				bool hle;	/// (TSX) Hardware Lock Elision
				bool rtm;	/// (TSX) Restricted Transactional Memory
				bool tsxldtrk;	/// (TSX) Suspend Load Address Tracking
			}
		}
		bool smep;	/// Supervisor Mode Execution Protection
		bool smap;	/// Supervisor Mode Access Protection
		bool pku;	/// Protection Key Units
		bool _5pl;	/// 5-level paging
		bool fsrepmov;	/// Fast Short REP MOVSB optimization
		bool lam;	/// Linear Address Masking
		union {
			package ushort b_8000_0008_ax;
			struct {
				ubyte phys_bits;	/// Memory physical bits
				ubyte line_bits;	/// Memory linear bits
			}
		}
	}
	align (2) Memory mem;	/// Memory features
	
	/// Debugging features.
	struct Debugging {
		bool mca;	/// Machine Check Architecture
		bool mce;	/// Machine Check Exception
		bool de;	/// Degging Extensions
		bool ds;	/// Debug Store
		bool ds_cpl;	/// Debug Store - Curernt Privilege Level
		bool dtes64;	/// 64-bit Debug Store area
		bool pdcm;	/// Perfmon And Debug Capability
		bool sdbg;	/// Silicon Debug
		bool pbe;	/// Pending Break Enable
	}
	align(2) Debugging dbg;	/// Debugging feature
	
	/// Security features and mitigations.
	struct Security {
		bool ia32_arch_capabilities;	/// IA32_ARCH_CAPABILITIES MSR
		// NOTE: IA32_CORE_CAPABILITIES is currently empty
		bool ibpb;	/// Indirect Branch Predictor Barrier
		bool ibrs;	/// Indirect Branch Restricted Speculation
		bool ibrs_on;	/// IBRS always enabled
		bool ibrs_pref;	/// IBRS preferred
		bool stibp;	/// Single Thread Indirect Branch Predictors
		bool stibp_on;	/// STIBP always enabled
		bool ssbd;	/// Speculative Store Bypass Disable
		bool l1d_flush;	/// L1D Cache Flush
		bool md_clear;	/// MDS mitigation
		bool cet_ibt;	/// (Control-flow Enforcement Technology) Indirect Branch Tracking 
		bool cet_ss;	/// (Control-flow Enforcement Technology) Shadow Stack
	}
	align(2) Security sec;	/// Security features
	
	/// Miscellaneous features.
	struct Miscellaneous {
		bool psn;	/// Processor Serial Number (Pentium III only)
		bool pcid;	/// PCID
		bool xtpr;	/// xTPR
		bool fsgsbase;	/// FS and GS register base
		bool uintr;	/// User Interrupts
	}
	align(2) Miscellaneous misc;	/// Miscellaneous features
}

// EAX[4:0], 0-31, but there aren't that many
// So we limit it to 0-7
private
enum CACHE_MASK = 7; // Max 31
private
immutable const(char)* CACHE_TYPE = "?DIU????";

private
immutable const(char)*[] PROCESSOR_TYPE = [ "Original", "OverDrive", "Dual", "Reserved" ];

version (Trace) {
	import core.stdc.stdio;
	import core.stdc.stdarg;
	
	private extern (C) int putchar(int);
	
	/// Trace application
	void trace(string func = __FUNCTION__)(const(char) *fmt, ...) {
		va_list va;
		va_start(va, fmt);
		printf("TRACE:%s: ", func.ptr);
		vprintf(fmt, va);
		putchar('\n');
	}
}

/// Query processor with CPUID.
/// Params:
///   regs = REGISTERS structure
///   level = Leaf (EAX)
///   sublevel = Sub-leaf (ECX)
pragma(inline, false)
void asmcpuid(ref REGISTERS regs, uint level, uint sublevel = 0) {
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
			: "a" (level), "c" (sublevel);
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
	}
	version (Trace) with (regs) trace(
		"level=%x sub=%x -> eax=%x ebx=%x ecx=%x edx=%x",
		level, sublevel, eax, ebx, ecx, edx);
}
/// 
@system unittest {
	REGISTERS regs;
	asmcpuid(regs, 0);
	assert(regs.eax > 0 && regs.eax < 0x4000_0000);
	asmcpuid(regs, 0x8000_0000);
	assert(regs.eax > 0x8000_0000);
}

/// Get CPU leaf levels.
/// Params: info = CPUINFO structure
pragma(inline, false)
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
			"cpuid"
			: "=a" (info.max_leaf)
			: "a" (0);
		}
		asm {
			"cpuid"
			: "=a" (info.max_virt_leaf)
			: "a" (0x40000000);
		}
		asm {
			"cpuid"
			: "=a" (info.max_ext_leaf)
			: "a" (0x80000000);
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
	}
	version (Trace) with(info) trace(
		"leaf=%x vleaf=%x eleaf=%x",
		max_leaf, max_virt_leaf, max_ext_leaf);
}

/// Fetch CPU vendor
pragma(inline, false)
void getVendor(ref CPUINFO info) {
	version (DMD) {
		version (X86) asm {
			mov EDI, info;
			mov EAX, 0;
			cpuid;
			mov [EDI + VENDOR_OFFSET], EBX;
			mov [EDI + VENDOR_OFFSET + 4], EDX;
			mov [EDI + VENDOR_OFFSET + 8], ECX;
		} else asm { // x86-64
			mov RDI, info;
			mov EAX, 0;
			cpuid;
			mov [RDI + VENDOR_OFFSET], EBX;
			mov [RDI + VENDOR_OFFSET + 4], EDX;
			mov [RDI + VENDOR_OFFSET + 8], ECX;
		}
	} else version (GDC) {
		version (X86) asm {
			"lea %0, %%edi\n\t"~
			"mov $0, %%eax\n\t"~
			"cpuid\n"~
			"mov %%ebx, (%%edi)\n\t"~
			"mov %%edx, 4(%%edi)\n\t"~
			"mov %%ecx, 8(%%edi)"
			:
			: "m" (info.vendor)
			: "edi", "eax", "ebx", "ecx", "edx";
		} else asm { // x86-64
			"lea %0, %%rdi\n\t"~
			"mov $0, %%eax\n\t"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n\t"~
			"mov %%edx, 4(%%rdi)\n\t"~
			"mov %%ecx, 8(%%rdi)"
			:
			: "m" (info.vendor)
			: "rdi", "rax", "rbx", "rcx", "rdx";
		}
	} else version (LDC) {
		version (X86) asm {
			lea EDI, info;
			mov EAX, 0;
			cpuid;
			mov [EDI + VENDOR_OFFSET], EBX;
			mov [EDI + VENDOR_OFFSET + 4], EDX;
			mov [EDI + VENDOR_OFFSET + 8], ECX;
		} else asm { // x86-64
			lea RDI, info;
			mov EAX, 0;
			cpuid;
			mov [RDI + VENDOR_OFFSET], EBX;
			mov [RDI + VENDOR_OFFSET + 4], EDX;
			mov [RDI + VENDOR_OFFSET + 8], ECX;
		}
	}
	
	// Vendor string verification
	// If the rest of the string doesn't correspond, the id is unset
	switch (info.vendor32[0]) {
	case Vendor.Intel:	// "GenuineIntel"
		if (info.vendor32[1] != ID!("ineI")) goto default;
		if (info.vendor32[2] != ID!("ntel")) goto default;
		break;
	case Vendor.AMD:	// "AuthenticAMD"
		if (info.vendor32[1] != ID!("enti")) goto default;
		if (info.vendor32[2] != ID!("cAMD")) goto default;
		break;
	case Vendor.VIA:	// "VIA VIA VIA "
		if (info.vendor32[1] != ID!("VIA ")) goto default;
		if (info.vendor32[2] != ID!("VIA ")) goto default;
		break;
	default: // Unknown
		info.vendor_id32 = 0;
		return;
	}
	
	info.vendor_id32 = info.vendor32[0];
}

pragma(inline, false)
private
void getBrand(ref CPUINFO info) {
	version (DMD) {
		version (X86) asm {
			mov EDI, info;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [EDI + BRAND_OFFSET], EAX;
			mov [EDI + BRAND_OFFSET +  4], EBX;
			mov [EDI + BRAND_OFFSET +  8], ECX;
			mov [EDI + BRAND_OFFSET + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [EDI + BRAND_OFFSET + 16], EAX;
			mov [EDI + BRAND_OFFSET + 20], EBX;
			mov [EDI + BRAND_OFFSET + 24], ECX;
			mov [EDI + BRAND_OFFSET + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [EDI + BRAND_OFFSET + 32], EAX;
			mov [EDI + BRAND_OFFSET + 36], EBX;
			mov [EDI + BRAND_OFFSET + 40], ECX;
			mov [EDI + BRAND_OFFSET + 44], EDX;
		} else version (X86_64) asm {
			mov RDI, info;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [RDI + BRAND_OFFSET], EAX;
			mov [RDI + BRAND_OFFSET +  4], EBX;
			mov [RDI + BRAND_OFFSET +  8], ECX;
			mov [RDI + BRAND_OFFSET + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [RDI + BRAND_OFFSET + 16], EAX;
			mov [RDI + BRAND_OFFSET + 20], EBX;
			mov [RDI + BRAND_OFFSET + 24], ECX;
			mov [RDI + BRAND_OFFSET + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [RDI + BRAND_OFFSET + 32], EAX;
			mov [RDI + BRAND_OFFSET + 36], EBX;
			mov [RDI + BRAND_OFFSET + 40], ECX;
			mov [RDI + BRAND_OFFSET + 44], EDX;
		}
	} else version (GDC) {
		version (X86) asm {
			"lea %0, %%edi\n\t"~
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
			: "m" (info.brand)
			: "edi", "eax", "ebx", "ecx", "edx";
		} else version (X86_64) asm {
			"lea %0, %%rdi\n\t"~
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
			: "m" (info.brand)
			: "rdi", "rax", "rbx", "rcx", "rdx";
		}
	} else version (LDC) {
		version (X86) asm {
			lea EDI, info;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [EDI + BRAND_OFFSET], EAX;
			mov [EDI + BRAND_OFFSET +  4], EBX;
			mov [EDI + BRAND_OFFSET +  8], ECX;
			mov [EDI + BRAND_OFFSET + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [EDI + BRAND_OFFSET + 16], EAX;
			mov [EDI + BRAND_OFFSET + 20], EBX;
			mov [EDI + BRAND_OFFSET + 24], ECX;
			mov [EDI + BRAND_OFFSET + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [EDI + BRAND_OFFSET + 32], EAX;
			mov [EDI + BRAND_OFFSET + 36], EBX;
			mov [EDI + BRAND_OFFSET + 40], ECX;
			mov [EDI + BRAND_OFFSET + 44], EDX;
		} else version (X86_64) asm {
			lea RDI, info;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [RDI + BRAND_OFFSET], EAX;
			mov [RDI + BRAND_OFFSET +  4], EBX;
			mov [RDI + BRAND_OFFSET +  8], ECX;
			mov [RDI + BRAND_OFFSET + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [RDI + BRAND_OFFSET + 16], EAX;
			mov [RDI + BRAND_OFFSET + 20], EBX;
			mov [RDI + BRAND_OFFSET + 24], ECX;
			mov [RDI + BRAND_OFFSET + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [RDI + BRAND_OFFSET + 32], EAX;
			mov [RDI + BRAND_OFFSET + 36], EBX;
			mov [RDI + BRAND_OFFSET + 40], ECX;
			mov [RDI + BRAND_OFFSET + 44], EDX;
		}
	}
}

pragma(inline, false)
private
void getVirtVendor(ref CPUINFO info) {
	version (DMD) {
		version (X86) asm {
			mov EDI, info;
			mov EAX, 0x40000000;
			cpuid;
			mov [EDI + VIRTVENDOR_OFFSET], EBX;
			mov [EDI + VIRTVENDOR_OFFSET + 4], ECX;
			mov [EDI + VIRTVENDOR_OFFSET + 8], EDX;
		} else asm { // x86-64
			mov RDI, info;
			mov EAX, 0x40000000;
			cpuid;
			mov [RDI + VIRTVENDOR_OFFSET], EBX;
			mov [RDI + VIRTVENDOR_OFFSET + 4], ECX;
			mov [RDI + VIRTVENDOR_OFFSET + 8], EDX;
		}
	} else version (GDC) {
		version (X86) asm {
			"lea %0, %%edi\n\t"~
			"mov $0x40000000, %%eax\n\t"~
			"cpuid\n"~
			"mov %%ebx, (%%edi)\n\t"~
			"mov %%ecx, 4(%%edi)\n\t"~
			"mov %%edx, 8(%%edi)"
			:
			: "m" (info.virt.vendor)
			: "edi", "eax", "ebx", "ecx", "edx";
		} else asm { // x86-64
			"lea %0, %%rdi\n\t"~
			"mov $0x40000000, %%eax\n\t"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n\t"~
			"mov %%ecx, 4(%%rdi)\n\t"~
			"mov %%edx, 8(%%rdi)"
			:
			: "m" (info.virt.vendor)
			: "rdi", "rax", "rbx", "rcx", "rdx";
		}
	} else version (LDC) {
		version (X86) asm {
			lea EDI, info;
			mov EAX, 0x40000000;
			cpuid;
			mov [EDI + VIRTVENDOR_OFFSET], EBX;
			mov [EDI + VIRTVENDOR_OFFSET + 4], ECX;
			mov [EDI + VIRTVENDOR_OFFSET + 8], EDX;
		} else asm { // x86-64
			lea RDI, info;
			mov EAX, 0x40000000;
			cpuid;
			mov [RDI + VIRTVENDOR_OFFSET], EBX;
			mov [RDI + VIRTVENDOR_OFFSET + 4], ECX;
			mov [RDI + VIRTVENDOR_OFFSET + 8], EDX;
		}
	}
	
	// Paravirtual vendor string verification
	// If the rest of the string doesn't correspond, the id is unset
	switch (info.virt.vendor32[0]) {
	case VirtVendor.KVM:	// "KVMKVMKVM\0\0\0"
		if (info.virt.vendor32[1] != ID!("VMKV")) goto default;
		if (info.virt.vendor32[2] != ID!("M\0\0\0")) goto default;
		break;
	case VirtVendor.HyperV:	// "Microsoft Hv"
		if (info.virt.vendor32[1] != ID!("osof")) goto default;
		if (info.virt.vendor32[2] != ID!("t Hv")) goto default;
		break;
	case VirtVendor.VBoxHyperV:	// "VBoxVBoxVBox"
		if (info.virt.vendor32[1] != ID!("VBox")) goto default;
		if (info.virt.vendor32[2] != ID!("VBox")) goto default;
		info.virt.vendor_id = VirtVendor.HyperV;
		return;
	default:
		info.virt.vendor_id32 = 0;
		return;
	}
	
	info.virt.vendor_id32 = info.virt.vendor32[0];
	version (Trace) trace("id=%u", info.virt.vendor_id32);
}

/// Fetch CPU information.
/// Params: info = CPUINFO structure
// There are essentially 5 sections to this function:
// - Brand String
// - Normal leaf information
// - Paravirtualization leaf information
// - Extended leaf information
// - Cache information
pragma(inline, false)
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
	info.model_base  = regs.eax >>  4 &  0xF; // EAX[7:4]
	info.family_base = regs.eax >>  8 &  0xF; // EAX[11:8]
	info.type        = regs.eax >> 12 & 0b11; // EAX[13:12]
	info.type_string = PROCESSOR_TYPE[info.type];
	info.model_ext   = regs.eax >> 16 &  0xF; // EAX[19:16]
	info.family_ext  = cast(ubyte)(regs.eax >> 20); // EAX[27:20]
	
	switch (info.vendor_id) {
	case Vendor.Intel:
		info.family = info.family_base != 0 ?
			info.family_base :
			cast(ubyte)(info.family_ext + info.family_base);
		
		info.model = info.family_base == 6 || info.family_base == 0 ?
			cast(ubyte)((info.model_ext << 4) + info.model_base) :
			info.model_base; // DisplayModel = Model_ID;
		
		// ECX
		info.dbg.dtes64	= (regs.ecx & BIT!(2)) != 0;
		info.dbg.ds_cpl	= (regs.ecx & BIT!(4)) != 0;
		info.virt.available	= (regs.ecx & BIT!(5)) != 0;
		info.tech.smx	= (regs.ecx & BIT!(6)) != 0;
		info.tech.eist	= (regs.ecx & BIT!(7)) != 0;
		info.acpi.tm2	= (regs.ecx & BIT!(8)) != 0;
		info.cache.cnxt_id	= (regs.ecx & BIT!(10)) != 0;
		info.dbg.sdbg	= (regs.ecx & BIT!(11)) != 0;
		info.misc.xtpr	= (regs.ecx & BIT!(14)) != 0;
		info.dbg.pdcm	= (regs.ecx & BIT!(15)) != 0;
		info.misc.pcid	= (regs.ecx & BIT!(17)) != 0;
		info.dbg.mca	= (regs.ecx & BIT!(18)) != 0;
		info.acpi.x2apic	= (regs.ecx & BIT!(21)) != 0;
		info.extras.rdtsc_deadline	= (regs.ecx & BIT!(24)) != 0;
		
		// EDX
		info.misc.psn	= (regs.edx & BIT!(18)) != 0;
		info.dbg.ds	= (regs.edx & BIT!(21)) != 0;
		info.acpi.available	= (regs.edx & BIT!(22)) != 0;
		info.cache.ss	= (regs.edx & BIT!(27)) != 0;
		info.acpi.tm	= (regs.edx & BIT!(29)) != 0;
		info.dbg.pbe	= regs.edx >= BIT!(31);
		break;
	case Vendor.AMD:
		if (info.family_base < 0xF) {
			info.family = info.family_base;
			info.model = info.model_base;
		} else {
			info.family = cast(ubyte)(info.family_ext + info.family_base);
			info.model = cast(ubyte)((info.model_ext << 4) + info.model_base);
		}
		break;
	default:
	}
	
	// EBX
	__01ebx_t t = void; // BrandIndex, CLFLUSHLineSize, MaxIDs, InitialAPICID
	t.all = regs.ebx;
	info.brand_index = t.brand_index;
	info.cache.clflush_linesize = t.clflush_linesize;
	info.acpi.max_apic_id = t.max_apic_id;
	info.acpi.apic_id = t.apic_id;
	
	// ECX
	info.ext.sse3	= (regs.ecx & BIT!(0)) != 0;
	info.extras.pclmulqdq	= (regs.ecx & BIT!(1)) != 0;
	info.extras.monitor	= (regs.ecx & BIT!(3)) != 0;
	info.ext.ssse3	= (regs.ecx & BIT!(9)) != 0;
	info.ext.fma3	= (regs.ecx & BIT!(12)) != 0;
	info.extras.cmpxchg16b	= (regs.ecx & BIT!(13)) != 0;
	info.ext.sse41	= (regs.ecx & BIT!(15)) != 0;
	info.ext.sse42	= (regs.ecx & BIT!(20)) != 0;
	info.extras.movbe	= (regs.ecx & BIT!(22)) != 0;
	info.extras.popcnt	= (regs.ecx & BIT!(23)) != 0;
	info.ext.aes_ni	= (regs.ecx & BIT!(25)) != 0;
	info.extras.xsave	= (regs.ecx & BIT!(26)) != 0;
	info.extras.osxsave	= (regs.ecx & BIT!(27)) != 0;
	info.ext.avx	= (regs.ecx & BIT!(28)) != 0;
	info.ext.f16c	= (regs.ecx & BIT!(29)) != 0;
	info.extras.rdrand	= (regs.ecx & BIT!(30)) != 0;
	
	// EDX
	info.ext.fpu	= (regs.edx & BIT!(0)) != 0;
	info.virt.vme	= (regs.edx & BIT!(1)) != 0;
	info.dbg.de	= (regs.edx & BIT!(2)) != 0;
	info.mem.pse	= (regs.edx & BIT!(3)) != 0;
	info.extras.rdtsc	= (regs.edx & BIT!(4)) != 0;
	info.extras.rdmsr	= (regs.edx & BIT!(5)) != 0;
	info.mem.pae	= (regs.edx & BIT!(6)) != 0;
	info.dbg.mce	= (regs.edx & BIT!(7)) != 0;
	info.extras.cmpxchg8b	= (regs.edx & BIT!(8)) != 0;
	info.acpi.apic	= (regs.edx & BIT!(9)) != 0;
	info.extras.sysenter	= (regs.edx & BIT!(11)) != 0;
	info.mem.mtrr	= (regs.edx & BIT!(12)) != 0;
	info.mem.pge	= (regs.edx & BIT!(13)) != 0;
	info.dbg.mca	= (regs.edx & BIT!(14)) != 0;
	info.extras.cmov	= (regs.edx & BIT!(15)) != 0;
	info.mem.pat	= (regs.edx & BIT!(16)) != 0;
	info.mem.pse_36	= (regs.edx & BIT!(17)) != 0;
	info.cache.clflush	= (regs.edx & BIT!(19)) != 0;
	info.ext.mmx	= (regs.edx & BIT!(23)) != 0;
	info.extras.fxsr	= (regs.edx & BIT!(24)) != 0;
	info.ext.sse	= (regs.edx & BIT!(25)) != 0;
	info.ext.sse2	= (regs.edx & BIT!(26)) != 0;
	info.tech.htt	= (regs.edx & BIT!(28)) != 0;
	
	switch (info.vendor_id) {
	case Vendor.AMD:
		if (info.tech.htt)
			info.cores.logical = info.acpi.max_apic_id;
		break;
	default:
	}
	
	if (info.max_leaf < 5) goto L_VIRT;
	
	//
	// Leaf 5H
	//
	
	asmcpuid(regs, 5);
	
	info.extras.mwait_min = cast(ushort)regs.eax;
	info.extras.mwait_max = cast(ushort)regs.ebx;
	
	if (info.max_leaf < 6) goto L_VIRT;
	
	//
	// Leaf 6H
	//
	
	asmcpuid(regs, 6);
	
	switch (info.vendor_id) {
	case Vendor.Intel:
		info.tech.turboboost	= (regs.eax & BIT!(1)) != 0;
		info.tech.turboboost30	= (regs.eax & BIT!(14)) != 0;
		break;
	default:
	}
	
	info.acpi.arat = (regs.eax & BIT!(2)) != 0;
	
	if (info.max_leaf < 7) goto L_VIRT;
	
	//
	// Leaf 7H
	//
	
	asmcpuid(regs, 7);
	
	switch (info.vendor_id) {
	case Vendor.Intel:
		// EBX
		info.tech.sgx	= (regs.ebx & BIT!(2)) != 0;
		info.mem.hle	= (regs.ebx & BIT!(4)) != 0;
		info.cache.invpcid	= (regs.ebx & BIT!(10)) != 0;
		info.mem.rtm	= (regs.ebx & BIT!(11)) != 0;
		info.ext.avx512f	= (regs.ebx & BIT!(16)) != 0;
		info.mem.smap	= (regs.ebx & BIT!(20)) != 0;
		info.ext.avx512er	= (regs.ebx & BIT!(27)) != 0;
		info.ext.avx512pf	= (regs.ebx & BIT!(26)) != 0;
		info.ext.avx512cd	= (regs.ebx & BIT!(28)) != 0;
		info.ext.avx512dq	= (regs.ebx & BIT!(17)) != 0;
		info.ext.avx512bw	= (regs.ebx & BIT!(30)) != 0;
		info.ext.avx512_ifma	= (regs.ebx & BIT!(21)) != 0;
		info.ext.avx512_vbmi	= regs.ebx >= BIT!(31);
		// ECX
		info.ext.avx512vl	= (regs.ecx & BIT!(1)) != 0;
		info.mem.pku	= (regs.ecx & BIT!(3)) != 0;
		info.mem.fsrepmov	= (regs.ecx & BIT!(4)) != 0;
		info.ext.waitpkg	= (regs.ecx & BIT!(5)) != 0;
		info.ext.avx512_vbmi2	= (regs.ecx & BIT!(6)) != 0;
		info.sec.cet_ss	= (regs.ecx & BIT!(7)) != 0;
		info.ext.avx512_gfni	= (regs.ecx & BIT!(8)) != 0;
		info.ext.avx512_vaes	= (regs.ecx & BIT!(9)) != 0;
		info.ext.avx512_vnni	= (regs.ecx & BIT!(11)) != 0;
		info.ext.avx512_bitalg	= (regs.ecx & BIT!(12)) != 0;
		info.ext.avx512_vpopcntdq	= (regs.ecx & BIT!(14)) != 0;
		info.mem._5pl	= (regs.ecx & BIT!(16)) != 0;
		info.extras.cldemote	= (regs.ecx & BIT!(25)) != 0;
		info.extras.movdiri	= (regs.ecx & BIT!(27)) != 0;
		info.extras.movdir64b	= (regs.ecx & BIT!(28)) != 0;
		info.extras.enqcmd	= (regs.ecx & BIT!(29)) != 0;
		// EDX
		info.ext.avx512_4vnniw	= (regs.edx & BIT!(2)) != 0;
		info.ext.avx512_4fmaps	= (regs.edx & BIT!(3)) != 0;
		info.misc.uintr	= (regs.edx & BIT!(5)) != 0;
		info.ext.avx512_vp2intersect	= (regs.edx & BIT!(8)) != 0;
		info.sec.md_clear	= (regs.edx & BIT!(10)) != 0;
		info.extras.serialize	= (regs.edx & BIT!(14)) != 0;
		info.mem.tsxldtrk	= (regs.edx & BIT!(16)) != 0;
		info.extras.pconfig	= (regs.edx & BIT!(18)) != 0;
		info.sec.cet_ibt	= (regs.edx & BIT!(20)) != 0;
		info.ext.amx_bf16	= (regs.edx & BIT!(22)) != 0;
		info.ext.amx	= (regs.edx & BIT!(24)) != 0;
		info.ext.amx_int8	= (regs.edx & BIT!(25)) != 0;
		info.sec.ibrs = (regs.edx & BIT!(26)) != 0;
		info.sec.stibp	= (regs.edx & BIT!(27)) != 0;
		info.sec.l1d_flush	= (regs.edx & BIT!(28)) != 0;
		info.sec.ia32_arch_capabilities	= (regs.edx & BIT!(29)) != 0;
		info.sec.ssbd	= regs.edx >= BIT!(31);
		break;
	default:
	}

	// ebx
	info.misc.fsgsbase	= (regs.ebx & BIT!(0)) != 0;
	info.ext.bmi1	= (regs.ebx & BIT!(3)) != 0;
	info.ext.avx2	= (regs.ebx & BIT!(5)) != 0;
	info.mem.smep	= (regs.ebx & BIT!(7)) != 0;
	info.ext.bmi2	= (regs.ebx & BIT!(8)) != 0;
	info.extras.rdseed	= (regs.ebx & BIT!(18)) != 0;
	info.ext.adx	= (regs.ebx & BIT!(19)) != 0;
	info.cache.clflushopt	= (regs.ebx & BIT!(23)) != 0;
	info.ext.sha	= (regs.ebx & BIT!(29)) != 0;
	// ecx
	info.extras.rdpid	= (regs.ecx & BIT!(22)) != 0;
	
	//
	// Leaf 7H(ECX=01h)
	//
	
	switch (info.vendor_id) {
	case Vendor.Intel:
		asmcpuid(regs, 7, 1);
		// a
		info.ext.avx512_bf16	= (regs.eax & BIT!(5)) != 0;
		info.mem.lam	= (regs.eax & BIT!(26)) != 0;
		break;
	default:
	}
	
	if (info.max_leaf < 0xD) goto L_VIRT;
	
	//
	// Leaf DH
	//
	
	switch (info.vendor_id) {
	case Vendor.Intel:
		asmcpuid(regs, 0xd);
		info.ext.amx_xtilecfg	= (regs.eax & BIT!(17)) != 0;
		info.ext.amx_xtiledata	= (regs.eax & BIT!(18)) != 0;
		break;
	default:
	}
	
	//
	// Leaf DH(ECX=01h)
	//

	switch (info.vendor_id) {
	case Vendor.Intel:
		asmcpuid(regs, 0xd, 1);
		info.ext.amx_xfd	= (regs.eax & BIT!(18)) != 0;
		break;
	default:
	}
	
	if (info.max_virt_leaf < 0x4000_0000) goto L_VIRT;
	
	//
	// Leaf 4000_000H
	//
	
L_VIRT:
	getVirtVendor(info);

	if (info.max_virt_leaf < 0x4000_0001) goto L_EXTENDED;
	
	//
	// Leaf 4000_0001H
	//
	
	switch (info.virt.vendor_id) {
	case VirtVendor.KVM:
		asmcpuid(regs, 0x4000_0001);
		info.virt.kvm_feature_clocksource	= (regs.eax & BIT!(0)) != 0;
		info.virt.kvm_feature_nop_io_delay	= (regs.eax & BIT!(1)) != 0;
		info.virt.kvm_feature_mmu_op	= (regs.eax & BIT!(2)) != 0;
		info.virt.kvm_feature_clocksource2	= (regs.eax & BIT!(3)) != 0;
		info.virt.kvm_feature_async_pf	= (regs.eax & BIT!(4)) != 0;
		info.virt.kvm_feature_steal_time	= (regs.eax & BIT!(5)) != 0;
		info.virt.kvm_feature_pv_eoi	= (regs.eax & BIT!(6)) != 0;
		info.virt.kvm_feature_pv_unhault	= (regs.eax & BIT!(7)) != 0;
		info.virt.kvm_feature_pv_tlb_flush	= (regs.eax & BIT!(9)) != 0;
		info.virt.kvm_feature_async_pf_vmexit	= (regs.eax & BIT!(10)) != 0;
		info.virt.kvm_feature_pv_send_ipi	= (regs.eax & BIT!(11)) != 0;
		info.virt.kvm_feature_pv_poll_control	= (regs.eax & BIT!(12)) != 0;
		info.virt.kvm_feature_pv_sched_yield	= (regs.eax & BIT!(13)) != 0;
		info.virt.kvm_feature_clocsource_stable_bit	= (regs.eax & BIT!(24)) != 0;
		info.virt.kvm_hint_realtime	= (regs.edx & BIT!(0)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0002) goto L_EXTENDED;
	
	//
	// Leaf 4000_002H
	//
	
	switch (info.virt.vendor_id) {
	case VirtVendor.HyperV:
		asmcpuid(regs, 0x4000_0002);
		info.virt.hv_guest_minor	= cast(ubyte)(regs.eax >> 24);
		info.virt.hv_guest_service	= cast(ubyte)(regs.eax >> 16);
		info.virt.hv_guest_build	= cast(ushort)regs.eax;
		info.virt.hv_guest_opensource	= regs.edx >= BIT!(31);
		info.virt.hv_guest_vendor_id	= (regs.edx >> 16) & 0xFFF;
		info.virt.hv_guest_os	= cast(ubyte)(regs.edx >> 8);
		info.virt.hv_guest_major	= cast(ubyte)regs.edx;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0003) goto L_EXTENDED;
	
	//
	// Leaf 4000_0003H
	//
	
	switch (info.virt.vendor_id) {
	case VirtVendor.HyperV:
		asmcpuid(regs, 0x4000_0003);
		info.virt.hv_base_feat_vp_runtime_msr	= (regs.eax & BIT!(0)) != 0;
		info.virt.hv_base_feat_part_time_ref_count_msr	= (regs.eax & BIT!(1)) != 0;
		info.virt.hv_base_feat_basic_synic_msrs	= (regs.eax & BIT!(2)) != 0;
		info.virt.hv_base_feat_stimer_msrs	= (regs.eax & BIT!(3)) != 0;
		info.virt.hv_base_feat_apic_access_msrs	= (regs.eax & BIT!(4)) != 0;
		info.virt.hv_base_feat_hypercall_msrs	= (regs.eax & BIT!(5)) != 0;
		info.virt.hv_base_feat_vp_id_msr	= (regs.eax & BIT!(6)) != 0;
		info.virt.hv_base_feat_virt_sys_reset_msr	= (regs.eax & BIT!(7)) != 0;
		info.virt.hv_base_feat_stat_pages_msr	= (regs.eax & BIT!(8)) != 0;
		info.virt.hv_base_feat_part_ref_tsc_msr	= (regs.eax & BIT!(9)) != 0;
		info.virt.hv_base_feat_guest_idle_state_msr	= (regs.eax & BIT!(10)) != 0;
		info.virt.hv_base_feat_timer_freq_msrs	= (regs.eax & BIT!(11)) != 0;
		info.virt.hv_base_feat_debug_msrs	= (regs.eax & BIT!(12)) != 0;
		info.virt.hv_part_flags_create_part	= (regs.ebx & BIT!(0)) != 0;
		info.virt.hv_part_flags_access_part_id	= (regs.ebx & BIT!(1)) != 0;
		info.virt.hv_part_flags_access_memory_pool	= (regs.ebx & BIT!(2)) != 0;
		info.virt.hv_part_flags_adjust_msg_buffers	= (regs.ebx & BIT!(3)) != 0;
		info.virt.hv_part_flags_post_msgs	= (regs.ebx & BIT!(4)) != 0;
		info.virt.hv_part_flags_signal_events	= (regs.ebx & BIT!(5)) != 0;
		info.virt.hv_part_flags_create_port	= (regs.ebx & BIT!(6)) != 0;
		info.virt.hv_part_flags_connect_port	= (regs.ebx & BIT!(7)) != 0;
		info.virt.hv_part_flags_access_stats	= (regs.ebx & BIT!(8)) != 0;
		info.virt.hv_part_flags_debugging	= (regs.ebx & BIT!(11)) != 0;
		info.virt.hv_part_flags_cpu_mgmt	= (regs.ebx & BIT!(12)) != 0;
		info.virt.hv_part_flags_cpu_profiler	= (regs.ebx & BIT!(13)) != 0;
		info.virt.hv_part_flags_expanded_stack_walk	= (regs.ebx & BIT!(14)) != 0;
		info.virt.hv_part_flags_access_vsm	= (regs.ebx & BIT!(16)) != 0;
		info.virt.hv_part_flags_access_vp_regs	= (regs.ebx & BIT!(17)) != 0;
		info.virt.hv_part_flags_extended_hypercalls	= (regs.ebx & BIT!(20)) != 0;
		info.virt.hv_part_flags_start_vp	= (regs.ebx & BIT!(21)) != 0;
		info.virt.hv_pm_max_cpu_power_state_c0	= (regs.ecx & BIT!(0)) != 0;
		info.virt.hv_pm_max_cpu_power_state_c1	= (regs.ecx & BIT!(1)) != 0;
		info.virt.hv_pm_max_cpu_power_state_c2	= (regs.ecx & BIT!(2)) != 0;
		info.virt.hv_pm_max_cpu_power_state_c3	= (regs.ecx & BIT!(3)) != 0;
		info.virt.hv_pm_hpet_reqd_for_c3	= (regs.ecx & BIT!(4)) != 0;
		info.virt.hv_misc_feat_mwait	= (regs.eax & BIT!(0)) != 0;
		info.virt.hv_misc_feat_guest_debugging	= (regs.eax & BIT!(1)) != 0;
		info.virt.hv_misc_feat_perf_mon	= (regs.eax & BIT!(2)) != 0;
		info.virt.hv_misc_feat_pcpu_dyn_part_event	= (regs.eax & BIT!(3)) != 0;
		info.virt.hv_misc_feat_xmm_hypercall_input	= (regs.eax & BIT!(4)) != 0;
		info.virt.hv_misc_feat_guest_idle_state	= (regs.eax & BIT!(5)) != 0;
		info.virt.hv_misc_feat_hypervisor_sleep_state	= (regs.eax & BIT!(6)) != 0;
		info.virt.hv_misc_feat_query_numa_distance	= (regs.eax & BIT!(7)) != 0;
		info.virt.hv_misc_feat_timer_freq	= (regs.eax & BIT!(8)) != 0;
		info.virt.hv_misc_feat_inject_synmc_xcpt	= (regs.eax & BIT!(9)) != 0;
		info.virt.hv_misc_feat_guest_crash_msrs	= (regs.eax & BIT!(10)) != 0;
		info.virt.hv_misc_feat_debug_msrs	= (regs.eax & BIT!(11)) != 0;
		info.virt.hv_misc_feat_npiep1	= (regs.eax & BIT!(12)) != 0;
		info.virt.hv_misc_feat_disable_hypervisor	= (regs.eax & BIT!(13)) != 0;
		info.virt.hv_misc_feat_ext_gva_range_for_flush_va_list	= (regs.eax & BIT!(14)) != 0;
		info.virt.hv_misc_feat_hypercall_output_xmm	= (regs.eax & BIT!(15)) != 0;
		info.virt.hv_misc_feat_sint_polling_mode	= (regs.eax & BIT!(17)) != 0;
		info.virt.hv_misc_feat_hypercall_msr_lock	= (regs.eax & BIT!(18)) != 0;
		info.virt.hv_misc_feat_use_direct_synth_msrs	= (regs.eax & BIT!(19)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0004) goto L_EXTENDED;
	
	//
	// Leaf 4000_0004H
	//
	
	switch (info.virt.vendor_id) {
	case VirtVendor.HyperV:
		asmcpuid(regs, 0x4000_0004);
		info.virt.hv_hint_hypercall_for_process_switch	= (regs.eax & BIT!(0)) != 0;
		info.virt.hv_hint_hypercall_for_tlb_flush	= (regs.eax & BIT!(1)) != 0;
		info.virt.hv_hint_hypercall_for_tlb_shootdown	= (regs.eax & BIT!(2)) != 0;
		info.virt.hv_hint_msr_for_apic_access	= (regs.eax & BIT!(3)) != 0;
		info.virt.hv_hint_msr_for_sys_reset	= (regs.eax & BIT!(4)) != 0;
		info.virt.hv_hint_relax_time_checks	= (regs.eax & BIT!(5)) != 0;
		info.virt.hv_hint_dma_remapping	= (regs.eax & BIT!(6)) != 0;
		info.virt.hv_hint_interrupt_remapping	= (regs.eax & BIT!(7)) != 0;
		info.virt.hv_hint_x2apic_msrs	= (regs.eax & BIT!(8)) != 0;
		info.virt.hv_hint_deprecate_auto_eoi	= (regs.eax & BIT!(9)) != 0;
		info.virt.hv_hint_synth_cluster_ipi_hypercall	= (regs.eax & BIT!(10)) != 0;
		info.virt.hv_hint_ex_proc_masks_interface	= (regs.eax & BIT!(11)) != 0;
		info.virt.hv_hint_nested_hyperv	= (regs.eax & BIT!(12)) != 0;
		info.virt.hv_hint_int_for_mbec_syscalls	= (regs.eax & BIT!(13)) != 0;
		info.virt.hv_hint_nested_enlightened_vmcs_interface	= (regs.eax & BIT!(14)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0006) goto L_EXTENDED;
	
	//
	// Leaf 4000_0006H
	//
	
	switch (info.virt.vendor_id) {
	case VirtVendor.HyperV:
		asmcpuid(regs, 0x4000_0006);
		info.virt.hv_host_feat_avic	= (regs.eax & BIT!(0)) != 0;
		info.virt.hv_host_feat_msr_bitmap	= (regs.eax & BIT!(1)) != 0;
		info.virt.hv_host_feat_perf_counter	= (regs.eax & BIT!(2)) != 0;
		info.virt.hv_host_feat_nested_paging	= (regs.eax & BIT!(3)) != 0;
		info.virt.hv_host_feat_dma_remapping	= (regs.eax & BIT!(4)) != 0;
		info.virt.hv_host_feat_interrupt_remapping	= (regs.eax & BIT!(5)) != 0;
		info.virt.hv_host_feat_mem_patrol_scrubber	= (regs.eax & BIT!(6)) != 0;
		info.virt.hv_host_feat_dma_prot_in_use	= (regs.eax & BIT!(7)) != 0;
		info.virt.hv_host_feat_hpet_requested	= (regs.eax & BIT!(8)) != 0;
		info.virt.hv_host_feat_stimer_volatile	= (regs.eax & BIT!(9)) != 0;
		break;
	default:
	}

	if (info.max_virt_leaf < 0x4000_0010) goto L_EXTENDED;
	
	//
	// Leaf 4000_0010H
	//
	
	switch (info.virt.vendor_id) {
	case VirtVendor.VBoxMin: // VBox Minimal
		asmcpuid(regs, 0x4000_0010);
		info.virt.vbox_tsc_freq_khz = regs.eax;
		info.virt.vbox_apic_freq_khz = regs.ebx;
		break;
	default:
	}

	//
	// Leaf 8000_0001H
	//
	
L_EXTENDED:
	asmcpuid(regs, 0x8000_0001);
	
	switch (info.vendor_id) {
	case Vendor.AMD:
		// ecx
		info.virt.available	= (regs.ecx & BIT!(2)) != 0;
		info.acpi.x2apic	= (regs.ecx & BIT!(3)) != 0;
		info.ext.sse4a	= (regs.ecx & BIT!(6)) != 0;
		info.ext.xop	= (regs.ecx & BIT!(11)) != 0;
		info.extras.skinit	= (regs.ecx & BIT!(12)) != 0;
		info.ext.fma4	= (regs.ecx & BIT!(16)) != 0;
		info.ext.tbm	= (regs.ecx & BIT!(21)) != 0;
		// edx
		info.ext.mmxext	= (regs.edx & BIT!(22)) != 0;
		info.ext._3dnowext	= (regs.edx & BIT!(30)) != 0;
		info.ext._3dnow	= regs.edx >= BIT!(31);
		break;
	default:
	}
	
	// ecx
	info.ext.lahf64	= (regs.ecx & BIT!(0)) != 0;
	info.extras.lzcnt	= (regs.ecx & BIT!(5)) != 0;
	info.cache.prefetchw	= (regs.ecx & BIT!(8)) != 0;
	info.extras.monitorx	= (regs.ecx & BIT!(29)) != 0;
	// edx
	info.extras.syscall	= (regs.edx & BIT!(11)) != 0;
	info.mem.nx	= (regs.edx & BIT!(20)) != 0;
	info.mem.page1gb	= (regs.edx & BIT!(26)) != 0;
	info.extras.rdtscp	= (regs.edx & BIT!(27)) != 0;
	info.ext.x86_64	= (regs.edx & BIT!(29)) != 0;
	
	if (info.max_ext_leaf < 0x8000_0007) goto L_CACHE_INFO;
	
	//
	// Leaf 8000_0007H
	//
	
	asmcpuid(regs, 0x8000_0007);
	
	switch (info.vendor_id) {
	case Vendor.Intel:
		info.extras.rdseed	= (regs.ebx & BIT!(28)) != 0;
		break;
	case Vendor.AMD:
		info.acpi.tm	= (regs.edx & BIT!(4)) != 0;
		info.tech.turboboost	= (regs.edx & BIT!(9)) != 0;
		break;
	default:
	}
	
	info.extras.rdtsc_invariant	= (regs.edx & BIT!(8)) != 0;
	
	if (info.max_ext_leaf < 0x8000_0008) goto L_CACHE_INFO;
	
	//
	// Leaf 8000_0008H
	//
	
	asmcpuid(regs, 0x8000_0008);
	
	switch (info.vendor_id) {
	case Vendor.Intel:
		info.cache.wbnoinvd	= (regs.ebx & BIT!(9)) != 0;
		break;
	case Vendor.AMD:
		info.sec.ibpb	= (regs.ebx & BIT!(12)) != 0;
		info.sec.ibrs	= (regs.ebx & BIT!(14)) != 0;
		info.sec.stibp	= (regs.ebx & BIT!(15)) != 0;
		info.sec.ibrs_on	= (regs.ebx & BIT!(16)) != 0;
		info.sec.stibp_on	= (regs.ebx & BIT!(17)) != 0;
		info.sec.ibrs_pref	= (regs.ebx & BIT!(18)) != 0;
		info.sec.ssbd	= (regs.ebx & BIT!(24)) != 0;
		info.cores.logical	= (cast(ubyte)regs.ecx) + 1;
		break;
	default:
	}

	info.mem.b_8000_0008_ax = cast(ushort)regs.eax; // info.addr_phys_bits, info.addr_line_bits

	if (info.max_ext_leaf < 0x8000_000A) goto L_CACHE_INFO;
	
	//
	// Leaf 8000_000AH
	//
	
	asmcpuid(regs, 0x8000_000A);
	
	switch (info.vendor_id) {
	case Vendor.AMD:
		info.virt.version_	= cast(ubyte)regs.eax; // EAX[7:0]
		info.virt.apivc	= (regs.edx & BIT!(13)) != 0;
		break;
	default:
	}

	//if (info.max_ext_leaf < ...) goto L_CACHE_INFO;
	
L_CACHE_INFO:
	// Cache information
	// - done at the very end since we may need prior information
	//   - e.g. amd cpuid.8000_0008h
	// - maxleaf < 4 is too old/rare these days (es. for D programs)
	
	info.cache.levels = 0;
	CACHEINFO *ca = cast(CACHEINFO*)info.cache.level;
	
	ushort sc = void;	/// raw cores shared across cache level
	ushort crshrd = void;	/// actual count of shared cores
	ubyte type = void;
	ushort clevel;
	switch (info.vendor_id) {
	case Vendor.Intel:
		//TODO: Intel cache 1FH
		//if (info.max_leaf < 0x1f)
		//	GOTO L_CACHE_INTEL_BH;
		if (info.max_leaf < 0xb)
			goto L_CACHE_INTEL_4H;

		// Usually, ECX=1 will hold EBX=4 (cores)
		// With HTT, ECX=2 could hold EBX=8 (logical)
L_CACHE_INTEL_BH:
		asmcpuid(regs, 11, clevel);

		if (cast(ushort)regs.eax == 0) goto L_CACHE_INTEL_4H;

		switch (cast(ubyte)(regs.ecx >> 8)) {
		case 1: // Core
			info.cores.logical = cast(ushort)regs.ebx;
			break;
		case 2: // SMT
			info.cores.logical = cast(ushort)regs.ebx;
			break;
		default: assert(0, "implement cache type");
		}

		++clevel;
		goto L_CACHE_INTEL_BH;
		
L_CACHE_INTEL_4H:
		asmcpuid(regs, 4, info.cache.levels);
		
		type = regs.eax & CACHE_MASK; // EAX[4:0]
		if (type == 0) break;
		if (info.cache.levels >= CACHE_MAX_LEVEL) break;
		
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
		
		if (info.cores.logical == 0) // skip if already populated
			info.cores.logical = (regs.eax >> 26) + 1;	// EAX[31:26]
		
		crshrd = (((regs.eax >> 14) & 2047) + 1);	// EAX[25:14]
		sc = cast(ushort)(info.cores.logical / crshrd); // cast for ldc 0.17.1
		ca.sharedCores = sc ? sc : 1;
		version (Trace) trace(
			"intel.4h logical=%u shared=%u crshrd=%u sc=%u",
			info.cores.logical, ca.sharedCores, crshrd, sc);
		
		++info.cache.levels; ++ca;
		goto L_CACHE_INTEL_4H;
	case Vendor.AMD:
		if (info.max_ext_leaf < 0x8000_001D)
			goto L_CACHE_AMD_EXT_5H;
		
		//
		// AMD newer cache method
		//
		
L_CACHE_AMD_EXT_1DH: // Almost the same as Intel's
		asmcpuid(regs, 0x8000_001D, info.cache.levels);
		
		type = regs.eax & CACHE_MASK; // EAX[4:0]
		if (type == 0) break;
		if (info.cache.levels >= CACHE_MAX_LEVEL) break;
		
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
		sc = cast(ushort)(info.cores.logical / crshrd); // cast for ldc 0.17.1
		ca.sharedCores = sc ? sc : 1;

		version (Trace) trace("amd.ext.1dh logical=%u shared=%u crshrd=%u sc=%u",
			info.cores.logical, ca.sharedCores, crshrd, sc);
		
		++info.cache.levels; ++ca;
		goto L_CACHE_AMD_EXT_1DH;
		
		//
		// AMD legacy cache
		//
		
L_CACHE_AMD_EXT_5H:
		asmcpuid(regs, 0x8000_0005);
		
		info.cache.level[0].level = 1; // L1
		info.cache.level[0].type = 'D'; // data
		info.cache.level[0].__bundle1 = regs.ecx;
		info.cache.level[0].size = info.cache.level[0]._amdsize;
		info.cache.level[1].level = 1; // L1
		info.cache.level[1].type = 'I'; // instructions
		info.cache.level[1].__bundle1 = regs.edx;
		info.cache.level[1].size = info.cache.level[1]._amdsize;
		
		info.cache.levels = 2;
		
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
			info.cache.level[2].level = 2; // L2
			info.cache.level[2].type = 'U'; // unified
			info.cache.level[2].ways = _amd_cache_ways[_amd_ways_l2];
			info.cache.level[2].size = regs.ecx >> 16;
			info.cache.level[2].sets = (regs.ecx >> 8) & 7;
			info.cache.level[2].linesize = cast(ubyte)regs.ecx;
			
			info.cache.levels = 3;
			
			ubyte _amd_ways_l3 = (regs.edx >> 12) & 15;
			if (_amd_ways_l3) {
				info.cache.level[3].level = 3;  // L3
				info.cache.level[3].type = 'U'; // unified
				info.cache.level[3].ways = _amd_cache_ways[_amd_ways_l3];
				info.cache.level[3].size = ((regs.edx >> 18) + 1) * 512;
				info.cache.level[3].sets = (regs.edx >> 8) & 7;
				info.cache.level[3].linesize = cast(ubyte)(regs.edx & 0x7F);
				
				info.cache.levels = 4;
			}
		}
		break;
	default:
	}
}