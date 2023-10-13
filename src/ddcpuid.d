/**
 * x86 CPU Identification tool
 *
 * This was initially used internally, so it's pretty unfriendly.
 *
 * The best way to use this module would be:
 * ---
 * CPUINFO cpu;          // CPUINFO.init or memset
 * ddcpuid_leaves(cpu);  // Get maximum CPUID leaves (mandatory step before info)
 * ddcpuid_cpuinfo(cpu); // Fill CPUINFO structure (optional)
 * ---
 *
 * Then checking the corresponding field:
 * ---
 * if (cpu.amx_xfd) {
 *   // Intel AMX with AMX_XFD is available
 * }
 * ---
 *
 * See the CPUINFO structure for available fields.
 *
 * To further understand these fields, it's encouraged to consult the technical manual.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: © 2016-2023 dd86k
 * License: MIT
 */
module ddcpuid;

// NOTE: GAS syntax crash course
//       While ';' and '\n\t' are accepted, GNU typically recommends the
//       latter for readability in output. (Don't know if this affects binaries)
//       syntax:
//       asm { "statement\n\t"
//             : "constraint" (output), ...
//             : "constraint" (input), ...
//             : "clobbers", ... }
//       constraints:
//       - "r": register
//       - "a","b","c","d": AX, BX, CX, or DX respectively
//       - "m": memory
//       - "i": immediate (known at compile-time)
//       - "0",...: Use same constraint as operand n
//       constraint modifiers (for output):
//       - "=": Write-only
//       - "+": Read-write

@system:
extern (C):

version (X86)
	enum DDCPUID_PLATFORM = "i686"; /// Target platform
else version (X86_64)
	enum DDCPUID_PLATFORM = "amd64"; /// Target platform
else static assert(0, "Unsupported platform");

version (DigitalMars) {
	version = DMD;	// DMD compiler
	version = DMDLDC;	// DMD or LDC compilers
} else version (GNU) {
	version = GDC;	// GDC compiler
} else version (LDC) {
	version = DMDLDC;	// DMD or LDC compilers
} else static assert(0, "Unsupported compiler");

enum DDCPUID_VERSION   = "0.21.1";	/// Library version
private enum CACHE_LEVELS = 6;	/// For buffer
private enum CACHE_MAX_LEVEL = CACHE_LEVELS - 1;

version (PrintInfo) {
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
enum Vendor {
	Other = 0,
	Intel = ID!"Genu",	/// `"GenuineIntel"`: Intel
	AMD   = ID!"Auth",	/// `"AuthenticAMD"`: AMD
	VIA   = ID!"VIA ",	/// `"VIA VIA VIA "`: VIA
}

/// Virtual Vendor ID, used as the interface type.
// NOTE: bhyve doesn't not emit cpuid bits within 0x40000000, so not supported
enum VirtVendor {
	Other = 0,
	KVM        = ID!"KVMK",	/// `"KVMKVMKVM\0\0\0"`: KVM
	HyperV     = ID!"Micr",	/// `"Microsoft Hv"`: Hyper-V interface
	VBoxHyperV = ID!"VBox",	/// `"VBoxVBoxVBox"`: VirtualBox's Hyper-V interface
	VBoxMin    = 0,	/// Unset: VirtualBox minimal interface
}

/// Registers structure used with the ddcpuid function.
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

/// Cache entry.
struct CACHEINFO { align(1):
	this(ubyte level_, char type_, uint kbsize_, ushort shared_,
		ushort ways_, ushort parts_, ushort lineSize_, uint sets_) {
		level = level_;
		type = type_;
		size = kbsize_;
		sharedCores = shared_;
		ways = ways_;
		partitions = parts_;
		lineSize = lineSize_;
		sets = sets_;
		features = 0;
	}
	//TODO: Sort fields (totalSize, coresShared, ways, partitions, lineSize, sets)
	ushort lineSize;	/// Size of the line in bytes.
	union {
		ushort partitions;	/// Number of partitions.
		ushort lines;	/// Legacy name of partitions.
	}
	ushort ways;	/// Number of ways per line.
	uint sets; /// Number of cache sets. (Entries)
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

/// Vendor string structure.
struct VendorString { align(1):
	union {
		struct { uint ebx, edx, ecx; }
		char[12] string_;
	}
	Vendor id;	/// Validated vendor ID
}

@system unittest {
	VendorString s;
	s.string_ = "AuthenticAMD";
	assert(s.ebx == ID!"Auth");
	assert(s.edx == ID!"enti");
	assert(s.ecx == ID!"cAMD");
}

/// Virtualization vendor string structure.
struct VirtVendorString { align(1):
	union {
		struct { uint ebx, ecx, edx; }
		char[12] string_;
	}
	VirtVendor id;	/// Validated vendor ID
}

@system unittest {
	VirtVendorString s;
	s.string_ = "AuthenticAMD";
	assert(s.ebx == ID!"Auth");
	assert(s.ecx == ID!"enti");
	assert(s.edx == ID!"cAMD");
}

/// CPU information structure
struct CPUINFO { align(1):
	uint maxLeaf;	/// Highest cpuid leaf
	uint maxLeafVirt;	/// Highest cpuid virtualization leaf
	uint maxLeafExtended;	/// Highest cpuid extended leaf
	
	// Vendor/brand strings
	
	VendorString vendor;	/// Vendor string and id
	
//	const(char) *microArchitecture;	/// Microarchitecture name string
	
	union {
		private uint[12] brand32;	// For init only
		char[48] brandString;	/// Processor Brand String
	}
	ubyte brandIndex;	/// Brand string index
	private ubyte __pad;
	
	uint cacheLevels;
	CACHEINFO[CACHE_LEVELS] cache;
	
	ushort logicalCores;	/// Logical cores in this processor
	ushort physicalCores;	/// Physical cores in this processor
	
	// Identifier
	
	uint identifier;	/// Raw identifier (CPUID.01h.EAX)
	ushort family;	/// Effective family identifier
	ushort model;	/// Effective model identifier
	ubyte familyBase;	/// Base family identifier
	ubyte familyExtended;	/// Extended family identifier
	ubyte modelBase;	/// Base model identifier
	ubyte modelExtended;	/// Extended model identifier
	ubyte stepping;	/// Stepping revision
	ubyte type;	/// Processor type number
	const(char) *typeString;	/// Processor type string.
	
	//
	// Extensions
	//
	
	bool fpu;	/// On-Chip x87 FPU
	bool f16c;	/// Float16 Conversions
	bool mmx;	/// MMX
	bool mmxExtended;	/// MMX Extended
	bool _3DNow;	/// 3DNow!
	bool _3DNowExtended;	/// 3DNow! Extended
	bool aes_ni;	/// Advanced Encryption Standard New Instructions
	bool sha;	/// SHA-1
	bool bmi1;	/// BMI1
	bool bmi2;	/// BMI2
	bool x86_64;	/// 64-bit mode (Long mode)
	bool lahf64;	/// LAHF+SAHF in 64-bit mode
	bool waitpkg;	/// User Level Monitor Wait (UMWAIT)
	bool xop;	/// AMD eXtended OPerations
	bool tbm;	/// Trailing Bit Manipulation
	bool adx;	/// Multi-precision Add-Carry (ADCX+ADOX)
	
	//
	// SSE
	//
	
	bool sse;	/// Streaming SIMD Extensions
	bool sse2;	/// SSE2
	bool sse3;	/// SSE3
	bool ssse3;	/// SSSE3
	bool sse41;	/// SSE4.1
	bool sse42;	/// SSE4.2
	bool sse4a;	/// SSE4a
	bool fma;	/// Fused Multiply-Add (FMA)
	bool fma4;	/// FMA4
	private bool __pad_2;
	
	//
	// AVX
	//
	
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
	private bool __pad_3;
	
	//
	// AMX
	//
	
	bool amx;	/// Advanced Matrix eXtension
	bool amx_bf16;	/// AMX_BF16
	bool amx_int8;	/// AMX_INT8
	bool amx_xtilecfg;	/// AMX_XTILECFG
	bool amx_xtiledata;	/// AMX_XTILEDATA
	bool amx_xfd;	/// AMX_XFD
	
	//
	// SGX
	//
	
	bool sgx;	/// If SGX is supported (and enabled)
	bool sgx1;	/// SGX1
	bool sgx2;	/// SGX2
	ubyte sgxMaxSize;	/// 2^n maximum enclave size in non-64-bit
	ubyte sgxMaxSize64;	/// 2^n maximum enclave size in 64-bit
	private bool __pad_4;
	
	//
	// Additional instructions.
	//
	
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
	private bool __pad_5;
	
	// Features.
	
	bool eist;	/// Intel SpeedStep/AMD PowerNow/AMD Cool'n'Quiet
	bool turboboost;	/// Intel TurboBoost/AMD CorePerformanceBoost
	bool turboboost30;	/// Intel TurboBoost 3.0
	bool smx;	/// Intel TXT
	bool htt;	/// (HTT) HyperThreading Technology, or just SMT available
	private bool __pad_6;
	
	/// Cache-related.
	
	bool clflush;	/// CLFLUSH instruction
	ubyte clflushLinesize;	/// Linesize of CLFLUSH in bytes
	bool clflushopt;	/// CLFLUSH instruction
	bool cnxtId;	/// L1 Context ID
	bool ss;	/// SelfSnoop
	bool prefetchw;	/// PREFETCHW instruction
	bool invpcid;	/// INVPCID instruction
	bool wbnoinvd;	/// WBNOINVD instruction
	
	/// ACPI information.
	
	bool apci;	/// ACPI
	bool apic;	/// APIC
	bool x2apic;	/// x2APIC
	bool arat;	/// Always-Running-APIC-Timer
	bool tm;	/// Thermal Monitor
	bool tm2;	/// Thermal Monitor 2
	ubyte apicMaxId;	/// Maximum APIC ID
	ubyte apicId;	/// Initial APIC ID (running core where CPUID was called)
	
	//
	// Virtualization features.
	//
	
	bool virtualization;	/// Intel VT-x/AMD-V
	ubyte virtVersion;	/// (AMD) Virtualization platform version
	bool vme;	/// Enhanced vm8086
	bool apicv;	/// (AMD) APICv. Intel's is available via a MSR.
	
	VirtVendorString virtVendor;
	
	struct VBox { align(1):
		uint tsc_freq_khz;	/// (VBox) Timestamp counter frequency in KHz
		uint apic_freq_khz;	/// (VBox) Paravirtualization API KHz frequency
	}
	VBox vbox;
	
	struct KVM { align(1):
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
		private bool res2;
	}
	KVM kvm;
	
	struct HyperV { align(1):
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
	
	//
	// Memory features.
	//
	
	bool pae;	/// Physical Address Extension 
	bool pse;	/// Page Size Extension
	bool pse36;	/// 36-bit PSE
	bool page1gb;	/// 1GiB pages in 4-level paging and higher
	bool mtrr;	/// Memory Type Range Registers
	bool pat;	/// Page Attribute Table
	bool pge;	/// Page Global Bit
	bool dca;	/// Direct Cache Access
	union {
		uint tsx;	/// Intel TSX. If set, has one of HLE, RTM, or TSXLDTRK.
		struct {
			bool hle;	/// (TSX) Hardware Lock Elision
			bool rtm;	/// (TSX) Restricted Transactional Memory
			bool tsxldtrk;	/// (TSX) Suspend Load Address Tracking
		}
	}
	bool nx;	/// Intel XD (No eXecute bit)
	bool smep;	/// Supervisor Mode Execution Protection
	bool smap;	/// Supervisor Mode Access Protection
	bool pku;	/// Protection Key Units
	bool _5pl;	/// 5-level paging
	bool fsrepmov;	/// Fast Short REP MOVSB optimization
	bool lam;	/// Linear Address Masking
	ubyte physicalBits;	/// Memory physical bits
	ubyte linearBits;	/// Memory linear bits
	private bool __pad_8;
	
	//
	// Debugging features.
	//
	
	bool mca;	/// Machine Check Architecture
	bool mce;	/// Machine Check Exception
	bool de;	/// Degging Extensions
	bool ds;	/// Debug Store
	bool ds_cpl;	/// Debug Store for Current Privilege Level
	bool dtes64;	/// 64-bit Debug Store area
	bool pdcm;	/// Perfmon And Debug Capability
	bool sdbg;	/// Silicon Debug
	bool pbe;	/// Pending Break Enable
	private bool __pad_9;
	
	/// Security features and mitigations.
	// NOTE: IA32_CORE_CAPABILITIES is currently empty
	
	bool ia32_arch_capabilities;	/// IA32_ARCH_CAPABILITIES MSR
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
	
	/// Miscellaneous features.
	
	bool psn;	/// Processor Serial Number (Pentium III only)
	bool pcid;	/// PCID
	bool xtpr;	/// xTPR
	bool fsgsbase;	/// FS and GS register base
	bool uintr;	/// User Interrupts
	private bool __pad_10;
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

/// Test if a bit is set.
/// Params:
/// 	val = 32-bit content.
/// 	pos = Bit position.
/// Returns: True if bit set.
pragma(inline, true)
private bool bit(uint val, int pos) pure @safe {
	return (val & (1 << pos)) != 0;
}

@safe unittest {
	assert( bit(0b10, 1));
	assert(!bit(   0, 1));
}

// GDC and LDC may inline the assembler code.
pragma(inline, false):

/// Query processor with CPUID.
/// Params:
///   regs = REGISTERS structure
///   level = Leaf (EAX)
///   sublevel = Sub-leaf (ECX)
void ddcpuid_id(ref REGISTERS regs, uint level, uint sublevel = 0) {
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
/// Typically these tests are done on Pentium 4 and later processors
@system unittest {
	REGISTERS regs;
	ddcpuid_id(regs, 0);
	assert(regs.eax > 0 && regs.eax < 0x4000_0000);
	ddcpuid_id(regs, 0x8000_0000);
	assert(regs.eax > 0x8000_0000);
}

private uint ddcpuid_max_leaf() {
	version (DMDLDC) asm {
		xor EAX,EAX;
		cpuid;
	} else version (GDC) asm {
		"xor %eax,%eax\n\t"~
		"cpuid";
	}
}

private uint ddcpuid_max_leaf_virt() {
	uint eax = void;
	version (DMDLDC) asm {
		mov EAX,0x4000_0000;
		cpuid;
		mov eax,EAX;
	} else version (GDC) asm {
		"mov $0x40000000,%%eax\n\t"~
		"cpuid"
		: "=a" (eax);
	}
	if (eax <  0x4000_0000) return 0;
	if (eax >= 0x5000_0000) return 0;
	return eax;
}

private uint ddcpuid_max_leaf_ext() {
	uint eax = void;
	version (DMDLDC) asm {
		mov EAX,0x8000_0000;
		cpuid;
		mov eax,EAX;
	} else version (GDC) asm {
		"mov $0x80000000,%%eax\n\t"~
		"cpuid"
		: "=a" (eax);
	}
	if (eax <  0x8000_0000) return 0;
	if (eax >= 0x9000_0000) return 0;
	return eax;
}

/// Get CPU leaf levels.
/// Params: cpu = CPUINFO structure
void ddcpuid_leaves(ref CPUINFO cpu) {
	cpu.maxLeaf = ddcpuid_max_leaf;
	cpu.maxLeafVirt = ddcpuid_max_leaf_virt;
	cpu.maxLeafExtended = ddcpuid_max_leaf_ext;
}

private
void ddcpuid_vendor(ref char[12] string_) {
	version (DMD) {
		version (X86) asm {
			mov EDI, string_;
			xor EAX, EAX;
			cpuid;
			mov [EDI], EBX;
			mov [EDI + 4], EDX;
			mov [EDI + 8], ECX;
		} else asm { // x86-64
			mov RDI, string_;
			xor EAX,EAX;
			cpuid;
			mov [RDI], EBX;
			mov [RDI + 4], EDX;
			mov [RDI + 8], ECX;
		}
	} else version (GDC) {
		version (X86) asm {
			"lea %0, %%edi\n\t"~
			"xor %%eax, %%eax\n\t"~
			"cpuid\n"~
			"mov %%ebx, (%%edi)\n\t"~
			"mov %%edx, 4(%%edi)\n\t"~
			"mov %%ecx, 8(%%edi)"
			:
			: "m" (string_)
			: "edi", "eax", "ebx", "ecx", "edx";
		} else asm { // x86-64
			"lea %0, %%rdi\n\t"~
			"xor %%eax, %%eax\n\t"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n\t"~
			"mov %%edx, 4(%%rdi)\n\t"~
			"mov %%ecx, 8(%%rdi)"
			:
			: "m" (string_)
			: "rdi", "rax", "rbx", "rcx", "rdx";
		}
	} else version (LDC) {
		version (X86) asm {
			lea EDI, string_;
			xor EAX, EAX;
			cpuid;
			mov [EDI], EBX;
			mov [EDI + 4], EDX;
			mov [EDI + 8], ECX;
		} else asm { // x86-64
			lea RDI, string_;
			xor EAX, EAX;
			cpuid;
			mov [RDI], EBX;
			mov [RDI + 4], EDX;
			mov [RDI + 8], ECX;
		}
	}
}

private
Vendor ddcpuid_vendor_id(ref VendorString vendor) {
	// Vendor string verification
	// If the rest of the string doesn't correspond, the id is unset
	switch (vendor.ebx) with (Vendor) {
	case Intel:	// "GenuineIntel"
		if (vendor.edx != ID!("ineI")) break;
		if (vendor.ecx != ID!("ntel")) break;
		return Vendor.Intel;
	case AMD:	// "AuthenticAMD"
		if (vendor.edx != ID!("enti")) break;
		if (vendor.ecx != ID!("cAMD")) break;
		return Vendor.AMD;
	case VIA:	// "VIA VIA VIA "
		if (vendor.edx != ID!("VIA ")) break;
		if (vendor.ecx != ID!("VIA ")) break;
		return Vendor.VIA;
	default: // Unknown
	}
	return Vendor.Other;
}

private
void ddcpuid_extended_brand(ref char[48] string_) {
	version (DMD) {
		version (X86) asm {
			mov EDI, string_;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [EDI], EAX;
			mov [EDI +  4], EBX;
			mov [EDI +  8], ECX;
			mov [EDI + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [EDI + 16], EAX;
			mov [EDI + 20], EBX;
			mov [EDI + 24], ECX;
			mov [EDI + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [EDI + 32], EAX;
			mov [EDI + 36], EBX;
			mov [EDI + 40], ECX;
			mov [EDI + 44], EDX;
		} else version (X86_64) asm {
			mov RDI, string_;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [RDI], EAX;
			mov [RDI +  4], EBX;
			mov [RDI +  8], ECX;
			mov [RDI + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [RDI + 16], EAX;
			mov [RDI + 20], EBX;
			mov [RDI + 24], ECX;
			mov [RDI + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [RDI + 32], EAX;
			mov [RDI + 36], EBX;
			mov [RDI + 40], ECX;
			mov [RDI + 44], EDX;
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
			: "m" (string_)
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
			: "m" (string_)
			: "rdi", "rax", "rbx", "rcx", "rdx";
		}
	} else version (LDC) {
		version (X86) asm {
			lea EDI, string_;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [EDI], EAX;
			mov [EDI +  4], EBX;
			mov [EDI +  8], ECX;
			mov [EDI + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [EDI + 16], EAX;
			mov [EDI + 20], EBX;
			mov [EDI + 24], ECX;
			mov [EDI + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [EDI + 32], EAX;
			mov [EDI + 36], EBX;
			mov [EDI + 40], ECX;
			mov [EDI + 44], EDX;
		} else version (X86_64) asm {
			lea RDI, string_;
			mov EAX, 0x8000_0002;
			cpuid;
			mov [RDI], EAX;
			mov [RDI +  4], EBX;
			mov [RDI +  8], ECX;
			mov [RDI + 12], EDX;
			mov EAX, 0x8000_0003;
			cpuid;
			mov [RDI + 16], EAX;
			mov [RDI + 20], EBX;
			mov [RDI + 24], ECX;
			mov [RDI + 28], EDX;
			mov EAX, 0x8000_0004;
			cpuid;
			mov [RDI + 32], EAX;
			mov [RDI + 36], EBX;
			mov [RDI + 40], ECX;
			mov [RDI + 44], EDX;
		}
	}
}

// Avoids depending on C runtime for library.
/// Copy brand string
/// Params:
/// 	dst = Destination buffer
/// 	src = Source constant string
private
void ddcpuid_strcpy48(ref char[48] dst, const(char) *src) {
	for (size_t i; i < 48; ++i) {
		char c = src[i];
		dst[i] = c;
		if (c == 0) break;
	}
}
private alias strcpy48 = ddcpuid_strcpy48;

@system unittest {
	char[48] buffer = void;
	strcpy48(buffer, "ea");
	assert(buffer[0] == 'e');
	assert(buffer[1] == 'a');
	assert(buffer[2] == 0);
}

/// Get the legacy processor brand string.
/// These indexes/tables were introduced in Intel's Pentium III.
/// AMD does not use them.
/// Params:
/// 	cpu = CPUINFO structure.
/// 	index = CPUID.01h.BL value.
private
const(char)* ddcpuid_intel_brand_index(uint identifier, ubyte index) {
	switch (index) {
	case 1, 0xA, 0xF, 0x14: return "Intel(R) Celeron(R)";
	case 2, 4: return "Intel(R) Pentium(R) III";
	case 3:
		if (identifier == 0x6b1) goto case 1;
		return "Intel(R) Pentium(R) III Xeon(R)";
	case 6:
		return "Mobile Intel(R) Pentium(R) III";
	case 7, 0x13, 0x17: // Same as Intel(R) Celeron(R) M?
		return "Mobile Intel(R) Celeron(R)";
	case 8, 9:
		return "Intel(R) Pentium(R) 4";
	case 0xB:
		if (identifier == 0xf13) goto case 0xC;
	L_XEON: // Needed to avoid loop with case 0xe
		return "Intel(R) Xeon(R)";
	case 0xC: return "Intel(R) Xeon(R) MP";
	case 0xE:
		if (identifier == 0xf13) goto L_XEON;
		return "Mobile Intel(R) Pentium(R) 4";
	case 0x11, 0x15: // Yes, really.
		return "Mobile Genuine Intel(R)";
	case 0x12: return "Intel(R) Celeron(R) M";
	case 0x16: return "Intel(R) Pentium(R) M";
	default:   return "Unknown";
	}
}

private
const(char)* ddcpuid_intel_brand_family(ref CPUINFO cpu) {
	// This function exist for processors that does not support the
	// brand name table.
	// At least do from Pentium to late Pentium II processors.
	switch (cpu.family) {
	case 5: // i586, Pentium
		if (cpu.model >= 4) return "Intel(R) Pentium(R) MMX";
		return "Intel(R) Pentium(R)";
	case 6: // i686, Pentium Pro
		if (cpu.model >= 3) return "Intel(R) Pentium(R) II";
		return "Intel(R) Pentium(R) Pro";
	default: return "Unknown";
	}
}

private
void ddcpuid_amd_brand_family(ref CPUINFO cpu) {
	// This function exist for processors that does not support the
	// extended brand string which is the Am5x86 and AMD K-5 model 0.
	// K-5 model 1 has extended brand string so case 5 is only model 0.
	// AMD has no official names for these.
	switch (cpu.family) {
	case 4:  strcpy48(cpu.brandString, "AMD Am5x86"); return;
	case 5:  strcpy48(cpu.brandString, "AMD K5"); return;
	default: strcpy48(cpu.brandString, "Unknown"); return;
	}
}

private
void ddcpuid_virt_vendor(ref char[12] string_) {
	version (DMD) {
		version (X86) asm {
			mov EDI, string_;
			mov EAX, 0x40000000;
			cpuid;
			mov [EDI], EBX;
			mov [EDI + 4], ECX;
			mov [EDI + 8], EDX;
		} else asm { // x86-64
			mov RDI, string_;
			mov EAX, 0x40000000;
			cpuid;
			mov [RDI], EBX;
			mov [RDI + 4], ECX;
			mov [RDI + 8], EDX;
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
			: "m" (string_)
			: "edi", "eax", "ebx", "ecx", "edx";
		} else asm { // x86-64
			"lea %0, %%rdi\n\t"~
			"mov $0x40000000, %%eax\n\t"~
			"cpuid\n"~
			"mov %%ebx, (%%rdi)\n\t"~
			"mov %%ecx, 4(%%rdi)\n\t"~
			"mov %%edx, 8(%%rdi)"
			:
			: "m" (string_)
			: "rdi", "rax", "rbx", "rcx", "rdx";
		}
	} else version (LDC) {
		version (X86) asm {
			lea EDI, string_;
			mov EAX, 0x40000000;
			cpuid;
			mov [EDI], EBX;
			mov [EDI + 4], ECX;
			mov [EDI + 8], EDX;
		} else asm { // x86-64
			lea RDI, string_;
			mov EAX, 0x40000000;
			cpuid;
			mov [RDI], EBX;
			mov [RDI + 4], ECX;
			mov [RDI + 8], EDX;
		}
	}
}

private
VirtVendor ddcpuid_virt_vendor_id(ref VirtVendorString vendor) {
	// Paravirtual vendor string verification
	// If the rest of the string doesn't correspond, the id is unset
	switch (vendor.ebx) {
	case VirtVendor.KVM:	// "KVMKVMKVM\0\0\0"
		if (vendor.ecx != ID!("VMKV")) goto default;
		if (vendor.edx != ID!("M\0\0\0")) goto default;
		return VirtVendor.KVM;
	case VirtVendor.HyperV:	// "Microsoft Hv"
		if (vendor.ecx != ID!("osof")) goto default;
		if (vendor.edx != ID!("t Hv")) goto default;
		return VirtVendor.HyperV;
	case VirtVendor.VBoxHyperV:	// "VBoxVBoxVBox"
		if (vendor.ecx != ID!("VBox")) goto default;
		if (vendor.edx != ID!("VBox")) goto default;
		return VirtVendor.HyperV; // Bug according to VBox
	default:
		return VirtVendor.Other;
	}
}

@system unittest {
	VirtVendorString vendor;
	vendor.string_ = "KVMKVMKVM\0\0\0";
	assert(ddcpuid_virt_vendor_id(vendor) == VirtVendor.KVM);
}

private
void ddcpuid_model_string(ref CPUINFO cpu) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		// Brand string
		if (cpu.maxLeafExtended >= 0x8000_0004)
			ddcpuid_extended_brand(cpu.brandString);
		else if (cpu.brandIndex)
			strcpy48(cpu.brandString,
				ddcpuid_intel_brand_index(cpu.identifier, cpu.brandIndex));
		else
			strcpy48(cpu.brandString, ddcpuid_intel_brand_family(cpu));
		return;
	case AMD, VIA:
		// Brand string
		// NOTE: AMD processor never supported string tables.
		//       Am486DX4 and Am5x86 processors do not support the extended brand string.
		//       K5 model 0 does not support the extended brand string.
		//       K5 model 1, 2, and 3 support the extended brand string.
		if (cpu.maxLeafExtended >= 0x8000_0004)
			ddcpuid_extended_brand(cpu.brandString);
		else
			ddcpuid_amd_brand_family(cpu);
		return;
	default:
		strcpy48(cpu.brandString, "Unknown");
		return;
	}
}

private
void ddcpuid_leaf1(ref CPUINFO cpu, ref REGISTERS regs) {
	// EAX
	cpu.identifier = regs.eax;
	cpu.stepping   = regs.eax & 15;       // EAX[3:0]
	cpu.modelBase  = regs.eax >>  4 & 15; // EAX[7:4]
	cpu.familyBase = regs.eax >>  8 & 15; // EAX[11:8]
	cpu.type       = regs.eax >> 12 & 3;  // EAX[13:12]
	cpu.typeString = PROCESSOR_TYPE[cpu.type];
	cpu.modelExtended   = regs.eax >> 16 & 15; // EAX[19:16]
	cpu.familyExtended  = cast(ubyte)(regs.eax >> 20); // EAX[27:20]
	
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		cpu.family = cpu.familyBase != 15 ?
			cast(ushort)cpu.familyBase :
			cast(ushort)(cpu.familyExtended + cpu.familyBase);
		
		cpu.model = cpu.familyBase == 6 || cpu.familyBase == 0 ?
			cast(ushort)((cpu.modelExtended << 4) + cpu.modelBase) :
			cast(ushort)cpu.modelBase; // DisplayModel = Model_ID;
		
		// ECX
		cpu.dtes64	= bit(regs.ecx, 2);
		cpu.ds_cpl	= bit(regs.ecx, 4);
		cpu.virtualization	= bit(regs.ecx, 5);
		cpu.smx	= bit(regs.ecx, 6);
		cpu.eist	= bit(regs.ecx, 7);
		cpu.tm2	= bit(regs.ecx, 8);
		cpu.cnxtId	= bit(regs.ecx, 10);
		cpu.sdbg	= bit(regs.ecx, 11);
		cpu.xtpr	= bit(regs.ecx, 14);
		cpu.pdcm	= bit(regs.ecx, 15);
		cpu.pcid	= bit(regs.ecx, 17);
		cpu.mca	= bit(regs.ecx, 18);
		cpu.x2apic	= bit(regs.ecx, 21);
		cpu.rdtscDeadline	= bit(regs.ecx, 24);
		
		// EDX
		cpu.psn	= bit(regs.edx, 18);
		cpu.ds	= bit(regs.edx, 21);
		cpu.apci	= bit(regs.edx, 22);
		cpu.ss	= bit(regs.edx, 27);
		cpu.tm	= bit(regs.edx, 29);
		cpu.pbe	= regs.edx >= BIT!(31);
		break;
	case AMD:
		if (cpu.familyBase < 15) {
			cpu.family = cpu.familyBase;
			cpu.model = cpu.modelBase;
		} else {
			cpu.family = cast(ushort)(cpu.familyExtended + cpu.familyBase);
			cpu.model = cast(ushort)((cpu.modelExtended << 4) + cpu.modelBase);
		}
		break;
	default:
	}
	
	// EBX
	cpu.apicId	= regs.ebx >> 24;
	cpu.apicMaxId	= cast(ubyte)(regs.ebx >> 16);
	cpu.clflushLinesize	= regs.bh;
	cpu.brandIndex	= regs.bl;
	
	// ECX
	cpu.sse3	= bit(regs.ecx, 0);
	cpu.pclmulqdq	= bit(regs.ecx, 1);
	cpu.monitor	= bit(regs.ecx, 3);
	cpu.ssse3	= bit(regs.ecx, 9);
	cpu.fma	= bit(regs.ecx, 12);
	cpu.cmpxchg16b	= bit(regs.ecx, 13);
	cpu.sse41	= bit(regs.ecx, 19);
	cpu.sse42	= bit(regs.ecx, 20);
	cpu.movbe	= bit(regs.ecx, 22);
	cpu.popcnt	= bit(regs.ecx, 23);
	cpu.aes_ni	= bit(regs.ecx, 25);
	cpu.xsave	= bit(regs.ecx, 26);
	cpu.osxsave	= bit(regs.ecx, 27);
	cpu.avx	= bit(regs.ecx, 28);
	cpu.f16c	= bit(regs.ecx, 29);
	cpu.rdrand	= bit(regs.ecx, 30);
	
	// EDX
	cpu.fpu	= bit(regs.edx, 0);
	cpu.vme	= bit(regs.edx, 1);
	cpu.de	= bit(regs.edx, 2);
	cpu.pse	= bit(regs.edx, 3);
	cpu.rdtsc	= bit(regs.edx, 4);
	cpu.rdmsr	= bit(regs.edx, 5);
	cpu.pae	= bit(regs.edx, 6);
	cpu.mce	= bit(regs.edx, 7);
	cpu.cmpxchg8b	= bit(regs.edx, 8);
	cpu.apic	= bit(regs.edx, 9);
	cpu.sysenter	= bit(regs.edx, 11);
	cpu.mtrr	= bit(regs.edx, 12);
	cpu.pge	= bit(regs.edx, 13);
	cpu.mca	= bit(regs.edx, 14);
	cpu.cmov	= bit(regs.edx, 15);
	cpu.pat	= bit(regs.edx, 16);
	cpu.pse36	= bit(regs.edx, 17);
	cpu.clflush	= bit(regs.edx, 19);
	cpu.mmx	= bit(regs.edx, 23);
	cpu.fxsr	= bit(regs.edx, 24);
	cpu.sse	= bit(regs.edx, 25);
	cpu.sse2	= bit(regs.edx, 26);
	cpu.htt	= bit(regs.edx, 28);
}

//NOTE: Only Intel officially supports CPUID.02h
//      No dedicated functions to a cache descriptor to avoid a definition.
private
void ddcpuid_leaf2(ref CPUINFO cpu, ref REGISTERS regs) {
	struct leaf2_t {
		union {
			REGISTERS registers;
			ubyte[16] values;
		}
	}
	leaf2_t data = void;
	
	data.registers = regs;
	
	enum L1I = 0;
	enum L1D = 1;
	enum L2 = 2;
	enum L3 = 3;
	// Skips value in AL
	with (cpu) for (size_t index = 1; index < 16; ++index) {
		ubyte value = data.values[index];
		
		// Cache entries only, the rest is "don't care".
		// Unless if one day I support looking up TLB data, but AMD does not support this.
		// continue: Explicitly skip cache, this includes 0x00 (null), 0x40 (no L2 or L3).
		// break: Valid cache descriptor, increment cache level.
		switch (value) {
		case 0x06: // 1st-level instruction cache: 8 KBytes, 4-way set associative, 32 byte line size
			cache[L1I] = CACHEINFO(1, 'I', 8, 1, 4, 1, 32, 64);
			break;
		case 0x08: // 1st-level instruction cache: 16 KBytes, 4-way set associative, 32 byte line size
			cache[L1I] = CACHEINFO(1, 'I', 16, 1, 4, 1, 32, 128);
			break;
		case 0x09: // 1st-level instruction cache: 32 KBytes, 4-way set associative, 64 byte line size
			cache[L1I] = CACHEINFO(1, 'I', 32, 1, 4, 1, 64, 128);
			break;
		case 0x0A: // 1st-level data cache: 8 KBytes, 2-way set associative, 32 byte line size
			cache[L1D] = CACHEINFO(1, 'D', 8, 1, 2, 1, 32, 128);
			break;
		case 0x0C: // 1st-level data cache: 16 KBytes, 4-way set associative, 32 byte line size
			cache[L1D] = CACHEINFO(1, 'D', 16, 1, 4, 1, 32, 128);
			break;
		case 0x0D: // 1st-level data cache: 16 KBytes, 4-way set associative, 64 byte line size (ECC?)
			cache[L1D] = CACHEINFO(1, 'D', 16, 1, 4, 1, 64, 64);
			break;
		case 0x0E: // 1st-level data cache: 24 KBytes, 6-way set associative, 64 byte line size
			cache[L1D] = CACHEINFO(1, 'D', 24, 1, 6, 1, 64, 64);
			break;
		case 0x10: // (sandpile) data L1 cache, 16 KB, 4 ways, 32 byte lines (IA-64)
			cache[L1D] = CACHEINFO(1, 'D', 16, 1, 4, 1, 32, 64);
			break;
		case 0x15: // (sandpile) code L1 cache, 16 KB, 4 ways, 32 byte lines (IA-64)
			cache[L1I] = CACHEINFO(1, 'I', 16, 1, 4, 1, 32, 64);
			break;
		case 0x1a: // (sandpile) code and data L2 cache, 96 KB, 6 ways, 64 byte lines (IA-64)
			cache[L2] = CACHEINFO(2, 'I', 96, 1, 6, 1, 64, 256);
			break;
		case 0x1D: // 2nd-level cache: 128 KBytes, 2-way set associative, 64 byte line size
			cache[L2] = CACHEINFO(2, 'U', 128, 1, 2, 1, 64, 1024);
			break;
		case 0x21: // 2nd-level cache: 256 KBytes, 8-way set associative, 64 byte line size
			cache[L2] = CACHEINFO(2, 'U', 256, 1, 8, 1, 64, 512);
			break;
		case 0x22: // 3rd-level cache: 512 KBytes, 4-way set associative, 64 byte line size, 2 lines per sector
			cache[L3] = CACHEINFO(3, 'U', 512, 1, 4, 2, 64, 1024);
			break;
		case 0x23: // 3rd-level cache: 1 MBytes, 8-way set associative, 64 byte line size, 2 lines per sector
			cache[L3] = CACHEINFO(3, 'U', 1024, 1, 8, 2, 64, 1024);
			break;
		case 0x24: // 2nd-level cache: 1 MBytes, 16-way set associative, 64 byte line size
			cache[L2] = CACHEINFO(2, 'U', 1024, 1, 16, 1, 64, 1024);
			break;
		case 0x25: // 3rd-level cache: 2 MBytes, 8-way set associative, 64 byte line size, 2 lines per sector
			cache[L3] = CACHEINFO(3, 'U', 2048, 1, 8, 2, 64, 2048);
			break;
		case 0x29: // 3rd-level cache: 4 MBytes, 8-way set associative, 64 byte line size, 2 lines per sector
			cache[L3] = CACHEINFO(3, 'U', 4096, 1, 8, 2, 64, 4096);
			break;
		case 0x2C: // 1st-level data cache: 32 KBytes, 8-way set associative, 64 byte line size
			cache[L1D] = CACHEINFO(1, 'D', 32, 1, 8, 1, 64, 64);
			break;
		case 0x30: // 1st-level instruction cache: 32 KBytes, 8-way set associative, 64 byte line size
			cache[L1I] = CACHEINFO(1, 'I', 32, 1, 8, 1, 64, 64);
			break;
		case 0x39: // (sandpile) code and data L2 cache, 128 KB, 4 ways, 64 byte lines, sectored (htt?)
			cache[L2] = CACHEINFO(2, 'U', 128, 1, 4, 1, 64, 512);
			break;
		case 0x3A: // (sandpile) code and data L2 cache, 192 KB, 6 ways, 64 byte lines, sectored (htt?)
			cache[L2] = CACHEINFO(2, 'U', 192, 1, 6, 1, 64, 512);
			break;
		case 0x3B: // (sandpile) code and data L2 cache, 128 KB, 2 ways, 64 byte lines, sectored (htt?)
			cache[L2] = CACHEINFO(2, 'U', 128, 1, 2, 1, 64, 1024);
			break;
		case 0x3C: // (sandpile) code and data L2 cache, 256 KB, 4 ways, 64 byte lines, sectored
			cache[L2] = CACHEINFO(2, 'U', 256, 1, 4, 1, 64, 1024);
			break;
		case 0x3D: // (sandpile) code and data L2 cache, 384 KB, 6 ways, 64 byte lines, sectored (htt?)
			cache[L2] = CACHEINFO(2, 'U', 384, 1, 6, 1, 64, 1024);
			break;
		case 0x3E: // (sandpile) code and data L2 cache, 512 KB, 4 ways, 64 byte lines, sectored (htt?)
			cache[L2] = CACHEINFO(2, 'U', 512, 1, 4, 1, 64, 2048);
			break;
		case 0x41: // 2nd-level cache: 128 KBytes, 4-way set associative, 32 byte line size
			cache[L2] = CACHEINFO(2, 'U', 128, 1, 4, 1, 32, 1024);
			break;
		case 0x42: // 2nd-level cache: 256 KBytes, 4-way set associative, 32 byte line size
			cache[L2] = CACHEINFO(2, 'U', 256, 1, 4, 1, 32, 2048);
			break;
		case 0x43: // 2nd-level cache: 512 KBytes, 4-way set associative, 32 byte line size
			cache[L2] = CACHEINFO(2, 'U', 512, 1, 4, 1, 32, 4096);
			break;
		case 0x44: // 2nd-level cache: 1 MByte, 4-way set associative, 32 byte line size
			cache[L2] = CACHEINFO(2, 'U', 1024, 1, 4, 1, 32, 8192);
			break;
		case 0x45: // 2nd-level cache: 2 MByte, 4-way set associative, 32 byte line size
			cache[L2] = CACHEINFO(2, 'U', 2048, 1, 4, 1, 32, 16384);
			break;
		case 0x46: // 3rd-level cache: 4 MByte, 4-way set associative, 64 byte line size
			cache[L2] = CACHEINFO(2, 'U', 4096, 1, 4, 1, 64, 16384);
			break;
		case 0x47: // 3rd-level cache: 8 MByte, 8-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 8192, 1, 8, 1, 64, 16384);
			break;
		case 0x48: // 2nd-level cache: 3 MByte, 12-way set associative, 64 byte line size
			cache[L2] = CACHEINFO(2, 'U', 3072, 1, 12, 1, 64, 4096);
			break;
		// 3rd-level cache: 4 MByte, 16-way set associative, 64-byte line size (Intel Xeon processor MP, Family 0FH, Model 06H);			
		// 2nd-level cache: 4 MByte, 16-way set associative, 64 byte line size
		case 0x49:
			if (cpu.family == 0xf && cpu.family == 6)
				cache[L3] = CACHEINFO(3, 'U', 4096, 1, 16, 1, 64, 4096);
			else
				cache[L2] = CACHEINFO(2, 'U', 4096, 1, 16, 1, 64, 4096);
			break;
		case 0x4A: // 3rd-level cache: 6 MByte, 12-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 6144, 1, 12, 1, 64, 6144);
			break;
		case 0x4B: // 3rd-level cache: 8 MByte, 16-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 8192, 1, 16, 1, 64, 8192);
			break;
		case 0x4C: // 3rd-level cache: 12 MByte, 12-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 8192, 1, 12, 1, 64, 16384);
			break;
		case 0x4D: // 3rd-level cache: 16 MByte, 16-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 16384, 1, 16, 1, 64, 16384);
			break;
		case 0x4E: // 2nd-level cache: 6MByte, 24-way set associative, 64 byte line size
			cache[L2] = CACHEINFO(2, 'U', 6144, 1, 24, 1, 64, 4096);
			break;
		case 0x60: // 1st-level data cache: 16 KByte, 8-way set associative, 64 byte line size
			cache[L1D] = CACHEINFO(1, 'D', 16, 1, 8, 1, 64, 32);
			break;
		case 0x66: // 1st-level data cache: 8 KByte, 4-way set associative, 64 byte line size
			cache[L1D] = CACHEINFO(1, 'D', 8, 1, 4, 1, 64, 32);
			break;
		case 0x67: // 1st-level data cache: 16 KByte, 4-way set associative, 64 byte line size
			cache[L1D] = CACHEINFO(1, 'D', 16, 1, 4, 1, 64, 64);
			break;
		case 0x68: // 1st-level data cache: 32 KByte, 4-way set associative, 64 byte line size
			cache[L1D] = CACHEINFO(1, 'D', 32, 1, 4, 1, 64, 128);
			break;
		case 0x77: // (sandpile) code L1 cache, 16 KB, 4 ways, 64 byte lines, sectored (IA-64)
			cache[L1I] = CACHEINFO(1, 'I', 16, 1, 4, 1, 64, 64);
			break;
		case 0x78: // 2nd-level cache: 1 MByte, 4-way set associative, 64byte line size
			cache[L2] = CACHEINFO(2, 'U', 1024, 1, 4, 1, 64, 4096);
			break;
		case 0x79: // 2nd-level cache: 128 KByte, 8-way set associative, 64 byte line size, 2 lines per sector
			cache[L2] = CACHEINFO(2, 'U', 128, 1, 8, 2, 64, 128);
			break;
		case 0x7A: // 2nd-level cache: 256 KByte, 8-way set associative, 64 byte line size, 2 lines per sector
			cache[L2] = CACHEINFO(2, 'U', 256, 1, 8, 2, 64, 256);
			break;
		case 0x7B: // 2nd-level cache: 512 KByte, 8-way set associative, 64 byte line size, 2 lines per sector
			cache[L2] = CACHEINFO(2, 'U', 512, 1, 8, 2, 64, 512);
			break;
		case 0x7C: // 2nd-level cache: 1 MByte, 8-way set associative, 64 byte line size, 2 lines per sector
			cache[L2] = CACHEINFO(2, 'U', 1024, 1, 8, 2, 64, 1024);
			break;
		case 0x7D: // 2nd-level cache: 2 MByte, 8-way set associative, 64 byte line size
			cache[L2] = CACHEINFO(2, 'U', 2048, 1, 8, 1, 64, 4096);
			break;
		case 0x7E: // (sandpile) code and data L2 cache, 256 KB, 8 ways, 128 byte lines, sect. (IA-64)
			cache[L2] = CACHEINFO(2, 'U', 256, 1, 8, 1, 128, 256);
			break;
		case 0x7F: // 2nd-level cache: 512 KByte, 2-way set associative, 64-byte line size
			cache[L2] = CACHEINFO(2, 'U', 512, 1, 2, 1, 64, 4096);
			break;
		case 0x80: // 2nd-level cache: 512 KByte, 8-way set associative, 64-byte line size
			cache[L2] = CACHEINFO(2, 'U', 512, 1, 8, 1, 64, 1024);
			break;
		case 0x81: // (sandpile) code and data L2 cache, 128 KB, 8 ways, 32 byte lines
			cache[L2] = CACHEINFO(2, 'U', 128, 1, 8, 1, 32, 512);
			break;
		case 0x82: // 2nd-level cache: 256 KByte, 8-way set associative, 32 byte line size
			cache[L2] = CACHEINFO(2, 'U', 256, 1, 8, 1, 32, 1024);
			break;
		case 0x83: // 2nd-level cache: 512 KByte, 8-way set associative, 32 byte line size
			cache[L2] = CACHEINFO(2, 'U', 512, 1, 8, 1, 32, 2048);
			break;
		case 0x84: // 2nd-level cache: 1 MByte, 8-way set associative, 32 byte line size
			cache[L2] = CACHEINFO(2, 'U', 1024, 1, 8, 1, 32, 4096);
			break;
		case 0x85: // 2nd-level cache: 2 MByte, 8-way set associative, 32 byte line size
			cache[L2] = CACHEINFO(2, 'U', 2048, 1, 8, 1, 32, 8192);
			break;
		case 0x86: // 2nd-level cache: 512 KByte, 4-way set associative, 64 byte line size
			cache[L2] = CACHEINFO(2, 'U', 512, 1, 4, 1, 64, 2048);
			break;
		case 0x87: // 2nd-level cache: 1 MByte, 8-way set associative, 64 byte line size
			cache[L2] = CACHEINFO(2, 'U', 1024, 1, 8, 1, 64, 2048);
			break;
		case 0xD0: // 3rd-level cache: 512 KByte, 4-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 512, 1, 4, 1, 64, 2048);
			break;
		case 0xD1: // 3rd-level cache: 1 MByte, 4-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 1024, 1, 4, 1, 64, 4096);
			break;
		case 0xD2: // 3rd-level cache: 2 MByte, 4-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 2048, 1, 4, 1, 64, 8192);
			break;
		case 0xD6: // 3rd-level cache: 1 MByte, 8-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 1024, 1, 8, 1, 64, 2048);
			break;
		case 0xD7: // 3rd-level cache: 2 MByte, 8-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 2048, 1, 8, 1, 64, 4096);
			break;
		case 0xD8: // 3rd-level cache: 4 MByte, 8-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 4096, 1, 8, 1, 64, 8192);
			break;
		case 0xDC: // 3rd-level cache: 1.5 MByte, 12-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 1536, 1, 12, 1, 64, 2048);
			break;
		case 0xDD: // 3rd-level cache: 3 MByte, 12-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 3072, 1, 12, 1, 64, 4096);
			break;
		case 0xDE: // 3rd-level cache: 6 MByte, 12-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 6144, 1, 12, 1, 64, 8192);
			break;
		case 0xE2: // 3rd-level cache: 2 MByte, 16-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 2048, 1, 16, 1, 64, 2048);
			break;
		case 0xE3: // 3rd-level cache: 4 MByte, 16-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 4096, 1, 16, 1, 64, 4096);
			break;
		case 0xE4: // 3rd-level cache: 8 MByte, 16-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 8192, 1, 16, 1, 64, 8192);
			break;
		case 0xEA: // 3rd-level cache: 12MByte, 24-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 12288, 1, 24, 1, 64, 8192);
			break;
		case 0xEB: // 3rd-level cache: 18MByte, 24-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 18432, 1, 24, 1, 64, 12288);
			break;
		case 0xEC: // 3rd-level cache: 24MByte, 24-way set associative, 64 byte line size
			cache[L3] = CACHEINFO(3, 'U', 24576, 1, 24, 1, 64, 16384);
			break;
		default: continue;
		}
		
		++cacheLevels;
	}
	with (cpu) { // Some do not have L1I, so move items down
		if (cache[0].level == 0) {
			for (size_t i; i < cacheLevels; ++i) {
				cache[i] = cache[i+1];
			}
			cache[cacheLevels] = CACHEINFO.init;
		}
	}
}

version (TestCPUID02h) @system unittest {
	import std.stdio : write, writeln, writef;
	REGISTERS regs; // Celeron 0xf34
	regs.eax = 0x605b5101;
	regs.ebx = 0;
	regs.ecx = 0;
	regs.edx = 0x3c7040;
	
	CPUINFO cpu;
	ddcpuid_leaf2(cpu, regs);
	
	writeln("TEST: CPUID.02h");
	CACHEINFO *cache = void;
	for (uint i; i < CACHE_MAX_LEVEL; ++i) {
		cache = &cpu.cache[i];
		writef("Level %u-%c   : %2ux %6u KiB, %u ways, %u parts, %u B, %u sets",
			cache.level, cache.type, cache.sharedCores, cache.size,
			cache.ways, cache.partitions, cache.lineSize, cache.sets
		);
		if (cache.features) {
			write(',');
			if (cache.features & BIT!(0)) write(" si"); // Self Initiative
			if (cache.features & BIT!(1)) write(" fa"); // Fully Associative
			if (cache.features & BIT!(2)) write(" nwbv"); // No Write-Back Validation
			if (cache.features & BIT!(3)) write(" ci"); // Cache Inclusive
			if (cache.features & BIT!(4)) write(" cci"); // Complex Cache Indexing
		}
		writeln;
	}
}

private
void ddcpuid_leaf5(ref CPUINFO cpu, ref REGISTERS regs) {
	cpu.mwaitMin = regs.ax;
	cpu.mwaitMax = regs.bx;
}

private
void ddcpuid_leaf6(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		cpu.turboboost	= bit(regs.eax, 1);
		cpu.turboboost30	= bit(regs.eax, 14);
		break;
	default:
	}
	
	cpu.arat = bit(regs.eax, 2);
}

private
void ddcpuid_leaf7(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		// EBX
		cpu.sgx	= bit(regs.ebx, 2);
		cpu.hle	= bit(regs.ebx, 4);
		cpu.invpcid	= bit(regs.ebx, 10);
		cpu.rtm	= bit(regs.ebx, 11);
		cpu.smap	= bit(regs.ebx, 20);
		// ECX
		cpu.pku	= bit(regs.ecx, 3);
		cpu.fsrepmov	= bit(regs.ecx, 4);
		cpu.waitpkg	= bit(regs.ecx, 5);
		cpu.cetSs	= bit(regs.ecx, 7);
		cpu.cldemote	= bit(regs.ecx, 25);
		cpu.movdiri	= bit(regs.ecx, 27);
		cpu.movdir64b	= bit(regs.ecx, 28);
		cpu.enqcmd	= bit(regs.ecx, 29);
		// EDX
		cpu.uintr	= bit(regs.edx, 5);
		cpu.md_clear	= bit(regs.edx, 10);
		cpu.serialize	= bit(regs.edx, 14);
		cpu.tsxldtrk	= bit(regs.edx, 16);
		cpu.pconfig	= bit(regs.edx, 18);
		cpu.cetIbt	= bit(regs.edx, 20);
		cpu.amx_bf16	= bit(regs.edx, 22);
		cpu.amx	= bit(regs.edx, 24);
		cpu.amx_int8	= bit(regs.edx, 25);
		cpu.ibrs = bit(regs.edx, 26);
		cpu.stibp	= bit(regs.edx, 27);
		cpu.l1dFlush	= bit(regs.edx, 28);
		cpu.ia32_arch_capabilities	= bit(regs.edx, 29);
		cpu.ssbd	= regs.edx >= BIT!(31);
		break;
	default:
	}

	// ebx
	cpu.fsgsbase	= bit(regs.ebx, 0);
	cpu.bmi1	= bit(regs.ebx, 3);
	cpu.avx2	= bit(regs.ebx, 5);
	cpu.smep	= bit(regs.ebx, 7);
	cpu.bmi2	= bit(regs.ebx, 8);
	cpu.rdseed	= bit(regs.ebx, 18);
	cpu.adx	= bit(regs.ebx, 19);
	cpu.clflushopt	= bit(regs.ebx, 23);
	cpu.sha	= bit(regs.ebx, 29);
	// abx512
	cpu.avx512f	= bit(regs.ebx, 16);
	cpu.avx512er	= bit(regs.ebx, 27);
	cpu.avx512pf	= bit(regs.ebx, 26);
	cpu.avx512cd	= bit(regs.ebx, 28);
	cpu.avx512dq	= bit(regs.ebx, 17);
	cpu.avx512bw	= bit(regs.ebx, 30);
	cpu.avx512_ifma	= bit(regs.ebx, 21);
	cpu.avx512_vbmi	= regs.ebx >= BIT!(31);
	cpu.avx512vl	= bit(regs.ecx, 1);
	cpu.avx512_vbmi2	= bit(regs.ecx, 6);
	cpu.avx512_gfni	= bit(regs.ecx, 8);
	cpu.avx512_vaes	= bit(regs.ecx, 9);
	cpu.avx512_vnni	= bit(regs.ecx, 11);
	cpu.avx512_bitalg	= bit(regs.ecx, 12);
	cpu.avx512_vpopcntdq	= bit(regs.ecx, 14);
	cpu.avx512_4vnniw	= bit(regs.edx, 2);
	cpu.avx512_4fmaps	= bit(regs.edx, 3);
	cpu.avx512_vp2intersect	= bit(regs.edx, 8);
	// ecx
	cpu._5pl	= bit(regs.ecx, 16);
	cpu.rdpid	= bit(regs.ecx, 22);
}

private
void ddcpuid_leaf7sub1(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		// a
		cpu.lam	= bit(regs.eax, 26);
		break;
	default:
	}
	
	cpu.avx512_bf16	= bit(regs.eax, 5);
}

private
void ddcpuid_leafD(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		cpu.amx_xtilecfg	= bit(regs.eax, 17);
		cpu.amx_xtiledata	= bit(regs.eax, 18);
		break;
	default:
	}
}

private
void ddcpuid_leafDsub1(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		cpu.amx_xfd	= bit(regs.eax, 18);
		break;
	default:
	}
}

private
void ddcpuid_leaf12(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		cpu.sgx1 = bit(regs.al, 0);
		cpu.sgx2 = bit(regs.al, 1);
		cpu.sgxMaxSize   = regs.dl;
		cpu.sgxMaxSize64 = regs.dh;
		break;
	default:
	}
}

private
void ddcpuid_leaf4000_0001(ref CPUINFO cpu, ref REGISTERS regs) {
//	switch (cpu.virt.vendor.id) with (VirtVendor) {
//	case KVM:
		cpu.kvm.feature_clocksource	= bit(regs.eax, 0);
		cpu.kvm.feature_nop_io_delay	= bit(regs.eax, 1);
		cpu.kvm.feature_mmu_op	= bit(regs.eax, 2);
		cpu.kvm.feature_clocksource2	= bit(regs.eax, 3);
		cpu.kvm.feature_async_pf	= bit(regs.eax, 4);
		cpu.kvm.feature_steal_time	= bit(regs.eax, 5);
		cpu.kvm.feature_pv_eoi	= bit(regs.eax, 6);
		cpu.kvm.feature_pv_unhault	= bit(regs.eax, 7);
		cpu.kvm.feature_pv_tlb_flush	= bit(regs.eax, 9);
		cpu.kvm.feature_async_pf_vmexit	= bit(regs.eax, 10);
		cpu.kvm.feature_pv_send_ipi	= bit(regs.eax, 11);
		cpu.kvm.feature_pv_poll_control	= bit(regs.eax, 12);
		cpu.kvm.feature_pv_sched_yield	= bit(regs.eax, 13);
		cpu.kvm.feature_clocsource_stable_bit	= bit(regs.eax, 24);
		cpu.kvm.hint_realtime	= bit(regs.edx, 0);
//		break;
//	default:
//	}
}

private
void ddcpuid_leaf4000_0002(ref CPUINFO cpu, ref REGISTERS regs) {
//	switch (cpu.virt.vendor.id) with (VirtVendor) {
//	case HyperV:
		cpu.hv.guest_minor	= cast(ubyte)(regs.eax >> 24);
		cpu.hv.guest_service	= cast(ubyte)(regs.eax >> 16);
		cpu.hv.guest_build	= regs.ax;
		cpu.hv.guest_opensource	= regs.edx >= BIT!(31);
		cpu.hv.guest_vendor_id	= (regs.edx >> 16) & 0xFFF;
		cpu.hv.guest_os	= regs.dh;
		cpu.hv.guest_major	= regs.dl;
//		break;
//	default:
//	}
}

private
void ddcpuid_leaf4000_0003(ref CPUINFO cpu, ref REGISTERS regs) {
//	switch (cpu.virt.vendor.id) with (VirtVendor) {
//	case HyperV:
		cpu.hv.base_feat_vp_runtime_msr	= bit(regs.eax, 0);
		cpu.hv.base_feat_part_time_ref_count_msr	= bit(regs.eax, 1);
		cpu.hv.base_feat_basic_synic_msrs	= bit(regs.eax, 2);
		cpu.hv.base_feat_stimer_msrs	= bit(regs.eax, 3);
		cpu.hv.base_feat_apic_access_msrs	= bit(regs.eax, 4);
		cpu.hv.base_feat_hypercall_msrs	= bit(regs.eax, 5);
		cpu.hv.base_feat_vp_id_msr	= bit(regs.eax, 6);
		cpu.hv.base_feat_virt_sys_reset_msr	= bit(regs.eax, 7);
		cpu.hv.base_feat_stat_pages_msr	= bit(regs.eax, 8);
		cpu.hv.base_feat_part_ref_tsc_msr	= bit(regs.eax, 9);
		cpu.hv.base_feat_guest_idle_state_msr	= bit(regs.eax, 10);
		cpu.hv.base_feat_timer_freq_msrs	= bit(regs.eax, 11);
		cpu.hv.base_feat_debug_msrs	= bit(regs.eax, 12);
		cpu.hv.part_flags_create_part	= bit(regs.ebx, 0);
		cpu.hv.part_flags_access_part_id	= bit(regs.ebx, 1);
		cpu.hv.part_flags_access_memory_pool	= bit(regs.ebx, 2);
		cpu.hv.part_flags_adjust_msg_buffers	= bit(regs.ebx, 3);
		cpu.hv.part_flags_post_msgs	= bit(regs.ebx, 4);
		cpu.hv.part_flags_signal_events	= bit(regs.ebx, 5);
		cpu.hv.part_flags_create_port	= bit(regs.ebx, 6);
		cpu.hv.part_flags_connect_port	= bit(regs.ebx, 7);
		cpu.hv.part_flags_access_stats	= bit(regs.ebx, 8);
		cpu.hv.part_flags_debugging	= bit(regs.ebx, 11);
		cpu.hv.part_flags_cpu_mgmt	= bit(regs.ebx, 12);
		cpu.hv.part_flags_cpu_profiler	= bit(regs.ebx, 13);
		cpu.hv.part_flags_expanded_stack_walk	= bit(regs.ebx, 14);
		cpu.hv.part_flags_access_vsm	= bit(regs.ebx, 16);
		cpu.hv.part_flags_access_vp_regs	= bit(regs.ebx, 17);
		cpu.hv.part_flags_extended_hypercalls	= bit(regs.ebx, 20);
		cpu.hv.part_flags_start_vp	= bit(regs.ebx, 21);
		cpu.hv.pm_max_cpu_power_state_c0	= bit(regs.ecx, 0);
		cpu.hv.pm_max_cpu_power_state_c1	= bit(regs.ecx, 1);
		cpu.hv.pm_max_cpu_power_state_c2	= bit(regs.ecx, 2);
		cpu.hv.pm_max_cpu_power_state_c3	= bit(regs.ecx, 3);
		cpu.hv.pm_hpet_reqd_for_c3	= bit(regs.ecx, 4);
		cpu.hv.misc_feat_mwait	= bit(regs.eax, 0);
		cpu.hv.misc_feat_guest_debugging	= bit(regs.eax, 1);
		cpu.hv.misc_feat_perf_mon	= bit(regs.eax, 2);
		cpu.hv.misc_feat_pcpu_dyn_part_event	= bit(regs.eax, 3);
		cpu.hv.misc_feat_xmm_hypercall_input	= bit(regs.eax, 4);
		cpu.hv.misc_feat_guest_idle_state	= bit(regs.eax, 5);
		cpu.hv.misc_feat_hypervisor_sleep_state	= bit(regs.eax, 6);
		cpu.hv.misc_feat_query_numa_distance	= bit(regs.eax, 7);
		cpu.hv.misc_feat_timer_freq	= bit(regs.eax, 8);
		cpu.hv.misc_feat_inject_synmc_xcpt	= bit(regs.eax, 9);
		cpu.hv.misc_feat_guest_crash_msrs	= bit(regs.eax, 10);
		cpu.hv.misc_feat_debug_msrs	= bit(regs.eax, 11);
		cpu.hv.misc_feat_npiep1	= bit(regs.eax, 12);
		cpu.hv.misc_feat_disable_hypervisor	= bit(regs.eax, 13);
		cpu.hv.misc_feat_ext_gva_range_for_flush_va_list	= bit(regs.eax, 14);
		cpu.hv.misc_feat_hypercall_output_xmm	= bit(regs.eax, 15);
		cpu.hv.misc_feat_sint_polling_mode	= bit(regs.eax, 17);
		cpu.hv.misc_feat_hypercall_msr_lock	= bit(regs.eax, 18);
		cpu.hv.misc_feat_use_direct_synth_msrs	= bit(regs.eax, 19);
//		break;
//	default:
//	}
}

private
void ddcpuid_leaf4000_0004(ref CPUINFO cpu, ref REGISTERS regs) {
//	switch (cpu.virt.vendor.id) with (VirtVendor) {
//	case HyperV:
		cpu.hv.hint_hypercall_for_process_switch	= bit(regs.eax, 0);
		cpu.hv.hint_hypercall_for_tlb_flush	= bit(regs.eax, 1);
		cpu.hv.hint_hypercall_for_tlb_shootdown	= bit(regs.eax, 2);
		cpu.hv.hint_msr_for_apic_access	= bit(regs.eax, 3);
		cpu.hv.hint_msr_for_sys_reset	= bit(regs.eax, 4);
		cpu.hv.hint_relax_time_checks	= bit(regs.eax, 5);
		cpu.hv.hint_dma_remapping	= bit(regs.eax, 6);
		cpu.hv.hint_interrupt_remapping	= bit(regs.eax, 7);
		cpu.hv.hint_x2apic_msrs	= bit(regs.eax, 8);
		cpu.hv.hint_deprecate_auto_eoi	= bit(regs.eax, 9);
		cpu.hv.hint_synth_cluster_ipi_hypercall	= bit(regs.eax, 10);
		cpu.hv.hint_ex_proc_masks_interface	= bit(regs.eax, 11);
		cpu.hv.hint_nested_hyperv	= bit(regs.eax, 12);
		cpu.hv.hint_int_for_mbec_syscalls	= bit(regs.eax, 13);
		cpu.hv.hint_nested_enlightened_vmcs_interface	= bit(regs.eax, 14);
//		break;
//	default:
//	}
}

private
void ddcpuid_leaf4000_0006(ref CPUINFO cpu, ref REGISTERS regs) {
//	switch (cpu.virt.vendor.id) with (VirtVendor) {
//	case HyperV:
		cpu.hv.host_feat_avic	= bit(regs.eax, 0);
		cpu.hv.host_feat_msr_bitmap	= bit(regs.eax, 1);
		cpu.hv.host_feat_perf_counter	= bit(regs.eax, 2);
		cpu.hv.host_feat_nested_paging	= bit(regs.eax, 3);
		cpu.hv.host_feat_dma_remapping	= bit(regs.eax, 4);
		cpu.hv.host_feat_interrupt_remapping	= bit(regs.eax, 5);
		cpu.hv.host_feat_mem_patrol_scrubber	= bit(regs.eax, 6);
		cpu.hv.host_feat_dma_prot_in_use	= bit(regs.eax, 7);
		cpu.hv.host_feat_hpet_requested	= bit(regs.eax, 8);
		cpu.hv.host_feat_stimer_volatile	= bit(regs.eax, 9);
//		break;
//	default:
//	}
}

private
void ddcpuid_leaf4000_0010(ref CPUINFO cpu, ref REGISTERS regs) {
//	switch (cpu.virt.vendor.id) with (VirtVendor) {
//	case VBoxMin: // VBox Minimal
		cpu.vbox.tsc_freq_khz = regs.eax;
		cpu.vbox.apic_freq_khz = regs.ebx;
//		break;
//	default:
//	}
}

private
void ddcpuid_leaf8000_0001(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) with (Vendor) {
	case AMD:
		// ecx
		cpu.virtualization	= bit(regs.ecx, 2);
		cpu.x2apic	= bit(regs.ecx, 3);
		cpu.sse4a	= bit(regs.ecx, 6);
		cpu.xop	= bit(regs.ecx, 11);
		cpu.skinit	= bit(regs.ecx, 12);
		cpu.fma4	= bit(regs.ecx, 16);
		cpu.tbm	= bit(regs.ecx, 21);
		// edx
		cpu.mmxExtended	= bit(regs.edx, 22);
		cpu._3DNowExtended	= bit(regs.edx, 30);
		cpu._3DNow	= regs.edx >= BIT!(31);
		break;
	default:
	}
	
	// ecx
	cpu.lahf64	= bit(regs.ecx, 0);
	cpu.lzcnt	= bit(regs.ecx, 5);
	cpu.prefetchw	= bit(regs.ecx, 8);
	cpu.monitorx	= bit(regs.ecx, 29);
	// edx
	cpu.syscall	= bit(regs.edx, 11);
	cpu.nx	= bit(regs.edx, 20);
	cpu.page1gb	= bit(regs.edx, 26);
	cpu.rdtscp	= bit(regs.edx, 27);
	cpu.x86_64	= bit(regs.edx, 29);
}

private
void ddcpuid_leaf8000_0007(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		cpu.rdseed	= bit(regs.ebx, 28);
		break;
	case AMD:
		cpu.tm	= bit(regs.edx, 4);
		cpu.turboboost	= bit(regs.edx, 9);
		break;
	default:
	}
	
	cpu.rdtscInvariant	= bit(regs.edx, 8);
}

private
void ddcpuid_leaf8000_0008(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		cpu.wbnoinvd	= bit(regs.ebx, 9);
		break;
	case AMD:
		cpu.ibpb	= bit(regs.ebx, 12);
		cpu.ibrs	= bit(regs.ebx, 14);
		cpu.stibp	= bit(regs.ebx, 15);
		cpu.ibrsAlwaysOn	= bit(regs.ebx, 16);
		cpu.stibpAlwaysOn	= bit(regs.ebx, 17);
		cpu.ibrsPreferred	= bit(regs.ebx, 18);
		cpu.ssbd	= bit(regs.ebx, 24);
		break;
	default:
	}
	
	cpu.physicalBits = regs.al;
	cpu.linearBits = regs.ah;
}

private
void ddcpuid_leaf8000_000A(ref CPUINFO cpu, ref REGISTERS regs) {
	switch (cpu.vendor.id) {
	case Vendor.AMD:
		cpu.virtVersion	= regs.al; // EAX[7:0]
		cpu.apicv	= bit(regs.edx, 13);
		break;
	default:
	}
}

private
void ddcpuid_topology(ref CPUINFO cpu) {
	ushort sc = void;	/// raw cores shared across cache level
	ushort crshrd = void;	/// actual count of shared cores
	ubyte type = void;	/// cache type
	ubyte mids = void;	/// maximum IDs to this cache
	int shared_ = 1;    /// (Total logical) Shared threads per core
	REGISTERS regs = void;	/// registers
	
	cpu.cacheLevels = 0;
	CACHEINFO *ca = cast(CACHEINFO*)cpu.cache;
	
	//TODO: Make 1FH/BH/4H/etc. functions.
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		if (cpu.maxLeaf >= 0x1f) goto L_CACHE_INTEL_1FH;
		if (cpu.maxLeaf >= 0xb)  goto L_CACHE_INTEL_BH;
		if (cpu.maxLeaf >= 4)    goto L_CACHE_INTEL_4H;
		// Celeron 0xf34 has maxLeaf=03h and ext=8000_0008h
		if (cpu.maxLeaf >= 2)    goto L_CACHE_INTEL_2H;
		if (cpu.maxLeafExtended >= 0x8000_0005) goto L_AMD_TOPOLOGY_EXT_5H; // Yes
		break;
		
L_CACHE_INTEL_1FH:
		//TODO: Support levels 3,4,5 in CPUID.1FH
		//      (Module, Tile, and Die)
		ddcpuid_id(regs, 0x1f, 1); // Cores (logical)
		cpu.logicalCores = regs.bx;
		
		ddcpuid_id(regs, 0x1f, 0); // SMT (architectural states per core)
		cpu.physicalCores = cast(ushort)(cpu.logicalCores / regs.bx);
		
		goto L_CACHE_INTEL_4H;
		
L_CACHE_INTEL_BH:
		ddcpuid_id(regs, 0xb, 1); // Cores (logical)
		cpu.logicalCores = regs.bx;
		
		ddcpuid_id(regs, 0xb, 0); // SMT (architectural states per core)
		cpu.physicalCores = cast(ushort)(cpu.logicalCores / regs.bx);
		
L_CACHE_INTEL_4H:
		ddcpuid_id(regs, 4, cpu.cacheLevels);
		
		type = regs.eax & CACHE_MASK; // EAX[4:0]
		if (type == 0 || cpu.cacheLevels >= CACHE_MAX_LEVEL) return;
		
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
		
		if (cpu.logicalCores == 0) with (cpu) { // skip if already populated
			logicalCores = mids;
			physicalCores = cpu.htt ? mids >> 1 : mids;
		}
		
		crshrd = (((regs.eax >> 14) & 2047) + 1);	// EAX[25:14]
		sc = cast(ushort)(cpu.logicalCores / crshrd); // cast for ldc 0.17.1
		ca.sharedCores = sc ? sc : 1;
		version (Trace) trace("intel.4h mids=%u shared=%u crshrd=%u sc=%u",
			mids, ca.sharedCores, crshrd, sc);
		
		++cpu.cacheLevels; ++ca;
		goto L_CACHE_INTEL_4H;

L_CACHE_INTEL_2H:
		ddcpuid_id(regs, 2);
		ddcpuid_leaf2(cpu, regs);
		break;
	case AMD:
		if (cpu.maxLeafExtended >= 0x8000_001E) goto L_AMD_TOPOLOGY_EXT_1EH;
		if (cpu.maxLeafExtended >= 0x8000_0008) goto L_AMD_TOPOLOGY_EXT_8H;
		if (cpu.maxLeafExtended >= 0x8000_0005) goto L_AMD_TOPOLOGY_EXT_5H;
		
		break;

L_AMD_TOPOLOGY_EXT_1EH:
		
		ddcpuid_id(regs, 0x8000_0001);
		
		if ((regs.ecx & BIT!22) == 0) goto L_AMD_TOPOLOGY_EXT_8H;
		
		ddcpuid_id(regs, 0x8000_001E);
		
		shared_ = regs.bh + 1; // ThreadsPerComputeUnit
		version (Trace) trace("amd.0x8000_001E shared=%u", shared_);
		
		goto L_AMD_TOPOLOGY_EXT_1DH;
		
L_AMD_TOPOLOGY_EXT_8H:
		// See APM Volume 3 Appendix E.5
		// For some reason, CPUID Fn8000_001E_EBX is not mentioned there
		ddcpuid_id(regs, 0x8000_0008);
		
		type = regs.cx >> 12; // ApicIdSize
		
		if (type) { // Extended
			cpu.physicalCores = regs.cl + 1;
			cpu.logicalCores = cast(ushort)(1 << type);
		} else { // Legacy
			cpu.logicalCores = cpu.physicalCores = regs.cl + 1;
		}
		
		//
		// AMD newer cache method
		//
		
L_AMD_TOPOLOGY_EXT_1DH: // Almost the same as Intel's
		ddcpuid_id(regs, 0x8000_001d, cpu.cacheLevels);
		
		type = regs.eax & CACHE_MASK; // EAX[4:0]
		if (type == 0 || cpu.cacheLevels >= CACHE_MAX_LEVEL) return;
		
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
		sc = cast(ushort)(cpu.apicMaxId / crshrd); // cast for ldc 0.17.1
		ca.sharedCores = sc ? sc : 1;
		
		if (cpu.logicalCores == 0) with (cpu) { // skip if already populated
			logicalCores = cpu.apicMaxId;
			physicalCores = cpu.apicMaxId / shared_;
		}
		
		version (Trace) trace("amd.8000_001Dh mids=%u shared=%u crshrd=%u sc=%u",
			mids, ca.sharedCores, crshrd, sc);
		
		++cpu.cacheLevels; ++ca;
		goto L_AMD_TOPOLOGY_EXT_1DH;
		
		//
		// AMD legacy cache
		//
		
L_AMD_TOPOLOGY_EXT_5H:
		ddcpuid_id(regs, 0x8000_0005);
		
		cpu.cache[0].level = 1; // L1-D
		cpu.cache[0].type = 'D'; // data
		cpu.cache[0].size = regs.ecx >> 24;
		cpu.cache[0].ways = cast(ubyte)(regs.ecx >> 16);
		cpu.cache[0].lines = regs.ch;
		cpu.cache[0].lineSize = regs.cl;
		cpu.cache[0].sets = 1;
		
		cpu.cache[1].level = 1; // L1-I
		cpu.cache[1].type = 'I'; // instructions
		cpu.cache[1].size = regs.edx >> 24;
		cpu.cache[1].ways = cast(ubyte)(regs.edx >> 16);
		cpu.cache[1].lines = regs.dh;
		cpu.cache[1].lineSize = regs.dl;
		cpu.cache[1].sets = 1;
		
		cpu.cacheLevels = 2;
		
		if (cpu.maxLeafExtended < 0x8000_0006)
			return; // No L2/L3
		
		// See Table E-4. L2/L3 Cache and TLB Associativity Field Encoding
		static immutable ubyte[16] _amd_cache_ways = [
			// 7h is reserved
			// 9h mentions 8000_001D but that's already supported
			0, 1, 2, 3, 4, 6, 8, 0, 16, 0, 32, 48, 64, 96, 128, 255
		];
		
		ddcpuid_id(regs, 0x8000_0006);
		
		type = regs.cx >> 12; // amd_ways_l2
		if (type == 0) break;
		
		cpu.cache[2].level = 2;  // L2
		cpu.cache[2].type = 'U'; // unified
		cpu.cache[2].size = regs.ecx >> 16;
		cpu.cache[2].ways = _amd_cache_ways[type];
		cpu.cache[2].lines = regs.ch & 0xf;
		cpu.cache[2].lineSize = regs.cl;
		cpu.cache[2].sets = 1;
		cpu.cacheLevels = 3;
		
		type = regs.dx >> 12; // amd_ways_l3
		if (type == 0) break;
		
		cpu.cache[3].level = 3;  // L3
		cpu.cache[3].type = 'U'; // unified
		cpu.cache[3].size = ((regs.edx >> 18) + 1) << 9;
		cpu.cache[3].ways = _amd_cache_ways[type];
		cpu.cache[3].lines = regs.dh & 0xf;
		cpu.cache[3].lineSize = regs.dl & 0x7F;
		cpu.cache[3].sets = 1;
		cpu.cacheLevels = 4;
		break;
	default:
	}
	
	with (cpu) physicalCores = logicalCores = 1;
}

private struct LeafInfo {
	uint leaf;
	uint sub;
	void function(ref CPUINFO, ref REGISTERS) func;
}
private struct LeafExtInfo {
	uint leaf;
	void function(ref CPUINFO, ref REGISTERS) func;
}

/// Fetch CPU information.
/// Params: cpu = CPUINFO structure
void ddcpuid_cpuinfo(ref CPUINFO cpu) {
	static immutable LeafInfo[] regulars = [
		{ 0x1,	0,	&ddcpuid_leaf1 },	// Sets brand index
		{ 0x5,	0,	&ddcpuid_leaf5 },
		{ 0x6,	0,	&ddcpuid_leaf6 },
		{ 0x7,	0,	&ddcpuid_leaf7 },
		{ 0x7,	1,	&ddcpuid_leaf7sub1 },
		{ 0xd,	0,	&ddcpuid_leafD },
		{ 0xd,	1,	&ddcpuid_leafDsub1 },
		{ 0x12,	0,	&ddcpuid_leaf12 },
	];
	static immutable LeafExtInfo[] extended = [
		{ 0x8000_0001,	&ddcpuid_leaf8000_0001 },
		{ 0x8000_0007,	&ddcpuid_leaf8000_0007 },
		{ 0x8000_0008,	&ddcpuid_leaf8000_0008 },
		{ 0x8000_000a,	&ddcpuid_leaf8000_000A },
	];
	REGISTERS regs = void;	/// registers
	
	ddcpuid_vendor(cpu.vendor.string_);
	cpu.vendor.id = ddcpuid_vendor_id(cpu.vendor);
	
	foreach (ref immutable(LeafInfo) l; regulars) {
		if (l.leaf > cpu.maxLeaf) break;
		
		ddcpuid_id(regs, l.leaf, l.sub);
		l.func(cpu, regs);
	}
	
	// Paravirtualization leaves
	if (cpu.maxLeafVirt >= 0x4000_0000) {
		ddcpuid_virt_vendor(cpu.virtVendor.string_);
		cpu.virtVendor.id = ddcpuid_virt_vendor_id(cpu.virtVendor);
		
		switch (cpu.virtVendor.id) with (VirtVendor) {
		case KVM:
			ddcpuid_id(regs, 0x4000_0001);
			ddcpuid_leaf4000_0001(cpu, regs);
			break;
		case HyperV:
			ddcpuid_id(regs, 0x4000_0002);
			ddcpuid_leaf4000_0002(cpu, regs);
			ddcpuid_id(regs, 0x4000_0003);
			ddcpuid_leaf4000_0003(cpu, regs);
			ddcpuid_id(regs, 0x4000_0004);
			ddcpuid_leaf4000_0004(cpu, regs);
			ddcpuid_id(regs, 0x4000_0006);
			ddcpuid_leaf4000_0006(cpu, regs);
			break;
		case VBoxMin:
			ddcpuid_id(regs, 0x4000_0010);
			ddcpuid_leaf4000_0010(cpu, regs);
			break;
		default:
		}
	}
	
	// Extended leaves
	if (cpu.maxLeafExtended >= 0x8000_0000) {
		foreach (ref immutable(LeafExtInfo) l; extended) {
			if (l.leaf > cpu.maxLeafExtended) break;
			
			ddcpuid_id(regs, l.leaf);
			l.func(cpu, regs);
		}
	}
	
	ddcpuid_model_string(cpu); // Sets brand string
	ddcpuid_topology(cpu);	 // Sets core/thread/cache topology
}

const(char) *ddcpuid_baseline(ref CPUINFO cpu) {
	if (cpu.avx512f && cpu.avx512bw && cpu.avx512cd &&
		cpu.avx512dq && cpu.avx512vl) {
		return "x86-64-v4";
	}
	
	if (cpu.avx2 && cpu.avx && cpu.bmi2 && cpu.bmi1 &&
		cpu.f16c && cpu.fma && cpu.lzcnt &&
		cpu.movbe && cpu.osxsave) {
		return "x86-64-v3";
	}
	
	if (cpu.sse42 && cpu.sse41 && cpu.ssse3 && cpu.sse3 &&
		cpu.lahf64 && cpu.popcnt && cpu.cmpxchg16b) {
		return "x86-64-v2";
	}
	
	if (cpu.sse && cpu.sse2 && cpu.mmx && cpu.fxsr &&
		cpu.cmpxchg8b && cpu.cmov && cpu.fpu && cpu.syscall) {
		return "x86-64"; // baseline, v1
	}
	
	// NOTE: K7 is still family 5 and didn't have SSE2.
	// NOTE: Whoever manages to run this on an i486 has my respect.
	switch (cpu.family) {
	case 3:  return "i386"; // 80386
	case 4:  return "i486"; // 80486
	case 5:  return "i586"; // Pentium / MMX
	default: return "i686"; // Pentium Pro / II
	}
}
