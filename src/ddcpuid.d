/**
 * x86 CPU Identification tool
 *
 * This was initially used internally, so it's pretty unfriendly.
 *
 * The best way to use this module would be:
 * ---
 * CPUINFO info;     // Important to let the struct init to zero!
 * getLeaves(info);  // Get maximum CPUID leaves (mandatory step before info)
 * getInfo(info);    // Fill CPUINFO structure (optional)
 * ---
 *
 * Then checking the corresponding field:
 * ---
 * if (info.extensions.amx.xfd) {
 *   // Intel AMX with AMX_XFD is available
 * } else {
 *   // Feature unavailable
 * }
 * ---
 *
 * See the CPUINFO structure for available fields.
 *
 * To further understand these fields, it's encouraged to consult the technical manual.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: © 2016-2021 dd86k
 * License: MIT
 */
module ddcpuid;

// NOTE: Please no naked assembler.
//       I'd rather let the compiler deal with a little bit of prolog and
//       epilog than slamming my head into my desk violently trying to match
//       every operating system ABI, compiler versions, and major compilers.
//       Besides, final compiled binary is plenty fine on every compiler.
// NOTE: GAS syntax reminder
//       asm { "asm;\n\t" : "constraint" output : "constraint" input : clobbers }
// NOTE: bhyve doesn't not emit cpuid bits within 0x40000000, so not supported

//TODO: Consider restructing
//      Static structure return pointer
//      struct MAXLEAVES + struct CPUINFO
//TODO: Rename "stages" to L_STAGE_EXTENDED/L_STAGE_TOPOLOGY.
//TODO: Tiny pure function to just (uint reg, int bit)

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

enum DDCPUID_VERSION   = "0.19.1";	/// Library version
private enum CACHE_LEVELS = 6;	/// For buffer
private enum CACHE_MAX_LEVEL = CACHE_LEVELS - 1;
private enum VENDOR_OFFSET     = CPUINFO.vendorString.offsetof;
private enum BRAND_OFFSET      = CPUINFO.brandString.offsetof;
private enum VIRTVENDOR_OFFSET = CPUINFO.virt.offsetof + CPUINFO.virt.vendorString.offsetof;

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

/// Registers structure used with the asmcpuid function.
struct REGISTERS {
	union {
		uint eax;
		ushort ax;
		struct { ubyte al, ah; }
	}
	union {
		uint ebx;
		ushort bx;
		struct { ubyte bl, bh; }
	}
	union {
		uint ecx;
		ushort cx;
		struct { ubyte cl, ch; }
	}
	union {
		uint edx;
		ushort dx;
		struct { ubyte dl, dh; }
	}
}
///
@system unittest {
	REGISTERS regs = void;
	regs.eax = 0xaabbccdd;
	assert(regs.eax == 0xaabbccdd);
	assert(regs.ax  == 0xccdd);
	assert(regs.al  == 0xdd);
	assert(regs.ah  == 0xcc);
}

/// CPU cache entry
struct CACHEINFO { align(1):
	deprecated union {
		package uint __bundle1;
		struct {
			ubyte linesize; /// Size of the line in bytes
			ubyte partitions_;	/// Number of partitions
			ubyte ways_;	/// Number of ways per line
			package ubyte _amdsize;	/// (AMD, legacy) Size in KiB
		}
	}
	ushort lineSize;	/// Size of the line in bytes.
	union {
		ushort partitions;	/// Number of partitions.
		ushort lines;	/// AMD legacy way of saying sets.
	}
	ushort ways;	/// Number of ways per line.
	uint sets; /// Number of cache sets.
	/// Cache size in kilobytes.
	// (Ways + 1) * (Partitions + 1) * (LineSize + 1) * (Sets + 1)
	// (EBX[31:22] + 1) * (EBX[21:12] + 1) * (EBX[11:0] + 1) * (ECX + 1)
	uint size;
	/// Number of CPU cores sharing this cache.
	ushort sharedCores;
	/// Cache feature, bit flags.
	/// - Bit 0: Self Initializing cache
	/// - Bit 1: Fully Associative cache
	/// - Bit 2: No Write-Back Invalidation (toggle)
	/// - Bit 3:  Cache Inclusiveness (toggle)
	/// - Bit 4: Complex Cache Indexing (toggle)
	ushort features;
	ubyte level;	/// Cache level: L1, L2, etc.
	char type = 0;	/// Type entry character: 'D'=Data, 'I'=Instructions, 'U'=Unified
}

/// CPU information structure
struct CPUINFO { align(1):
	uint maxLeaf;	/// Highest cpuid leaf
	uint maxLeafVirt;	/// Highest cpuid virtualization leaf
	uint maxLeafExtended;	/// Highest cpuid extended leaf
	
	// Vendor strings
	
	union {
		package uint[3] vendor32;	/// Vendor 32-bit parts
		char[12] vendorString;	/// Vendor String
	}
	union {
		package uint[12] brand32;	// For init
		char[48] brandString;	/// Processor Brand String
	}
	union {
		package uint vendorId32;
		Vendor vendorId;	/// Validated vendor ID
	}
	ubyte brandIndex;	/// Brand string index (not used)
	
	// Core
	
	/// Contains the information on the number of cores.
	struct Cores {
		ushort logical;	/// Logical cores in this processor
		ushort physical;	/// Physical cores in this processor
	}
	align(2) Cores cores;	/// Processor package cores
	
	// Identifier
	
	uint identifier;	/// Raw identifier (CPUID.01h.EAX)
	ushort family;	/// Effective family identifier
	ushort model;	/// Effective model identifier
//	const(char) *microArchitecture;	/// Microarchitecture name string
	ubyte familyBase;	/// Base family identifier
	ubyte familyExtended;	/// Extended family identifier
	ubyte modelBase;	/// Base model identifier
	ubyte modelExtended;	/// Extended model identifier
	ubyte stepping;	/// Stepping revision
	ubyte type;	/// Processor type number
	const(char) *typeString;	/// Processor type string.
	
	/// Contains processor extensions.
	/// Extensions contain a variety of instructions to aid particular
	/// tasks.
	struct Extensions {
		bool fpu;	/// On-Chip x87 FPU
		bool f16c;	/// Float16 Conversions
		bool mmx;	/// MMX
		bool mmxExtended;	/// MMX Extended
		bool _3DNow;	/// 3DNow!
		bool _3DNowExtended;	/// 3DNow! Extended
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
	}
	align(2) Extensions extensions;	/// Extensions
		
	struct SSE {
		bool sse;	/// Streaming SIMD Extensions
		bool sse2;	/// SSE2
		bool sse3;	/// SSE3
		bool ssse3;	/// SSSE3
		bool sse41;	/// SSE4.1
		bool sse42;	/// SSE4.2
		bool sse4a;	/// SSE4a
	}
	align(2) SSE sse;	/// Streaming SIMD Extensions
	
	struct AVX {
		bool avx;	/// Advanced Vector eXtension
		bool avx2;	/// AVX2
		bool avx512f;	/// AVX512
		bool avx512er;	/// AVX512_ER
		bool avx512pf;	/// AVX512_PF
		bool avx512cd;	/// AVX512_CD
		bool avx512dq;	/// AVX512_DQ
		bool avx512bw;	/// AVX512_BW
		bool avx512vl;	/// AVX512_VL
		bool avx512_ifma;	/// AVX512_IFMA
		bool avx512_vbmi;	/// AVX512_VBMI
		bool avx512_vbmi2;	/// AVX512_VBMI2
		bool avx512_gfni;	/// AVX512_GFNI
		bool avx512_vaes;	/// AVX512_VAES
		bool avx512_vnni;	/// AVX512_VNNI
		bool avx512_bitalg;	/// AVX512_BITALG
		bool avx512_vpopcntdq;	/// AVX512_VPOPCNTDQ
		bool avx512_4vnniw;	/// AVX512_4VNNIW
		bool avx512_4fmaps;	/// AVX512_4FMAPS
		bool avx512_bf16;	/// AVX512_BF16
		bool avx512_vp2intersect;	/// AVX512_VP2INTERSECT
	}
	align(2) AVX avx;	/// Advanced Vector eXtension
	
	struct AMX {
		bool enabled;	/// Advanced Matrix eXtension
		bool bf16;	/// AMX_BF16
		bool int8;	/// AMX_INT8
		bool xtilecfg;	/// AMX_XTILECFG
		bool xtiledata;	/// AMX_XTILEDATA
		bool xfd;	/// AMX_XFD
	}
	align(2) AMX amx;	/// Intel AMX
	
	struct SGX {
		bool supported;	/// If SGX is supported (and enabled)
		bool sgx1;	/// SGX1
		bool sgx2;	/// SGX2
		ubyte maxSize;	/// 2^n maximum enclave size in non-64-bit
		ubyte maxSize64;	/// 2^n maximum enclave size in 64-bit
	}
	align(2) SGX sgx;	/// Intel SGX
	
	/// Additional instructions. Often not part of extensions.
	struct Extras {
		bool pclmulqdq;	/// PCLMULQDQ instruction
		bool monitor;	/// MONITOR and MWAIT instructions
		ushort mwaitMin;	/// (With MONITOR+MWAIT) MWAIT minimum size in bytes
		ushort mwaitMax;	/// (With MONITOR+MWAIT) MWAIT maximum size in bytes
		bool cmpxchg8b;	/// CMPXCHG8B
		bool cmpxchg16b;	/// CMPXCHG16B instruction
		bool movbe;	/// MOVBE instruction
		bool rdrand;	/// RDRAND instruction
		bool rdseed;	/// RDSEED instruction
		bool rdmsr;	/// RDMSR instruction
		bool sysenter;	/// SYSENTER and SYSEXIT instructions
		bool rdtsc;	/// RDTSC instruction
		bool rdtscDeadline;	/// (With RDTSC) IA32_TSC_DEADLINE MSR
		bool rdtscInvariant;	/// (With RDTSC) Timestamp counter invariant of C/P/T-state
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
		bool htt;	/// (HTT) HyperThreading Technology
	}
	align(2) Technologies tech;	/// Processor technologies
	
	/// Cache information.
	struct CacheInfo {
		uint levels;
		CACHEINFO[CACHE_LEVELS] level;
		bool clflush;	/// CLFLUSH instruction
		ubyte clflushLinesize;	/// Linesize of CLFLUSH in bytes
		bool clflushopt;	/// CLFLUSH instruction
		bool cnxtId;	/// L1 Context ID
		bool ss;	/// SelfSnoop
		bool prefetchw;	/// PREFETCHW instruction
		bool invpcid;	/// INVPCID instruction
		bool wbnoinvd;	/// WBNOINVD instruction
	}
	align(2) CacheInfo cache;	/// Cache information
	
	/// ACPI information.
	struct SysInfo {
		bool available;	/// ACPI
		bool apic;	/// APIC
		bool x2apic;	/// x2APIC
		bool arat;	/// Always-Running-APIC-Timer
		bool tm;	/// Thermal Monitor
		bool tm2;	/// Thermal Monitor 2
		ubyte maxApicId;	/// Maximum APIC ID
		ubyte apicId;	/// Initial APIC ID (running core where CPUID was called)
	}
	align(2) SysInfo sys;	/// System features
	
	/// Virtualization features. If a paravirtual interface is available,
	/// its information will be found here.
	struct Virtualization {
		bool available;	/// Intel VT-x/AMD-V
		ubyte version_;	/// (AMD) Virtualization platform version
		bool vme;	/// Enhanced vm8086
		bool apicv;	/// (AMD) APICv. Intel's is available via a MSR.
		union {
			package uint[3] vendor32;
			char[12] vendorString;	/// Paravirtualization interface vendor string
		}
		union {
			package uint vendorId32;
			VirtVendor vendorId;	/// Effective paravirtualization vendor id
		}
		
		struct VBox {
			uint tsc_freq_khz;	/// (VBox) Timestamp counter frequency in KHz
			uint apic_freq_khz;	/// (VBox) Paravirtualization API KHz frequency
		}
		VBox vbox;
		
		struct KVM {
			bool feature_clocksource;	/// (KVM) kvmclock interface
			bool feature_nop_io_delay;	/// (KVM) No delays required on I/O operations
			bool feature_mmu_op;	/// (KVM) Deprecated
			bool feature_clocksource2;	/// (KVM) Remapped kvmclock interface
			bool feature_async_pf;	/// (KVM) Asynchronous Page Fault
			bool feature_steal_time;	/// (KVM) Steal time
			bool feature_pv_eoi;	/// (KVM) Paravirtualized End Of the Interrupt handler
			bool feature_pv_unhault;	/// (KVM) Paravirtualized spinlock
			bool feature_pv_tlb_flush;	/// (KVM) Paravirtualized TLB flush
			bool feature_async_pf_vmexit;	/// (KVM) Asynchronous Page Fault at VM exit
			bool feature_pv_send_ipi;	/// (KVM) Paravirtualized SEBD inter-processor-interrupt
			bool feature_pv_poll_control;	/// (KVM) Host-side polling on HLT
			bool feature_pv_sched_yield;	/// (KVM) paravirtualized scheduler yield
			bool feature_clocsource_stable_bit;	/// (KVM) kvmclock warning
			bool hint_realtime;	/// (KVM) vCPUs are never preempted for an unlimited amount of time
		}
		KVM kvm;
		
		struct HyperV {
			ushort guest_vendor_id;	/// (Hyper-V) Paravirtualization Guest Vendor ID
			ushort guest_build;	/// (Hyper-V) Paravirtualization Guest Build number
			ubyte guest_os;	/// (Hyper-V) Paravirtualization Guest OS ID
			ubyte guest_major;	/// (Hyper-V) Paravirtualization Guest OS Major version
			ubyte guest_minor;	/// (Hyper-V) Paravirtualization Guest OS Minor version
			ubyte guest_service;	/// (Hyper-V) Paravirtualization Guest Service ID
			bool guest_opensource;	/// (Hyper-V) Paravirtualization Guest additions open-source
			bool base_feat_vp_runtime_msr;	/// (Hyper-V) Virtual processor runtime MSR
			bool base_feat_part_time_ref_count_msr;	/// (Hyper-V) Partition reference counter MSR
			bool base_feat_basic_synic_msrs;	/// (Hyper-V) Basic Synthetic Interrupt Controller MSRs
			bool base_feat_stimer_msrs;	/// (Hyper-V) Synthetic Timer MSRs
			bool base_feat_apic_access_msrs;	/// (Hyper-V) APIC access MSRs (EOI, ICR, TPR)
			bool base_feat_hypercall_msrs;	/// (Hyper-V) Hypercalls API MSRs
			bool base_feat_vp_id_msr;	/// (Hyper-V) vCPU index MSR
			bool base_feat_virt_sys_reset_msr;	/// (Hyper-V) Virtual system reset MSR
			bool base_feat_stat_pages_msr;	/// (Hyper-V) Statistic pages MSRs
			bool base_feat_part_ref_tsc_msr;	/// (Hyper-V) Partition reference timestamp counter MSR
			bool base_feat_guest_idle_state_msr;	/// (Hyper-V) Virtual guest idle state MSR
			bool base_feat_timer_freq_msrs;	/// (Hyper-V) Timer frequency MSRs (TSC and APIC)
			bool base_feat_debug_msrs;	/// (Hyper-V) Debug MSRs
			bool part_flags_create_part;	/// (Hyper-V) Partitions can be created
			bool part_flags_access_part_id;	/// (Hyper-V) Partitions IDs can be accessed
			bool part_flags_access_memory_pool;	/// (Hyper-V) Memory pool can be accessed
			bool part_flags_adjust_msg_buffers;	/// (Hyper-V) Possible to adjust message buffers
			bool part_flags_post_msgs;	/// (Hyper-V) Possible to send messages
			bool part_flags_signal_events;	/// (Hyper-V) Possible to signal events
			bool part_flags_create_port;	/// (Hyper-V) Possible to create ports
			bool part_flags_connect_port;	/// (Hyper-V) Possible to connect to ports
			bool part_flags_access_stats;	/// (Hyper-V) Can access statistics
			bool part_flags_debugging;	/// (Hyper-V) Debugging features available
			bool part_flags_cpu_mgmt;	/// (Hyper-V) Processor management available
			bool part_flags_cpu_profiler;	/// (Hyper-V) Processor profiler available
			bool part_flags_expanded_stack_walk;	/// (Hyper-V) Extended stack walking available
			bool part_flags_access_vsm;	/// (Hyper-V) Virtual system monitor available
			bool part_flags_access_vp_regs;	/// (Hyper-V) Virtual private registers available
			bool part_flags_extended_hypercalls;	/// (Hyper-V) Extended hypercalls API available
			bool part_flags_start_vp;	/// (Hyper-V) Virtual processor has started
			bool pm_max_cpu_power_state_c0;	/// (Hyper-V) Processor C0 is maximum state
			bool pm_max_cpu_power_state_c1;	/// (Hyper-V) Processor C1 is maximum state
			bool pm_max_cpu_power_state_c2;	/// (Hyper-V) Processor C2 is maximum state
			bool pm_max_cpu_power_state_c3;	/// (Hyper-V) Processor C3 is maximum state
			bool pm_hpet_reqd_for_c3;	/// (Hyper-V) High-precision event timer required for C3 state
			bool misc_feat_mwait;	/// (Hyper-V) MWAIT instruction available for guest
			bool misc_feat_guest_debugging;	/// (Hyper-V) Guest supports debugging
			bool misc_feat_perf_mon;	/// (Hyper-V) Performance monitor support available
			bool misc_feat_pcpu_dyn_part_event;	/// (Hyper-V) Physicap CPU dynamic partitioning event available
			bool misc_feat_xmm_hypercall_input;	/// (Hyper-V) Hypercalls via XMM registers available
			bool misc_feat_guest_idle_state;	/// (Hyper-V) Virtual guest supports idle state
			bool misc_feat_hypervisor_sleep_state;	/// (Hyper-V) Hypervisor supports sleep
			bool misc_feat_query_numa_distance;	/// (Hyper-V) NUMA distance query available
			bool misc_feat_timer_freq;	/// (Hyper-V) Determining timer frequencies available
			bool misc_feat_inject_synmc_xcpt;	/// (Hyper-V) Support for injecting synthetic machine checks
			bool misc_feat_guest_crash_msrs;	/// (Hyper-V) Guest crash MSR available
			bool misc_feat_debug_msrs;	/// (Hyper-V) Debug MSR available
			bool misc_feat_npiep1;	/// (Hyper-V) Documentation unavailable
			bool misc_feat_disable_hypervisor;	/// (Hyper-V) Hypervisor can be disabled
			bool misc_feat_ext_gva_range_for_flush_va_list;	/// (Hyper-V) Extended guest virtual address (GVA) ranges for FlushVirtualAddressList available
			bool misc_feat_hypercall_output_xmm;	/// (Hyper-V) Returning hypercall output via XMM registers available
			bool misc_feat_sint_polling_mode;	/// (Hyper-V) Synthetic interrupt source polling mode available
			bool misc_feat_hypercall_msr_lock;	/// (Hyper-V) Hypercall MISR lock feature available
			bool misc_feat_use_direct_synth_msrs;	/// (Hyper-V) Possible to directly use synthetic MSRs
			bool hint_hypercall_for_process_switch;	/// (Hyper-V) Guest should use the Hypercall API for address space switches rather than MOV CR3
			bool hint_hypercall_for_tlb_flush;	/// (Hyper-V) Guest should use the Hypercall API for local TLB flushes rather than INVLPG/MOV CR3
			bool hint_hypercall_for_tlb_shootdown;	/// (Hyper-V) Guest should use the Hypercall API for inter-CPU TLB flushes rather than inter-processor-interrupts (IPI)
			bool hint_msr_for_apic_access;	/// (Hyper-V) Guest should use the MSRs for APIC access (EOI, ICR, TPR) rather than memory-mapped input/output (MMIO)
			bool hint_msr_for_sys_reset;	/// (Hyper-V) Guest should use the hypervisor-provided MSR for a system reset instead of traditional methods
			bool hint_relax_time_checks;	/// (Hyper-V) Guest should relax timer-related checks (watchdogs/deadman timeouts) that rely on timely deliver of external interrupts
			bool hint_dma_remapping;	/// (Hyper-V) Guest should use the direct memory access (DMA) remapping
			bool hint_interrupt_remapping;	/// (Hyper-V) Guest should use the interrupt remapping
			bool hint_x2apic_msrs;	/// (Hyper-V) Guest should use the X2APIC MSRs rather than memory mapped input/output (MMIO)
			bool hint_deprecate_auto_eoi;	/// (Hyper-V) Guest should deprecate Auto EOI (End Of Interrupt) features
			bool hint_synth_cluster_ipi_hypercall;	/// (Hyper-V) Guest should use the SyntheticClusterIpi Hypercall
			bool hint_ex_proc_masks_interface;	/// (Hyper-V) Guest should use the newer ExProcessMasks interface over ProcessMasks
			bool hint_nested_hyperv;	/// (Hyper-V) Hyper-V instance is nested within a Hyper-V partition
			bool hint_int_for_mbec_syscalls;	/// (Hyper-V) Guest should use the INT instruction for Mode Based Execution Control (MBEC) system calls
			bool hint_nested_enlightened_vmcs_interface;	/// (Hyper-V) Guest should use enlightened Virtual Machine Control Structure (VMCS) interfaces and nested enlightenment
			bool host_feat_avic;	/// (Hyper-V) Hypervisor is using the Advanced Virtual Interrupt Controller (AVIC) overlay
			bool host_feat_msr_bitmap;	/// (Hyper-V) Hypervisor is using MSR bitmaps
			bool host_feat_perf_counter;	/// (Hyper-V) Hypervisor supports the architectural performance counter
			bool host_feat_nested_paging;	/// (Hyper-V) Hypervisor is using nested paging
			bool host_feat_dma_remapping;	/// (Hyper-V) Hypervisor is using direct memory access (DMA) remapping
			bool host_feat_interrupt_remapping;	/// (Hyper-V) Hypervisor is using interrupt remapping
			bool host_feat_mem_patrol_scrubber;	/// (Hyper-V) Hypervisor's memory patrol scrubber is present
			bool host_feat_dma_prot_in_use;	/// (Hyper-V) Hypervisor is using direct memory access (DMA) protection
			bool host_feat_hpet_requested;	/// (Hyper-V) Hypervisor requires a High Precision Event Timer (HPET)
			bool host_feat_stimer_volatile;	/// (Hyper-V) Hypervisor's synthetic timers are volatile
		}
		HyperV hv;
	}
	align(2) Virtualization virt;	/// Virtualization features
	
	/// Memory features.
	struct Memory {
		bool pae;	/// Physical Address Extension 
		bool pse;	/// Page Size Extension
		bool pse36;	/// 36-bit PSE
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
				ubyte physBits;	/// Memory physical bits
				ubyte lineBits;	/// Memory linear bits
			}
		}
	}
	align (2) Memory memory;	/// Memory features
	
	/// Debugging features.
	struct Debugging {
		bool mca;	/// Machine Check Architecture
		bool mce;	/// Machine Check Exception
		bool de;	/// Degging Extensions
		bool ds;	/// Debug Store
		bool dsCpl;	/// Debug Store - Curernt Privilege Level
		bool dtes64;	/// 64-bit Debug Store area
		bool pdcm;	/// Perfmon And Debug Capability
		bool sdbg;	/// Silicon Debug
		bool pbe;	/// Pending Break Enable
	}
	align(2) Debugging debugging;	/// Debugging feature
	
	/// Security features and mitigations.
	struct Security {
		bool ia32_arch_capabilities;	/// IA32_ARCH_CAPABILITIES MSR
		// NOTE: IA32_CORE_CAPABILITIES is currently empty
		bool ibpb;	/// Indirect Branch Predictor Barrier
		bool ibrs;	/// Indirect Branch Restricted Speculation
		bool ibrsAlwaysOn;	/// IBRS always enabled
		bool ibrsPreferred;	/// IBRS preferred over software solution
		bool stibp;	/// Single Thread Indirect Branch Predictors
		bool stibpAlwaysOn;	/// STIBP always enabled
		bool ssbd;	/// Speculative Store Bypass Disable
		bool l1dFlush;	/// L1D Cache Flush
		bool md_clear;	/// MDS mitigation
		bool cetIbt;	/// (Control-flow Enforcement Technology) Indirect Branch Tracking 
		bool cetSs;	/// (Control-flow Enforcement Technology) Shadow Stack
	}
	align(2) Security security;	/// Security features
	
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
private enum CACHE_MASK = 7; // Max 31
private immutable const(char)* CACHE_TYPE = "?DIU????";

private
immutable const(char)*[4] PROCESSOR_TYPE = [ "Original", "OverDrive", "Dual", "Reserved" ];

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
			mov [EDI + info.maxLeaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [EDI + info.maxLeafVirt.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [EDI + info.maxLeafExtended.offsetof], EAX;
		} else version (X86_64) asm {
			mov RDI, info;
			mov EAX, 0;
			cpuid;
			mov [RDI + info.maxLeaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [RDI + info.maxLeafVirt.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [RDI + info.maxLeafExtended.offsetof], EAX;
		}
	} else version (GDC) {
		asm {
			"cpuid"
			: "=a" (info.maxLeaf)
			: "a" (0);
		}
		asm {
			"cpuid"
			: "=a" (info.maxLeafVirt)
			: "a" (0x40000000);
		}
		asm {
			"cpuid"
			: "=a" (info.maxLeafExtended)
			: "a" (0x80000000);
		}
	} else version (LDC) {
		version (X86) asm {
			lea EDI, info;
			mov EAX, 0;
			cpuid;
			mov [EDI + info.maxLeaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [EDI + info.maxLeafVirt.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [EDI + info.maxLeafExtended.offsetof], EAX;
		} else version (X86_64) asm {
			lea RDI, info;
			mov EAX, 0;
			cpuid;
			mov [RDI + info.maxLeaf.offsetof], EAX;
			mov EAX, 0x4000_0000;
			cpuid;
			mov [RDI + info.maxLeafVirt.offsetof], EAX;
			mov EAX, 0x8000_0000;
			cpuid;
			mov [RDI + info.maxLeafExtended.offsetof], EAX;
		}
	}
	version (Trace) with(info) trace(
		"leaf=%x vleaf=%x eleaf=%x",
		maxLeaf, maxLeafVirt, maxLeafExtended);
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
		info.vendorId32 = 0;
		return;
	}
	
	info.vendorId32 = info.vendor32[0];
}

pragma(inline, false)
private
void getBrandExtended(ref CPUINFO info) {
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

// Avoids depending on C runtime for library.
/// Copy string, this exists solely for getBrandIndex
pragma(inline, false)
private
void strcpy48(ref char[48] dst, const(char) *src) {
	size_t i;
	for (; i < 48; ++i) {
		char c = src[i];
		dst[i] = c;
		if (c == 0) break;
	}
}

@system unittest {
	char[48] buffer = void;
	strcpy48(buffer, "e");
	assert(buffer[0] == 'e');
	assert(buffer[1] == 0);
}

/// Get the legacy processor brand string.
/// These indexes/tables were introduced in Intel's Pentium III.
/// AMD does not use them.
/// Params:
/// 	info = CPUINFO structure.
/// 	index = CPUID.01h.BL value.
pragma(inline, false)
private
void getBrandIndex(ref CPUINFO info, ubyte index) {
	switch (index) {
	case 1, 0xA, 0xF, 0x14:
		strcpy48(info.brandString, "Intel(R) Celeron(R)");
		return;
	case 2, 4:
		strcpy48(info.brandString, "Intel(R) Pentium(R) III");
		return;
	case 3:
		if (info.identifier == 0x6b1) goto case 1;
		strcpy48(info.brandString, "Intel(R) Pentium(R) III Xeon(R)");
		return;
	case 6:
		strcpy48(info.brandString, "Mobile Intel(R) Pentium(R) III");
		return;
	case 7, 0x13, 0x17: // Same as Intel(R) Celeron(R) M?
		strcpy48(info.brandString, "Mobile Intel(R) Celeron(R)");
		return;
	case 8, 9:
		strcpy48(info.brandString, "Intel(R) Pentium(R) 4");
		return;
	case 0xB:
		if (info.identifier == 0xf13) goto case 0xC;
	L_XEON: // Needed to avoid loop
		strcpy48(info.brandString, "Intel(R) Xeon(R)");
		return;
	case 0xC:
		strcpy48(info.brandString, "Intel(R) Xeon(R) MP");
		return;
	case 0xE:
		if (info.identifier == 0xf13) goto L_XEON;
		strcpy48(info.brandString, "Mobile Intel(R) Pentium(R) 4");
		return;
	case 0x11, 0x15: // Yes, really.
		strcpy48(info.brandString, "Mobile Genuine Intel(R)");
		return;
	case 0x12: strcpy48(info.brandString, "Intel(R) Celeron(R) M"); return;
	case 0x16: strcpy48(info.brandString, "Intel(R) Pentium(R) M"); return;
	default:   strcpy48(info.brandString, "Unknown"); return;
	}
}

pragma(inline, false)
private
void getBrandIdentifierIntel(ref CPUINFO info) {
	// This function exist for processors that does not support the
	// brand name table.
	// At least do i486SL-Pentium II
	switch (info.family) {
	case 5: // i586, Pentium
		if (info.model >= 4) {
			strcpy48(info.brandString, "Intel(R) Pentium(R) MMX");
			return;
		}
		strcpy48(info.brandString, "Intel(R) Pentium(R)");
		return;
	case 6: // i686, Pentium Pro
		if (info.model >= 3) {
			strcpy48(info.brandString, "Intel(R) Pentium(R) II");
			return;
		}
		strcpy48(info.brandString, "Intel(R) Pentium(R) Pro");
		return;
	default:
		strcpy48(info.brandString, "Unknown");
		return;
	}
}

pragma(inline, false)
private
void getBrandIdentifierAmd(ref CPUINFO info) {
	// This function exist for processors that does not support the
	// extended brand string which is the Am5x86 and AMD K-5 model 0.
	// K-5 model 1 has extended brand string so case 5 is only model 0.
	// AMD has no official names for these.
	switch (info.family) {
	case 4:  strcpy48(info.brandString, "AMD Am5x86"); return;
	case 5:  strcpy48(info.brandString, "AMD K5"); return;
	default: strcpy48(info.brandString, "Unknown"); return;
	}
}

/*pragma(inline, false)
private
void getMicroArchitectureName(ref CPUINFO info) {
	
}*/

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
		info.virt.vendorId = VirtVendor.HyperV;
		return;
	default:
		info.virt.vendorId32 = 0;
		return;
	}
	
	info.virt.vendorId32 = info.virt.vendor32[0];
	version (Trace) trace("id=%u", info.virt.vendorId32);
}

/// Fetch CPU information.
/// 
/// Here is a list of phases this function goes through:
/// 1. Get vendor string and ID
/// 2. Get brand string
/// 3. Get family IDs and basic information
/// 4. Get virtualization features
/// 5. Get extended features
/// 6. Get cache and core information
///
/// When a section is no longer capable of proceeding, it skips to the next
/// phase.
/// 
/// Params: info = CPUINFO structure
pragma(inline, false)
void getInfo(ref CPUINFO info) {
	ushort sc = void;	/// raw cores shared across cache level
	ushort crshrd = void;	/// actual count of shared cores
	ubyte type = void;	/// cache type
	ubyte mids = void;	/// maximum IDs to this cache
	REGISTERS regs = void;	/// registers
	
	getVendor(info);
	
	//
	// Leaf 1H
	//
	
	asmcpuid(regs, 1);
	
	// EAX
	info.identifier = regs.eax;
	info.stepping   = regs.eax & 15;       // EAX[3:0]
	info.modelBase  = regs.eax >>  4 & 15; // EAX[7:4]
	info.familyBase = regs.eax >>  8 & 15; // EAX[11:8]
	info.type       = regs.eax >> 12 & 3;  // EAX[13:12]
	info.typeString = PROCESSOR_TYPE[info.type];
	info.modelExtended   = regs.eax >> 16 & 15; // EAX[19:16]
	info.familyExtended  = cast(ubyte)(regs.eax >> 20); // EAX[27:20]
	
	switch (info.vendorId) {
	case Vendor.Intel:
		info.family = info.familyBase != 15 ?
			cast(ushort)info.familyBase :
			cast(ushort)(info.familyExtended + info.familyBase);
		
		info.model = info.familyBase == 6 || info.familyBase == 0 ?
			cast(ushort)((info.modelExtended << 4) + info.modelBase) :
			cast(ushort)info.modelBase; // DisplayModel = Model_ID;
		
		// ECX
		info.debugging.dtes64	= (regs.ecx & BIT!(2)) != 0;
		info.debugging.dsCpl	= (regs.ecx & BIT!(4)) != 0;
		info.virt.available	= (regs.ecx & BIT!(5)) != 0;
		info.tech.smx	= (regs.ecx & BIT!(6)) != 0;
		info.tech.eist	= (regs.ecx & BIT!(7)) != 0;
		info.sys.tm2	= (regs.ecx & BIT!(8)) != 0;
		info.cache.cnxtId	= (regs.ecx & BIT!(10)) != 0;
		info.debugging.sdbg	= (regs.ecx & BIT!(11)) != 0;
		info.misc.xtpr	= (regs.ecx & BIT!(14)) != 0;
		info.debugging.pdcm	= (regs.ecx & BIT!(15)) != 0;
		info.misc.pcid	= (regs.ecx & BIT!(17)) != 0;
		info.debugging.mca	= (regs.ecx & BIT!(18)) != 0;
		info.sys.x2apic	= (regs.ecx & BIT!(21)) != 0;
		info.extras.rdtscDeadline	= (regs.ecx & BIT!(24)) != 0;
		
		// EDX
		info.misc.psn	= (regs.edx & BIT!(18)) != 0;
		info.debugging.ds	= (regs.edx & BIT!(21)) != 0;
		info.sys.available	= (regs.edx & BIT!(22)) != 0;
		info.cache.ss	= (regs.edx & BIT!(27)) != 0;
		info.sys.tm	= (regs.edx & BIT!(29)) != 0;
		info.debugging.pbe	= regs.edx >= BIT!(31);
		
		// Brand string
		if (info.maxLeafExtended >= 0x8000_0004)
			getBrandExtended(info);
		else if (regs.bl)
			getBrandIndex(info, regs.bl);
		else
			getBrandIdentifierIntel(info);
		break;
	case Vendor.AMD:
		if (info.familyBase < 15) {
			info.family = info.familyBase;
			info.model = info.modelBase;
		} else {
			info.family = cast(ushort)(info.familyExtended + info.familyBase);
			info.model = cast(ushort)((info.modelExtended << 4) + info.modelBase);
		}
		
		// Brand string
		// NOTE: AMD processor never supported the string table.
		//       The Am486DX4 and Am5x86 processors do not support the extended brand string.
		//       The K5 model 0 does not support the extended brand string.
		//       The K5 model 1, 2, and 3 support the extended brand string.
		if (info.maxLeafExtended >= 0x8000_0004)
			getBrandExtended(info);
		else
			getBrandIdentifierAmd(info);
		break;
	default:
		strcpy48(info.brandString, "Unknown");
	}
	
	// EBX
	info.sys.apicId = regs.ebx >> 24;
	info.sys.maxApicId = cast(ubyte)(regs.ebx >> 16);
	info.cache.clflushLinesize = regs.bh;
	info.brandIndex = regs.bl;
	
	// ECX
	info.sse.sse3	= (regs.ecx & BIT!(0)) != 0;
	info.extras.pclmulqdq	= (regs.ecx & BIT!(1)) != 0;
	info.extras.monitor	= (regs.ecx & BIT!(3)) != 0;
	info.sse.ssse3	= (regs.ecx & BIT!(9)) != 0;
	info.extensions.fma3	= (regs.ecx & BIT!(12)) != 0;
	info.extras.cmpxchg16b	= (regs.ecx & BIT!(13)) != 0;
	info.sse.sse41	= (regs.ecx & BIT!(15)) != 0;
	info.sse.sse42	= (regs.ecx & BIT!(20)) != 0;
	info.extras.movbe	= (regs.ecx & BIT!(22)) != 0;
	info.extras.popcnt	= (regs.ecx & BIT!(23)) != 0;
	info.extensions.aes_ni	= (regs.ecx & BIT!(25)) != 0;
	info.extras.xsave	= (regs.ecx & BIT!(26)) != 0;
	info.extras.osxsave	= (regs.ecx & BIT!(27)) != 0;
	info.avx.avx	= (regs.ecx & BIT!(28)) != 0;
	info.extensions.f16c	= (regs.ecx & BIT!(29)) != 0;
	info.extras.rdrand	= (regs.ecx & BIT!(30)) != 0;
	
	// EDX
	info.extensions.fpu	= (regs.edx & BIT!(0)) != 0;
	info.virt.vme	= (regs.edx & BIT!(1)) != 0;
	info.debugging.de	= (regs.edx & BIT!(2)) != 0;
	info.memory.pse	= (regs.edx & BIT!(3)) != 0;
	info.extras.rdtsc	= (regs.edx & BIT!(4)) != 0;
	info.extras.rdmsr	= (regs.edx & BIT!(5)) != 0;
	info.memory.pae	= (regs.edx & BIT!(6)) != 0;
	info.debugging.mce	= (regs.edx & BIT!(7)) != 0;
	info.extras.cmpxchg8b	= (regs.edx & BIT!(8)) != 0;
	info.sys.apic	= (regs.edx & BIT!(9)) != 0;
	info.extras.sysenter	= (regs.edx & BIT!(11)) != 0;
	info.memory.mtrr	= (regs.edx & BIT!(12)) != 0;
	info.memory.pge	= (regs.edx & BIT!(13)) != 0;
	info.debugging.mca	= (regs.edx & BIT!(14)) != 0;
	info.extras.cmov	= (regs.edx & BIT!(15)) != 0;
	info.memory.pat	= (regs.edx & BIT!(16)) != 0;
	info.memory.pse36	= (regs.edx & BIT!(17)) != 0;
	info.cache.clflush	= (regs.edx & BIT!(19)) != 0;
	info.extensions.mmx	= (regs.edx & BIT!(23)) != 0;
	info.extras.fxsr	= (regs.edx & BIT!(24)) != 0;
	info.sse.sse	= (regs.edx & BIT!(25)) != 0;
	info.sse.sse2	= (regs.edx & BIT!(26)) != 0;
	info.tech.htt	= (regs.edx & BIT!(28)) != 0;
	
	// Legacy processor topology
	// It's done here rather than the end because even with CPUID.03h,
	// there are no extensions with processors of the time.
	if (info.maxLeaf < 4) goto L_EXTENDED;
	
	//
	// Leaf 5H
	//
	
	if (info.maxLeaf < 5) goto L_VIRT;
	
	asmcpuid(regs, 5);
	
	info.extras.mwaitMin = regs.ax;
	info.extras.mwaitMax = regs.bx;
	
	//
	// Leaf 6H
	//
	
	if (info.maxLeaf < 6) goto L_VIRT;
	
	asmcpuid(regs, 6);
	
	switch (info.vendorId) {
	case Vendor.Intel:
		info.tech.turboboost	= (regs.eax & BIT!(1)) != 0;
		info.tech.turboboost30	= (regs.eax & BIT!(14)) != 0;
		break;
	default:
	}
	
	info.sys.arat = (regs.eax & BIT!(2)) != 0;
	
	//
	// Leaf 7H
	//
	
	if (info.maxLeaf < 7) goto L_VIRT;
	
	asmcpuid(regs, 7);
	
	switch (info.vendorId) {
	case Vendor.Intel:
		// EBX
		info.sgx.supported	= (regs.ebx & BIT!(2)) != 0;
		info.memory.hle	= (regs.ebx & BIT!(4)) != 0;
		info.cache.invpcid	= (regs.ebx & BIT!(10)) != 0;
		info.memory.rtm	= (regs.ebx & BIT!(11)) != 0;
		info.avx.avx512f	= (regs.ebx & BIT!(16)) != 0;
		info.memory.smap	= (regs.ebx & BIT!(20)) != 0;
		info.avx.avx512er	= (regs.ebx & BIT!(27)) != 0;
		info.avx.avx512pf	= (regs.ebx & BIT!(26)) != 0;
		info.avx.avx512cd	= (regs.ebx & BIT!(28)) != 0;
		info.avx.avx512dq	= (regs.ebx & BIT!(17)) != 0;
		info.avx.avx512bw	= (regs.ebx & BIT!(30)) != 0;
		info.avx.avx512_ifma	= (regs.ebx & BIT!(21)) != 0;
		info.avx.avx512_vbmi	= regs.ebx >= BIT!(31);
		// ECX
		info.avx.avx512vl	= (regs.ecx & BIT!(1)) != 0;
		info.memory.pku	= (regs.ecx & BIT!(3)) != 0;
		info.memory.fsrepmov	= (regs.ecx & BIT!(4)) != 0;
		info.extensions.waitpkg	= (regs.ecx & BIT!(5)) != 0;
		info.avx.avx512_vbmi2	= (regs.ecx & BIT!(6)) != 0;
		info.security.cetSs	= (regs.ecx & BIT!(7)) != 0;
		info.avx.avx512_gfni	= (regs.ecx & BIT!(8)) != 0;
		info.avx.avx512_vaes	= (regs.ecx & BIT!(9)) != 0;
		info.avx.avx512_vnni	= (regs.ecx & BIT!(11)) != 0;
		info.avx.avx512_bitalg	= (regs.ecx & BIT!(12)) != 0;
		info.avx.avx512_vpopcntdq	= (regs.ecx & BIT!(14)) != 0;
		info.memory._5pl	= (regs.ecx & BIT!(16)) != 0;
		info.extras.cldemote	= (regs.ecx & BIT!(25)) != 0;
		info.extras.movdiri	= (regs.ecx & BIT!(27)) != 0;
		info.extras.movdir64b	= (regs.ecx & BIT!(28)) != 0;
		info.extras.enqcmd	= (regs.ecx & BIT!(29)) != 0;
		// EDX
		info.avx.avx512_4vnniw	= (regs.edx & BIT!(2)) != 0;
		info.avx.avx512_4fmaps	= (regs.edx & BIT!(3)) != 0;
		info.misc.uintr	= (regs.edx & BIT!(5)) != 0;
		info.avx.avx512_vp2intersect	= (regs.edx & BIT!(8)) != 0;
		info.security.md_clear	= (regs.edx & BIT!(10)) != 0;
		info.extras.serialize	= (regs.edx & BIT!(14)) != 0;
		info.memory.tsxldtrk	= (regs.edx & BIT!(16)) != 0;
		info.extras.pconfig	= (regs.edx & BIT!(18)) != 0;
		info.security.cetIbt	= (regs.edx & BIT!(20)) != 0;
		info.amx.bf16	= (regs.edx & BIT!(22)) != 0;
		info.amx.enabled	= (regs.edx & BIT!(24)) != 0;
		info.amx.int8	= (regs.edx & BIT!(25)) != 0;
		info.security.ibrs = (regs.edx & BIT!(26)) != 0;
		info.security.stibp	= (regs.edx & BIT!(27)) != 0;
		info.security.l1dFlush	= (regs.edx & BIT!(28)) != 0;
		info.security.ia32_arch_capabilities	= (regs.edx & BIT!(29)) != 0;
		info.security.ssbd	= regs.edx >= BIT!(31);
		break;
	default:
	}

	// ebx
	info.misc.fsgsbase	= (regs.ebx & BIT!(0)) != 0;
	info.extensions.bmi1	= (regs.ebx & BIT!(3)) != 0;
	info.avx.avx2	= (regs.ebx & BIT!(5)) != 0;
	info.memory.smep	= (regs.ebx & BIT!(7)) != 0;
	info.extensions.bmi2	= (regs.ebx & BIT!(8)) != 0;
	info.extras.rdseed	= (regs.ebx & BIT!(18)) != 0;
	info.extensions.adx	= (regs.ebx & BIT!(19)) != 0;
	info.cache.clflushopt	= (regs.ebx & BIT!(23)) != 0;
	info.extensions.sha	= (regs.ebx & BIT!(29)) != 0;
	// ecx
	info.extras.rdpid	= (regs.ecx & BIT!(22)) != 0;
	
	//
	// Leaf 7H(ECX=01h)
	//
	
	switch (info.vendorId) {
	case Vendor.Intel:
		asmcpuid(regs, 7, 1);
		// a
		info.avx.avx512_bf16	= (regs.eax & BIT!(5)) != 0;
		info.memory.lam	= (regs.eax & BIT!(26)) != 0;
		break;
	default:
	}
	
	//
	// Leaf DH
	//
	
	if (info.maxLeaf < 0xd) goto L_VIRT;
	
	switch (info.vendorId) {
	case Vendor.Intel:
		asmcpuid(regs, 0xd);
		info.amx.xtilecfg	= (regs.eax & BIT!(17)) != 0;
		info.amx.xtiledata	= (regs.eax & BIT!(18)) != 0;
		break;
	default:
	}
	
	//
	// Leaf DH(ECX=01h)
	//
	
	switch (info.vendorId) {
	case Vendor.Intel:
		asmcpuid(regs, 0xd, 1);
		info.amx.xfd	= (regs.eax & BIT!(18)) != 0;
		break;
	default:
	}
	
	//
	// Leaf 12H
	//
	
	if (info.maxLeaf < 0x12) goto L_VIRT;
	
	switch (info.vendorId) {
	case Vendor.Intel:
		asmcpuid(regs, 0x12);
		info.sgx.sgx1 = (regs.al & BIT!(0)) != 0;
		info.sgx.sgx2 = (regs.al & BIT!(1)) != 0;
		info.sgx.maxSize   = regs.dl;
		info.sgx.maxSize64 = regs.dh;
		break;
	default:
	}
	
	//
	// Leaf 4000_000H
	//
	
L_VIRT:
	if (info.maxLeafVirt < 0x4000_0000) goto L_EXTENDED;
	
	getVirtVendor(info);
	
	//
	// Leaf 4000_0001H
	//

	if (info.maxLeafVirt < 0x4000_0001) goto L_EXTENDED;
	
	switch (info.virt.vendorId) {
	case VirtVendor.KVM:
		asmcpuid(regs, 0x4000_0001);
		info.virt.kvm.feature_clocksource	= (regs.eax & BIT!(0)) != 0;
		info.virt.kvm.feature_nop_io_delay	= (regs.eax & BIT!(1)) != 0;
		info.virt.kvm.feature_mmu_op	= (regs.eax & BIT!(2)) != 0;
		info.virt.kvm.feature_clocksource2	= (regs.eax & BIT!(3)) != 0;
		info.virt.kvm.feature_async_pf	= (regs.eax & BIT!(4)) != 0;
		info.virt.kvm.feature_steal_time	= (regs.eax & BIT!(5)) != 0;
		info.virt.kvm.feature_pv_eoi	= (regs.eax & BIT!(6)) != 0;
		info.virt.kvm.feature_pv_unhault	= (regs.eax & BIT!(7)) != 0;
		info.virt.kvm.feature_pv_tlb_flush	= (regs.eax & BIT!(9)) != 0;
		info.virt.kvm.feature_async_pf_vmexit	= (regs.eax & BIT!(10)) != 0;
		info.virt.kvm.feature_pv_send_ipi	= (regs.eax & BIT!(11)) != 0;
		info.virt.kvm.feature_pv_poll_control	= (regs.eax & BIT!(12)) != 0;
		info.virt.kvm.feature_pv_sched_yield	= (regs.eax & BIT!(13)) != 0;
		info.virt.kvm.feature_clocsource_stable_bit	= (regs.eax & BIT!(24)) != 0;
		info.virt.kvm.hint_realtime	= (regs.edx & BIT!(0)) != 0;
		break;
	default:
	}
	
	//
	// Leaf 4000_002H
	//

	if (info.maxLeafVirt < 0x4000_0002) goto L_EXTENDED;
	
	switch (info.virt.vendorId) {
	case VirtVendor.HyperV:
		asmcpuid(regs, 0x4000_0002);
		info.virt.hv.guest_minor	= cast(ubyte)(regs.eax >> 24);
		info.virt.hv.guest_service	= cast(ubyte)(regs.eax >> 16);
		info.virt.hv.guest_build	= regs.ax;
		info.virt.hv.guest_opensource	= regs.edx >= BIT!(31);
		info.virt.hv.guest_vendor_id	= (regs.edx >> 16) & 0xFFF;
		info.virt.hv.guest_os	= regs.dh;
		info.virt.hv.guest_major	= regs.dl;
		break;
	default:
	}
	
	//
	// Leaf 4000_0003H
	//

	if (info.maxLeafVirt < 0x4000_0003) goto L_EXTENDED;
	
	switch (info.virt.vendorId) {
	case VirtVendor.HyperV:
		asmcpuid(regs, 0x4000_0003);
		info.virt.hv.base_feat_vp_runtime_msr	= (regs.eax & BIT!(0)) != 0;
		info.virt.hv.base_feat_part_time_ref_count_msr	= (regs.eax & BIT!(1)) != 0;
		info.virt.hv.base_feat_basic_synic_msrs	= (regs.eax & BIT!(2)) != 0;
		info.virt.hv.base_feat_stimer_msrs	= (regs.eax & BIT!(3)) != 0;
		info.virt.hv.base_feat_apic_access_msrs	= (regs.eax & BIT!(4)) != 0;
		info.virt.hv.base_feat_hypercall_msrs	= (regs.eax & BIT!(5)) != 0;
		info.virt.hv.base_feat_vp_id_msr	= (regs.eax & BIT!(6)) != 0;
		info.virt.hv.base_feat_virt_sys_reset_msr	= (regs.eax & BIT!(7)) != 0;
		info.virt.hv.base_feat_stat_pages_msr	= (regs.eax & BIT!(8)) != 0;
		info.virt.hv.base_feat_part_ref_tsc_msr	= (regs.eax & BIT!(9)) != 0;
		info.virt.hv.base_feat_guest_idle_state_msr	= (regs.eax & BIT!(10)) != 0;
		info.virt.hv.base_feat_timer_freq_msrs	= (regs.eax & BIT!(11)) != 0;
		info.virt.hv.base_feat_debug_msrs	= (regs.eax & BIT!(12)) != 0;
		info.virt.hv.part_flags_create_part	= (regs.ebx & BIT!(0)) != 0;
		info.virt.hv.part_flags_access_part_id	= (regs.ebx & BIT!(1)) != 0;
		info.virt.hv.part_flags_access_memory_pool	= (regs.ebx & BIT!(2)) != 0;
		info.virt.hv.part_flags_adjust_msg_buffers	= (regs.ebx & BIT!(3)) != 0;
		info.virt.hv.part_flags_post_msgs	= (regs.ebx & BIT!(4)) != 0;
		info.virt.hv.part_flags_signal_events	= (regs.ebx & BIT!(5)) != 0;
		info.virt.hv.part_flags_create_port	= (regs.ebx & BIT!(6)) != 0;
		info.virt.hv.part_flags_connect_port	= (regs.ebx & BIT!(7)) != 0;
		info.virt.hv.part_flags_access_stats	= (regs.ebx & BIT!(8)) != 0;
		info.virt.hv.part_flags_debugging	= (regs.ebx & BIT!(11)) != 0;
		info.virt.hv.part_flags_cpu_mgmt	= (regs.ebx & BIT!(12)) != 0;
		info.virt.hv.part_flags_cpu_profiler	= (regs.ebx & BIT!(13)) != 0;
		info.virt.hv.part_flags_expanded_stack_walk	= (regs.ebx & BIT!(14)) != 0;
		info.virt.hv.part_flags_access_vsm	= (regs.ebx & BIT!(16)) != 0;
		info.virt.hv.part_flags_access_vp_regs	= (regs.ebx & BIT!(17)) != 0;
		info.virt.hv.part_flags_extended_hypercalls	= (regs.ebx & BIT!(20)) != 0;
		info.virt.hv.part_flags_start_vp	= (regs.ebx & BIT!(21)) != 0;
		info.virt.hv.pm_max_cpu_power_state_c0	= (regs.ecx & BIT!(0)) != 0;
		info.virt.hv.pm_max_cpu_power_state_c1	= (regs.ecx & BIT!(1)) != 0;
		info.virt.hv.pm_max_cpu_power_state_c2	= (regs.ecx & BIT!(2)) != 0;
		info.virt.hv.pm_max_cpu_power_state_c3	= (regs.ecx & BIT!(3)) != 0;
		info.virt.hv.pm_hpet_reqd_for_c3	= (regs.ecx & BIT!(4)) != 0;
		info.virt.hv.misc_feat_mwait	= (regs.eax & BIT!(0)) != 0;
		info.virt.hv.misc_feat_guest_debugging	= (regs.eax & BIT!(1)) != 0;
		info.virt.hv.misc_feat_perf_mon	= (regs.eax & BIT!(2)) != 0;
		info.virt.hv.misc_feat_pcpu_dyn_part_event	= (regs.eax & BIT!(3)) != 0;
		info.virt.hv.misc_feat_xmm_hypercall_input	= (regs.eax & BIT!(4)) != 0;
		info.virt.hv.misc_feat_guest_idle_state	= (regs.eax & BIT!(5)) != 0;
		info.virt.hv.misc_feat_hypervisor_sleep_state	= (regs.eax & BIT!(6)) != 0;
		info.virt.hv.misc_feat_query_numa_distance	= (regs.eax & BIT!(7)) != 0;
		info.virt.hv.misc_feat_timer_freq	= (regs.eax & BIT!(8)) != 0;
		info.virt.hv.misc_feat_inject_synmc_xcpt	= (regs.eax & BIT!(9)) != 0;
		info.virt.hv.misc_feat_guest_crash_msrs	= (regs.eax & BIT!(10)) != 0;
		info.virt.hv.misc_feat_debug_msrs	= (regs.eax & BIT!(11)) != 0;
		info.virt.hv.misc_feat_npiep1	= (regs.eax & BIT!(12)) != 0;
		info.virt.hv.misc_feat_disable_hypervisor	= (regs.eax & BIT!(13)) != 0;
		info.virt.hv.misc_feat_ext_gva_range_for_flush_va_list	= (regs.eax & BIT!(14)) != 0;
		info.virt.hv.misc_feat_hypercall_output_xmm	= (regs.eax & BIT!(15)) != 0;
		info.virt.hv.misc_feat_sint_polling_mode	= (regs.eax & BIT!(17)) != 0;
		info.virt.hv.misc_feat_hypercall_msr_lock	= (regs.eax & BIT!(18)) != 0;
		info.virt.hv.misc_feat_use_direct_synth_msrs	= (regs.eax & BIT!(19)) != 0;
		break;
	default:
	}
	
	//
	// Leaf 4000_0004H
	//

	if (info.maxLeafVirt < 0x4000_0004) goto L_EXTENDED;
	
	switch (info.virt.vendorId) {
	case VirtVendor.HyperV:
		asmcpuid(regs, 0x4000_0004);
		info.virt.hv.hint_hypercall_for_process_switch	= (regs.eax & BIT!(0)) != 0;
		info.virt.hv.hint_hypercall_for_tlb_flush	= (regs.eax & BIT!(1)) != 0;
		info.virt.hv.hint_hypercall_for_tlb_shootdown	= (regs.eax & BIT!(2)) != 0;
		info.virt.hv.hint_msr_for_apic_access	= (regs.eax & BIT!(3)) != 0;
		info.virt.hv.hint_msr_for_sys_reset	= (regs.eax & BIT!(4)) != 0;
		info.virt.hv.hint_relax_time_checks	= (regs.eax & BIT!(5)) != 0;
		info.virt.hv.hint_dma_remapping	= (regs.eax & BIT!(6)) != 0;
		info.virt.hv.hint_interrupt_remapping	= (regs.eax & BIT!(7)) != 0;
		info.virt.hv.hint_x2apic_msrs	= (regs.eax & BIT!(8)) != 0;
		info.virt.hv.hint_deprecate_auto_eoi	= (regs.eax & BIT!(9)) != 0;
		info.virt.hv.hint_synth_cluster_ipi_hypercall	= (regs.eax & BIT!(10)) != 0;
		info.virt.hv.hint_ex_proc_masks_interface	= (regs.eax & BIT!(11)) != 0;
		info.virt.hv.hint_nested_hyperv	= (regs.eax & BIT!(12)) != 0;
		info.virt.hv.hint_int_for_mbec_syscalls	= (regs.eax & BIT!(13)) != 0;
		info.virt.hv.hint_nested_enlightened_vmcs_interface	= (regs.eax & BIT!(14)) != 0;
		break;
	default:
	}
	
	//
	// Leaf 4000_0006H
	//

	if (info.maxLeafVirt < 0x4000_0006) goto L_EXTENDED;
	
	switch (info.virt.vendorId) {
	case VirtVendor.HyperV:
		asmcpuid(regs, 0x4000_0006);
		info.virt.hv.host_feat_avic	= (regs.eax & BIT!(0)) != 0;
		info.virt.hv.host_feat_msr_bitmap	= (regs.eax & BIT!(1)) != 0;
		info.virt.hv.host_feat_perf_counter	= (regs.eax & BIT!(2)) != 0;
		info.virt.hv.host_feat_nested_paging	= (regs.eax & BIT!(3)) != 0;
		info.virt.hv.host_feat_dma_remapping	= (regs.eax & BIT!(4)) != 0;
		info.virt.hv.host_feat_interrupt_remapping	= (regs.eax & BIT!(5)) != 0;
		info.virt.hv.host_feat_mem_patrol_scrubber	= (regs.eax & BIT!(6)) != 0;
		info.virt.hv.host_feat_dma_prot_in_use	= (regs.eax & BIT!(7)) != 0;
		info.virt.hv.host_feat_hpet_requested	= (regs.eax & BIT!(8)) != 0;
		info.virt.hv.host_feat_stimer_volatile	= (regs.eax & BIT!(9)) != 0;
		break;
	default:
	}
	
	//
	// Leaf 4000_0010H
	//

	if (info.maxLeafVirt < 0x4000_0010) goto L_EXTENDED;
	
	switch (info.virt.vendorId) {
	case VirtVendor.VBoxMin: // VBox Minimal
		asmcpuid(regs, 0x4000_0010);
		info.virt.vbox.tsc_freq_khz = regs.eax;
		info.virt.vbox.apic_freq_khz = regs.ebx;
		break;
	default:
	}

	//
	// Leaf 8000_0001H
	//
	
L_EXTENDED:
	
	if (info.maxLeafExtended < 0x8000_0000) goto L_CACHE_INFO;
	
	asmcpuid(regs, 0x8000_0001);
	
	switch (info.vendorId) {
	case Vendor.AMD:
		// ecx
		info.virt.available	= (regs.ecx & BIT!(2)) != 0;
		info.sys.x2apic	= (regs.ecx & BIT!(3)) != 0;
		info.sse.sse4a	= (regs.ecx & BIT!(6)) != 0;
		info.extensions.xop	= (regs.ecx & BIT!(11)) != 0;
		info.extras.skinit	= (regs.ecx & BIT!(12)) != 0;
		info.extensions.fma4	= (regs.ecx & BIT!(16)) != 0;
		info.extensions.tbm	= (regs.ecx & BIT!(21)) != 0;
		// edx
		info.extensions.mmxExtended	= (regs.edx & BIT!(22)) != 0;
		info.extensions._3DNowExtended	= (regs.edx & BIT!(30)) != 0;
		info.extensions._3DNow	= regs.edx >= BIT!(31);
		break;
	default:
	}
	
	// ecx
	info.extensions.lahf64	= (regs.ecx & BIT!(0)) != 0;
	info.extras.lzcnt	= (regs.ecx & BIT!(5)) != 0;
	info.cache.prefetchw	= (regs.ecx & BIT!(8)) != 0;
	info.extras.monitorx	= (regs.ecx & BIT!(29)) != 0;
	// edx
	info.extras.syscall	= (regs.edx & BIT!(11)) != 0;
	info.memory.nx	= (regs.edx & BIT!(20)) != 0;
	info.memory.page1gb	= (regs.edx & BIT!(26)) != 0;
	info.extras.rdtscp	= (regs.edx & BIT!(27)) != 0;
	info.extensions.x86_64	= (regs.edx & BIT!(29)) != 0;
	
	//
	// Leaf 8000_0007H
	//
	
	if (info.maxLeafExtended < 0x8000_0007) goto L_CACHE_INFO;
	
	asmcpuid(regs, 0x8000_0007);
	
	switch (info.vendorId) {
	case Vendor.Intel:
		info.extras.rdseed	= (regs.ebx & BIT!(28)) != 0;
		break;
	case Vendor.AMD:
		info.sys.tm	= (regs.edx & BIT!(4)) != 0;
		info.tech.turboboost	= (regs.edx & BIT!(9)) != 0;
		break;
	default:
	}
	
	info.extras.rdtscInvariant	= (regs.edx & BIT!(8)) != 0;
	
	//
	// Leaf 8000_0008H
	//
	
	if (info.maxLeafExtended < 0x8000_0008) goto L_CACHE_INFO;
	
	asmcpuid(regs, 0x8000_0008);
	
	switch (info.vendorId) {
	case Vendor.Intel:
		info.cache.wbnoinvd	= (regs.ebx & BIT!(9)) != 0;
		break;
	case Vendor.AMD:
		info.security.ibpb	= (regs.ebx & BIT!(12)) != 0;
		info.security.ibrs	= (regs.ebx & BIT!(14)) != 0;
		info.security.stibp	= (regs.ebx & BIT!(15)) != 0;
		info.security.ibrsAlwaysOn	= (regs.ebx & BIT!(16)) != 0;
		info.security.stibpAlwaysOn	= (regs.ebx & BIT!(17)) != 0;
		info.security.ibrsPreferred	= (regs.ebx & BIT!(18)) != 0;
		info.security.ssbd	= (regs.ebx & BIT!(24)) != 0;
		break;
	default:
	}

	info.memory.b_8000_0008_ax = regs.ax; // info.addr_phys_bits, info.addr_line_bits
	
	//
	// Leaf 8000_000AH
	//

	if (info.maxLeafExtended < 0x8000_000A) goto L_CACHE_INFO;
	
	asmcpuid(regs, 0x8000_000A);
	
	switch (info.vendorId) {
	case Vendor.AMD:
		info.virt.version_	= regs.al; // EAX[7:0]
		info.virt.apicv	= (regs.edx & BIT!(13)) != 0;
		break;
	default:
	}

	//if (info.maxLeafExtended < ...) goto L_CACHE_INFO;
	
L_CACHE_INFO:
	info.cache.levels = 0;
	CACHEINFO *ca = cast(CACHEINFO*)info.cache.level;
	
	//TODO: Make 1FH/BH/4H/etc. functions.
	switch (info.vendorId) {
	case Vendor.Intel:
		if (info.maxLeaf >= 0x1f) goto L_CACHE_INTEL_1FH;
		if (info.maxLeaf >= 0xb)  goto L_CACHE_INTEL_BH;
		if (info.maxLeaf >= 4)    goto L_CACHE_INTEL_4H;
		// Celeron 0xf34 has maxLeaf=03h and ext=8000_0008h
		if (info.maxLeafExtended >= 0x8000_0005) goto L_CACHE_AMD_EXT_5H;
		break;
		
L_CACHE_INTEL_1FH:
		//TODO: Support levels 3,4,5 in CPUID.1FH
		//      (Module, Tile, and Die)
		asmcpuid(regs, 0x1f, 1); // Cores (logical)
		info.cores.logical = regs.bx;
		
		asmcpuid(regs, 0x1f, 0); // SMT (architectural states per core)
		info.cores.physical = cast(ushort)(info.cores.logical / regs.bx);
		
		goto L_CACHE_INTEL_4H;
		
L_CACHE_INTEL_BH:
		asmcpuid(regs, 0xb, 1); // Cores (logical)
		info.cores.logical = regs.bx;
		
		asmcpuid(regs, 0xb, 0); // SMT (architectural states per core)
		info.cores.physical = cast(ushort)(info.cores.logical / regs.bx);
		
L_CACHE_INTEL_4H:
		asmcpuid(regs, 4, info.cache.levels);
		
		type = regs.eax & CACHE_MASK; // EAX[4:0]
		if (type == 0 || info.cache.levels >= CACHE_MAX_LEVEL) return;
		
		ca.type = CACHE_TYPE[type];
		ca.level = regs.al >> 5;
		ca.lineSize = (regs.bx & 0xfff) + 1; // bits 11-0
		ca.partitions = ((regs.ebx >> 12) & 0x3ff) + 1; // bits 21-12
		ca.ways = ((regs.ebx >> 22) + 1); // bits 31-22
		ca.sets = regs.ecx + 1;
		if (regs.eax & BIT!(8)) ca.features = 1;
		if (regs.eax & BIT!(9)) ca.features |= BIT!(1);
		if (regs.edx & BIT!(0)) ca.features |= BIT!(2);
		if (regs.edx & BIT!(1)) ca.features |= BIT!(3);
		if (regs.edx & BIT!(2)) ca.features |= BIT!(4);
		ca.size = (ca.sets * ca.lineSize * ca.partitions * ca.ways) >> 10;
		
		mids = (regs.eax >> 26) + 1;	// EAX[31:26]
		
		if (info.cores.logical == 0) { // skip if already populated
			info.cores.logical = mids;
			info.cores.physical = info.tech.htt ? mids >> 1 : mids;
		}
		
		crshrd = (((regs.eax >> 14) & 2047) + 1);	// EAX[25:14]
		sc = cast(ushort)(info.cores.logical / crshrd); // cast for ldc 0.17.1
		ca.sharedCores = sc ? sc : 1;
		version (Trace) trace("intel.4h mids=%u shared=%u crshrd=%u sc=%u",
			mids, ca.sharedCores, crshrd, sc);
		
		++info.cache.levels; ++ca;
		goto L_CACHE_INTEL_4H;
	case Vendor.AMD:
		if (info.maxLeafExtended >= 0x8000_001D) goto L_CACHE_AMD_EXT_1DH;
		if (info.maxLeafExtended >= 0x8000_0005) goto L_CACHE_AMD_EXT_5H;
		break;
		
		/*if (info.maxLeafExtended < 0x8000_001e) goto L_AMD_TOPOLOGY_EXT_8H;
		
		asmcpuid(regs, 0x8000_0001);
		
		if (regs.ecx & BIT!(22)) { // Topology extensions support
			asmcpuid(regs, 0x8000_001e);
			
			info.cores.logical = regs.ch + 1;
			info.cores.physical = regs.dh & 7;
			goto L_AMD_CACHE;
		}*/
		
/*L_AMD_TOPOLOGY_EXT_8H:
		// See APM Volume 3 Appendix E.5
		// For some reason, CPUID Fn8000_001E_EBX is not mentioned there
		asmcpuid(regs, 0x8000_0008);
		
		type = regs.cx >> 12; // ApicIdSize
		
		if (type) { // Extended
			info.cores.physical = regs.cl + 1;
			info.cores.logical = cast(ushort)(1 << type);
		} else { // Legacy
			info.cores.logical = info.cores.physical = regs.cl + 1;
		}*/
		
		//
		// AMD newer cache method
		//
		
L_CACHE_AMD_EXT_1DH: // Almost the same as Intel's
		asmcpuid(regs, 0x8000_001d, info.cache.levels);
		
		type = regs.eax & CACHE_MASK; // EAX[4:0]
		if (type == 0 || info.cache.levels >= CACHE_MAX_LEVEL) return;
		
		ca.type = CACHE_TYPE[type];
		ca.level = (regs.eax >> 5) & 7;
		ca.lineSize = (regs.ebx & 0xfff) + 1;
		ca.partitions = ((regs.ebx >> 12) & 0x3ff) + 1;
		ca.ways = (regs.ebx >> 22) + 1;
		ca.sets = regs.ecx + 1;
		if (regs.eax & BIT!(8)) ca.features = 1;
		if (regs.eax & BIT!(9)) ca.features |= BIT!(1);
		if (regs.edx & BIT!(0)) ca.features |= BIT!(2);
		if (regs.edx & BIT!(1)) ca.features |= BIT!(3);
		ca.size = (ca.sets * ca.lineSize * ca.partitions * ca.ways) >> 10;
		
		crshrd = (((regs.eax >> 14) & 0xfff) + 1); // bits 25-14
		sc = cast(ushort)(info.sys.maxApicId / crshrd); // cast for ldc 0.17.1
		ca.sharedCores = sc ? sc : 1;
		
		if (info.cores.logical == 0) with (info.cores) { // skip if already populated
			logical = info.sys.maxApicId;
			physical = info.tech.htt ? logical >> 1 : info.sys.maxApicId;
		}
		
		version (Trace) trace("amd.8000_001Dh mids=%u shared=%u crshrd=%u sc=%u",
			mids, ca.sharedCores, crshrd, sc);
		
		++info.cache.levels; ++ca;
		goto L_CACHE_AMD_EXT_1DH;
		
		//
		// AMD legacy cache
		//
		
L_CACHE_AMD_EXT_5H:
		asmcpuid(regs, 0x8000_0005);
		
		info.cache.level[0].level = 1; // L1-D
		info.cache.level[0].type = 'D'; // data
		info.cache.level[0].size = regs.ecx >> 24;
		info.cache.level[0].ways = cast(ubyte)(regs.ecx >> 16);
		info.cache.level[0].lines = regs.ch;
		info.cache.level[0].lineSize = regs.cl;
		info.cache.level[0].sets = 1;
		
		info.cache.level[1].level = 1; // L1-I
		info.cache.level[1].type = 'I'; // instructions
		info.cache.level[1].size = regs.edx >> 24;
		info.cache.level[1].ways = cast(ubyte)(regs.edx >> 16);
		info.cache.level[1].lines = regs.dh;
		info.cache.level[1].lineSize = regs.dl;
		info.cache.level[1].sets = 1;
		
		info.cache.levels = 2;
		
		if (info.maxLeafExtended < 0x8000_0006)
			return; // No L2/L3
		
		// See Table E-4. L2/L3 Cache and TLB Associativity Field Encoding
		static immutable ubyte[16] _amd_cache_ways = [
			// 7h is reserved
			// 9h mentions 8000_001D but that's already supported
			0, 1, 2, 3, 4, 6, 8, 0, 16, 0, 32, 48, 64, 96, 128, 255
		];
		
		asmcpuid(regs, 0x8000_0006);
		
		type = regs.cx >> 12; // amd_ways_l2
		if (type) {
			info.cache.level[2].level = 2;  // L2
			info.cache.level[2].type = 'U'; // unified
			info.cache.level[2].size = regs.ecx >> 16;
			info.cache.level[2].ways = _amd_cache_ways[type];
			info.cache.level[2].lines = regs.ch & 0xf;
			info.cache.level[2].lineSize = regs.cl;
			info.cache.level[2].sets = 1;
			info.cache.levels = 3;
			
			type = regs.dx >> 12; // amd_ways_l3
			if (type) {
				info.cache.level[3].level = 3;  // L3
				info.cache.level[3].type = 'U'; // unified
				info.cache.level[3].size = ((regs.edx >> 18) + 1) << 9;
				info.cache.level[3].ways = _amd_cache_ways[type];
				info.cache.level[3].lines = regs.dh & 0xf;
				info.cache.level[3].lineSize = regs.dl & 0x7F;
				info.cache.level[3].sets = 1;
				info.cache.levels = 4;
			}
		}
		return;
	default:
	}
	
	with (info) cores.physical = cores.logical = 1;
}
