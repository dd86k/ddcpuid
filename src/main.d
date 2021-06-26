/**
 * Program entry point.
 *
 * NOTE: printf is mainly used for two reasons. First, fputs with stdout
 *       crashes on Windows. Secondly, line buffering.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: © 2016-2021 dd86k
 * License: MIT
 */
module main;

import ddcpuid;

private:
@system:
extern (C):

int strcmp(scope const char*, scope const char*);
int puts(scope const char*);
int putchar(int);
int atoi(scope const char*);

static if (__VERSION__ >= 2092) {
	pragma(printf)
	int printf(scope const char*, ...);
} else {
	int printf(scope const char*, ...);
}

/// Compiler version template for betterC usage
template CVER(int v) {
	enum CVER =
		cast(char)((v / 1000) + '0') ~
		"." ~
		cast(char)(((v % 1000) / 100) + '0') ~
		cast(char)(((v % 100) / 10) + '0') ~
		cast(char)((v % 10) + '0');
}

/// Make a bit mask of one bit at n position
template BIT(int n) if (n <= 31) { enum uint BIT = 1 << n; }

enum : uint {
	MAX_LEAF	= 0x20, /// Maximum leaf override
	MAX_VLEAF	= 0x4000_0020, /// Maximum virt leaf override
	MAX_ELEAF	= 0x8000_0020, /// Maximum extended leaf override
}

/// Command-line options
struct options_t {
	uint maxsub;	/// Maximum subleaf for -r (-s)
	bool table;	/// Raw table (-r)
	bool override_;	/// Override leaves (-o)
}

/// print help page
void clih() {
	puts(
	"x86/AMD64 CPUID information tool\n"~
	"\n"~
	"USAGE\n"~
	"  ddcpuid [OPTIONS...]\n"~
	"\n"~
	"OPTIONS\n"~
	"  -r    Show raw CPUID data in a table\n"~
	"  -s    Set subleaf (ECX) input value with -r\n"~
	"  -o    Override maximum leaves to 20h, 4000_0020h, and 8000_0020h\n"~
	"\n"~
	"PAGES\n"~
	"  --version    Print version screen and quit\n"~
	"  --ver        Print version and quit\n"~
	"  -h, --help   Print this help screen and quit"
	);
}

/// print version page
void cliv() {
	puts(
	"ddcpuid-"~DDCPUID_PLATFORM~" v"~DDCPUID_VERSION~" ("~__TIMESTAMP__~")\n"~
	"Copyright (c) dd86k 2016-2021\n"~
	"License: MIT License <http://opensource.org/licenses/MIT>\n"~
	"Project page: <https://github.com/dd86k/ddcpuid>\n"~
	"Compiler: "~__VENDOR__~" v"~CVER!(__VERSION__)
	);
}

/// Print cpuid table entry into stdout.
/// Params:
/// 	leaf = EAX input
/// 	sub = ECX input
pragma(inline, false) // ldc optimization thing
void printc(uint leaf, uint sub) {
	REGISTERS regs = void;
	asmcpuid(regs, leaf, sub);
	with (regs)
	printf("| %8x | %8x | %8x | %8x | %8x | %8x |\n",
		leaf, sub, eax, ebx, ecx, edx);
}

int main(int argc, const(char) **argv) {
	options_t opts;	/// Command-line options
	
	const(char) *arg = void;
	for (int argi = 1; argi < argc; ++argi) {
		if (argv[argi][1] == '-') { // Long arguments
			arg = argv[argi] + 2;
			if (strcmp(arg, "help") == 0) { clih; return 0; }
			if (strcmp(arg, "version") == 0) { cliv; return 0; }
			if (strcmp(arg, "ver") == 0) { puts(DDCPUID_VERSION); return 0; }
			printf("Unknown parameter: '%s'\n", arg);
			return 1;
		} else if (argv[argi][0] == '-') { // Short arguments
			arg = argv[argi] + 1;
			char o = void;
			while ((o = *arg) != 0) {
				++arg;
				switch (o) {
				case 'o': opts.override_ = true; continue;
				case 'r': opts.table = true; continue;
				case 's':
					if (++argi >= argc) {
						puts("Missing parameter: sub-leaf (-s)");
						return 1;
					}
					opts.maxsub = atoi(argv[argi]);
					continue;
				case 'h': clih; return 0;
				case 'V': cliv; return 0;
				default:
					printf("Unknown parameter: '-%c'\n", o);
					return 1;
				}
			}
		} // else if
	} // for
	
	CPUINFO info;
	
	if (opts.override_ == false) {
		getLeaves(info);
	} else {
		info.max_leaf = MAX_LEAF;
		info.max_virt_leaf = MAX_VLEAF;
		info.max_ext_leaf = MAX_ELEAF;
	}
	
	if (opts.table) { // -r
		puts(
		"| Leaf     | Sub-leaf | EAX      | EBX      | ECX      | EDX      |\n"~
		"|----------|----------|----------|----------|----------|----------|"
		);
		
		// Normal
		uint l = void, s = void;
		for (l = 0; l <= info.max_leaf; ++l)
			for (s = 0; s <= opts.maxsub; ++s)
				printc(l, s);
		
		// Paravirtualization
		if (info.max_virt_leaf > 0x4000_0000)
		for (l = 0x4000_0000; l <= info.max_virt_leaf; ++l)
			for (s = 0; s <= opts.maxsub; ++s)
				printc(l, s);
		
		// Extended
		for (l = 0x8000_0000; l <= info.max_ext_leaf; ++l)
			for (s = 0; s <= opts.maxsub; ++s)
				printc(l, s);
		return 0;
	}
	
	getInfo(info);
	
	// NOTE: .ptr crash with GDC -O3
	//       glibc!__strlen_sse2 (in printf)
	char *vendor = cast(char*)info.vendor;
	char *brand  = cast(char*)info.brand;
	
	// Brand string left space trimming
	// Extremely common in Intel but let's also do it for others
	while (*brand == ' ') ++brand;
	
	//
	// ANCHOR Processor basic information
	//
	
	printf(
	"Vendor      : %.12s\n"~
	"Brand       : %.48s\n"~
	"Identifier  : Family %u (0x%x) [0x%x:0x%x] Model %u (0x%x) [0x%x:0x%x] Stepping %u\n"~
	"Cores       : %u threads\n"~
	"Extensions  :",
	vendor, brand,
	info.family, info.family, info.family_base, info.family_ext,
	info.model, info.model, info.model_base, info.model_ext,
	info.stepping,
	info.cores.logical
	);
	
	if (info.ext.fpu) {
		printf(" x87/FPU");
		if (info.ext.f16c) printf(" +F16C");
	}
	if (info.ext.mmx) {
		printf(" MMX");
		if (info.ext.mmxext) printf(" ExtMMX");
	}
	if (info.ext._3dnow) {
		printf(" 3DNow!");
		if (info.ext._3dnowext) printf(" Ext3DNow!");
	}
	if (info.ext.sse) {
		printf(" SSE");
		if (info.ext.sse2) printf(" SSE2");
		if (info.ext.sse3) printf(" SSE3");
		if (info.ext.ssse3) printf(" SSSE3");
		if (info.ext.sse41) printf(" SSE4.1");
		if (info.ext.sse42) printf(" SSE4.2");
		if (info.ext.sse4a) printf(" SSE4a");
		if (info.ext.xop) printf(" XOP");
	}
	if (info.ext.x86_64) {
		switch (info.vendor_id) {
		case Vendor.Intel: printf(" Intel64/x86-64"); break;
		case Vendor.AMD: printf(" AMD64/x86-64"); break;
		default: printf(" x86-64");
		}
		if (info.ext.lahf64)
			printf(" +LAHF64");
	}
	if (info.virt.available)
		switch (info.vendor_id) {
		case Vendor.Intel: printf(" VT-x/VMX"); break;
		case Vendor.AMD: // SVM
			printf(" AMD-V/VMX");
			if (info.virt.version_)
				printf(":v%u", info.virt.version_);
			break;
		case Vendor.VIA: printf(" VIA-VT/VMX"); break;
		default: printf(" VMX");
		}
	if (info.ext.aes_ni) printf(" AES-NI");
	if (info.ext.avx) printf(" AVX");
	if (info.ext.avx2) printf(" AVX2");
	if (info.ext.avx512f) {
		printf(" AVX512F");
		if (info.ext.avx512er) printf(" AVX512ER");
		if (info.ext.avx512pf) printf(" AVX512PF");
		if (info.ext.avx512cd) printf(" AVX512CD");
		if (info.ext.avx512dq) printf(" AVX512DQ");
		if (info.ext.avx512bw) printf(" AVX512BW");
		if (info.ext.avx512vl) printf(" AVX512VL");
		if (info.ext.avx512_ifma) printf(" AVX512_IFMA");
		if (info.ext.avx512_vbmi) printf(" AVX512_VBMI");
		if (info.ext.avx512_4vnniw) printf(" AVX512_4VNNIW");
		if (info.ext.avx512_4fmaps) printf(" AVX512_4FMAPS");
		if (info.ext.avx512_vbmi2) printf(" AVX512_VBMI2");
		if (info.ext.avx512_gfni) printf(" AVX512_GFNI");
		if (info.ext.avx512_vaes) printf(" AVX512_VAES");
		if (info.ext.avx512_vnni) printf(" AVX512_VNNI");
		if (info.ext.avx512_bitalg) printf(" AVX512_BITALG");
		if (info.ext.avx512_bf16) printf(" AVX512_BF16");
		if (info.ext.avx512_vp2intersect) printf(" AVX512_VP2INTERSECT");
	}
	if (info.ext.adx) printf(" ADX");
	if (info.ext.sha) printf(" SHA");
	if (info.ext.fma3) printf(" FMA3");
	if (info.ext.fma4) printf(" FMA4");
	if (info.ext.tbm) printf(" TBM");
	if (info.ext.bmi1) printf(" BMI1");
	if (info.ext.bmi2) printf(" BMI2");
	if (info.ext.waitpkg) printf(" WAITPKG");
	if (info.ext.amx) printf(" AMX");
	if (info.ext.amx_bf16) printf(" +BF16");
	if (info.ext.amx_int8) printf(" +INT8");
	if (info.ext.amx_xtilecfg) printf(" +XTILECFG");
	if (info.ext.amx_xtiledata) printf(" +XTILEDATA");
	if (info.ext.amx_xfd) printf(" +XFD");
	
	//
	// ANCHOR Extra/lone instructions
	//
	
	printf("\nExtra       :");
	if (info.extras.monitor) {
		printf(" MONITOR+MWAIT");
		if (info.extras.mwait_min)
			printf(" +MIN=%u +MAX=%u",
				info.extras.mwait_min, info.extras.mwait_max);
		if (info.extras.monitorx) printf(" MONITORX+MWAITX");
	}
	if (info.extras.pclmulqdq) printf(" PCLMULQDQ");
	if (info.extras.cmpxchg8b) printf(" CMPXCHG8B");
	if (info.extras.cmpxchg16b) printf(" CMPXCHG16B");
	if (info.extras.movbe) printf(" MOVBE");
	if (info.extras.rdrand) printf(" RDRAND");
	if (info.extras.rdseed) printf(" RDSEED");
	if (info.extras.rdmsr) printf(" RDMSR+WRMSR");
	if (info.extras.sysenter) printf(" SYSENTER+SYSEXIT");
	if (info.extras.syscall) printf(" SYSCALL+SYSRET");
	if (info.extras.rdtsc) {
		printf(" RDTSC");
		if (info.extras.rdtsc_deadline)
			printf(" +TSC-Deadline");
		if (info.extras.rdtsc_invariant)
			printf(" +TSC-Invariant");
	}
	if (info.extras.rdtscp) printf(" RDTSCP");
	if (info.extras.rdpid) printf(" RDPID");
	if (info.extras.cmov) {
		printf(" CMOV");
		if (info.ext.fpu) printf(" FCOMI+FCMOV");
	}
	if (info.extras.lzcnt) printf(" LZCNT");
	if (info.extras.popcnt) printf(" POPCNT");
	if (info.extras.xsave) printf(" XSAVE+XRSTOR");
	if (info.extras.osxsave) printf(" XSETBV+XGETBV");
	if (info.extras.fxsr) printf(" FXSAVE+FXRSTOR");
	if (info.extras.pconfig) printf(" PCONFIG");
	if (info.extras.cldemote) printf(" CLDEMOTE");
	if (info.extras.movdiri) printf(" MOVDIRI");
	if (info.extras.movdir64b) printf(" MOVDIR64B");
	if (info.extras.enqcmd) printf(" ENQCMD");
	if (info.extras.skinit) printf(" SKINIT+STGI");
	if (info.extras.serialize) printf(" SERIALIZE");
	
	//
	// ANCHOR Vendor specific technologies
	//
	
	printf("\nTechnologies:");
	
	switch (info.vendor_id) {
	case Vendor.Intel:
		if (info.tech.eist) printf(" EIST");
		if (info.tech.turboboost)
			printf(info.tech.turboboost30 ?
				" TurboBoot-3.0" : " TurboBoost");
		if (info.mem.tsx) {
			printf(" TSX");
			if (info.mem.hle)
				printf(" +HLE");
			if (info.mem.rtm)
				printf(" +RTM");
			if (info.mem.tsxldtrk)
				printf(" +TSXLDTRK");
		}
		if (info.tech.smx) printf(" Intel-TXT/SMX");
		if (info.tech.sgx) printf(" SGX");
		break;
	case Vendor.AMD:
		if (info.tech.turboboost) printf(" Core-Performance-Boost");
		break;
	default:
	}
	if (info.tech.htt) printf(" HTT");
	
	//
	// ANCHOR Cache information
	//
	
	printf("\nCache       :");
	if (info.cache.clflush)
		printf(" CLFLUSH=%uB", info.cache.clflush_linesize << 3);
	if (info.cache.clflushopt) printf(" CLFLUSHOPT");
	if (info.cache.cnxt_id) printf(" CNXT_ID");
	if (info.cache.ss) printf(" SS");
	if (info.cache.prefetchw) printf(" PREFETCHW");
	if (info.cache.invpcid) printf(" INVPCID");
	if (info.cache.wbnoinvd) printf(" WBNOINVD");
	
	for (uint i; i < info.cache.levels && i < DDCPUID_CACHE_MAX; ++i) {
		CACHEINFO *cache = &info.cache.level[i];
		char c = 'K';
		if (cache.size >= 1024) {
			cache.size >>= 10;
			c = 'M';
		}
		printf("\n\tL%u-%c: %ux %4u %ciB, %u ways, %u parts, %u B, %u sets",
			cache.level, cache.type, cache.sharedCores, cache.size, c,
			cache.ways, cache.partitions, cache.linesize, cache.sets
		);
		if (cache.feat & BIT!(0)) printf(" +SI"); // Self Initiative
		if (cache.feat & BIT!(1)) printf(" +FA"); // Fully Associative
		if (cache.feat & BIT!(2)) printf(" +NWBV"); // No Write-Back Validation
		if (cache.feat & BIT!(3)) printf(" +CI"); // Cache Inclusive
		if (cache.feat & BIT!(4)) printf(" +CCI"); // Complex Cache Indexing
	}
	
	printf("\nACPI        :");
	if (info.acpi.available) printf(" ACPI");
	if (info.acpi.apic) printf(" APIC");
	if (info.acpi.x2apic) printf(" x2APIC");
	if (info.acpi.arat) printf(" ARAT");
	if (info.acpi.tm) printf(" TM");
	if (info.acpi.tm2) printf(" TM2");
	printf(" APIC-ID=%u", info.acpi.apic_id);
	if (info.acpi.max_apic_id) printf(" MAX-ID=%u", info.acpi.max_apic_id);
	
	printf("\nVirtual     :");
	if (info.virt.vme) printf(" VME");
	if (info.virt.apivc) printf(" APICv");
	
	// Paravirtualization
	if (info.virt.vendor_id) {
		// See earlier NOTE
		char *virtvendor = cast(char*)info.virt.vendor;
		printf(" HOST=%.12s", virtvendor);
	}
	switch (info.virt.vendor_id) {
	case VirtVendor.VBoxMin:
		if (info.virt.vbox_tsc_freq_khz)
			printf(" TSC_FREQ_KHZ=%u", info.virt.vbox_tsc_freq_khz);
		if (info.virt.vbox_apic_freq_khz)
			printf(" APIC_FREQ_KHZ=%u", info.virt.vbox_apic_freq_khz);
		break;
	case VirtVendor.HyperV:
		printf(" OPENSOURCE=%d VENDOR_ID=%d OS=%d MAJOR=%d MINOR=%d SERVICE=%d BUILD=%d",
			info.virt.hv_guest_opensource,
			info.virt.hv_guest_vendor_id,
			info.virt.hv_guest_os,
			info.virt.hv_guest_major,
			info.virt.hv_guest_minor,
			info.virt.hv_guest_service,
			info.virt.hv_guest_build);
		if (info.virt.hv_base_feat_vp_runtime_msr) printf(" HV_BASE_FEAT_VP_RUNTIME_MSR");
		if (info.virt.hv_base_feat_part_time_ref_count_msr) printf(" HV_BASE_FEAT_PART_TIME_REF_COUNT_MSR");
		if (info.virt.hv_base_feat_basic_synic_msrs) printf(" HV_BASE_FEAT_BASIC_SYNIC_MSRS");
		if (info.virt.hv_base_feat_stimer_msrs) printf(" HV_BASE_FEAT_STIMER_MSRS");
		if (info.virt.hv_base_feat_apic_access_msrs) printf(" HV_BASE_FEAT_APIC_ACCESS_MSRS");
		if (info.virt.hv_base_feat_hypercall_msrs) printf(" HV_BASE_FEAT_HYPERCALL_MSRS");
		if (info.virt.hv_base_feat_vp_id_msr) printf(" HV_BASE_FEAT_VP_ID_MSR");
		if (info.virt.hv_base_feat_virt_sys_reset_msr) printf(" HV_BASE_FEAT_VIRT_SYS_RESET_MSR");
		if (info.virt.hv_base_feat_stat_pages_msr) printf(" HV_BASE_FEAT_STAT_PAGES_MSR");
		if (info.virt.hv_base_feat_part_ref_tsc_msr) printf(" HV_BASE_FEAT_PART_REF_TSC_MSR");
		if (info.virt.hv_base_feat_guest_idle_state_msr) printf(" HV_BASE_FEAT_GUEST_IDLE_STATE_MSR");
		if (info.virt.hv_base_feat_timer_freq_msrs) printf(" HV_BASE_FEAT_TIMER_FREQ_MSRS");
		if (info.virt.hv_base_feat_debug_msrs) printf(" HV_BASE_FEAT_DEBUG_MSRS");
		if (info.virt.hv_part_flags_create_part) printf(" HV_PART_FLAGS_CREATE_PART");
		if (info.virt.hv_part_flags_access_part_id) printf(" HV_PART_FLAGS_ACCESS_PART_ID");
		if (info.virt.hv_part_flags_access_memory_pool) printf(" HV_PART_FLAGS_ACCESS_MEMORY_POOL");
		if (info.virt.hv_part_flags_adjust_msg_buffers) printf(" HV_PART_FLAGS_ADJUST_MSG_BUFFERS");
		if (info.virt.hv_part_flags_post_msgs) printf(" HV_PART_FLAGS_POST_MSGS");
		if (info.virt.hv_part_flags_signal_events) printf(" HV_PART_FLAGS_SIGNAL_EVENTS");
		if (info.virt.hv_part_flags_create_port) printf(" HV_PART_FLAGS_CREATE_PORT");
		if (info.virt.hv_part_flags_connect_port) printf(" HV_PART_FLAGS_CONNECT_PORT");
		if (info.virt.hv_part_flags_access_stats) printf(" HV_PART_FLAGS_ACCESS_STATS");
		if (info.virt.hv_part_flags_debugging) printf(" HV_PART_FLAGS_DEBUGGING");
		if (info.virt.hv_part_flags_cpu_mgmt) printf(" HV_PART_FLAGS_CPU_MGMT");
		if (info.virt.hv_part_flags_cpu_profiler) printf(" HV_PART_FLAGS_CPU_PROFILER");
		if (info.virt.hv_part_flags_expanded_stack_walk) printf(" HV_PART_FLAGS_EXPANDED_STACK_WALK");
		if (info.virt.hv_part_flags_access_vsm) printf(" HV_PART_FLAGS_ACCESS_VSM");
		if (info.virt.hv_part_flags_access_vp_regs) printf(" HV_PART_FLAGS_ACCESS_VP_REGS");
		if (info.virt.hv_part_flags_extended_hypercalls) printf(" HV_PART_FLAGS_EXTENDED_HYPERCALLS");
		if (info.virt.hv_part_flags_start_vp) printf(" HV_PART_FLAGS_START_VP");
		if (info.virt.hv_pm_max_cpu_power_state_c0) printf(" HV_PM_MAX_CPU_POWER_STATE_C0");
		if (info.virt.hv_pm_max_cpu_power_state_c1) printf(" HV_PM_MAX_CPU_POWER_STATE_C1");
		if (info.virt.hv_pm_max_cpu_power_state_c2) printf(" HV_PM_MAX_CPU_POWER_STATE_C2");
		if (info.virt.hv_pm_max_cpu_power_state_c3) printf(" HV_PM_MAX_CPU_POWER_STATE_C3");
		if (info.virt.hv_pm_hpet_reqd_for_c3) printf(" HV_PM_HPET_REQD_FOR_C3");
		if (info.virt.hv_misc_feat_mwait) printf(" HV_MISC_FEAT_MWAIT");
		if (info.virt.hv_misc_feat_guest_debugging) printf(" HV_MISC_FEAT_GUEST_DEBUGGING");
		if (info.virt.hv_misc_feat_perf_mon) printf(" HV_MISC_FEAT_PERF_MON");
		if (info.virt.hv_misc_feat_pcpu_dyn_part_event) printf(" HV_MISC_FEAT_PCPU_DYN_PART_EVENT");
		if (info.virt.hv_misc_feat_xmm_hypercall_input) printf(" HV_MISC_FEAT_XMM_HYPERCALL_INPUT");
		if (info.virt.hv_misc_feat_guest_idle_state) printf(" HV_MISC_FEAT_GUEST_IDLE_STATE");
		if (info.virt.hv_misc_feat_hypervisor_sleep_state) printf(" HV_MISC_FEAT_HYPERVISOR_SLEEP_STATE");
		if (info.virt.hv_misc_feat_query_numa_distance) printf(" HV_MISC_FEAT_QUERY_NUMA_DISTANCE");
		if (info.virt.hv_misc_feat_timer_freq) printf(" HV_MISC_FEAT_TIMER_FREQ");
		if (info.virt.hv_misc_feat_inject_synmc_xcpt) printf(" HV_MISC_FEAT_INJECT_SYNMC_XCPT");
		if (info.virt.hv_misc_feat_guest_crash_msrs) printf(" HV_MISC_FEAT_GUEST_CRASH_MSRS");
		if (info.virt.hv_misc_feat_debug_msrs) printf(" HV_MISC_FEAT_DEBUG_MSRS");
		if (info.virt.hv_misc_feat_npiep1) printf(" HV_MISC_FEAT_NPIEP1");
		if (info.virt.hv_misc_feat_disable_hypervisor) printf(" HV_MISC_FEAT_DISABLE_HYPERVISOR");
		if (info.virt.hv_misc_feat_ext_gva_range_for_flush_va_list) printf(" HV_MISC_FEAT_EXT_GVA_RANGE_FOR_FLUSH_VA_LIST");
		if (info.virt.hv_misc_feat_hypercall_output_xmm) printf(" HV_MISC_FEAT_HYPERCALL_OUTPUT_XMM");
		if (info.virt.hv_misc_feat_sint_polling_mode) printf(" HV_MISC_FEAT_SINT_POLLING_MODE");
		if (info.virt.hv_misc_feat_hypercall_msr_lock) printf(" HV_MISC_FEAT_HYPERCALL_MSR_LOCK");
		if (info.virt.hv_misc_feat_use_direct_synth_msrs) printf(" HV_MISC_FEAT_USE_DIRECT_SYNTH_MSRS");
		if (info.virt.hv_hint_hypercall_for_process_switch) printf(" HV_HINT_HYPERCALL_FOR_PROCESS_SWITCH");
		if (info.virt.hv_hint_hypercall_for_tlb_flush) printf(" HV_HINT_HYPERCALL_FOR_TLB_FLUSH");
		if (info.virt.hv_hint_hypercall_for_tlb_shootdown) printf(" HV_HINT_HYPERCALL_FOR_TLB_SHOOTDOWN");
		if (info.virt.hv_hint_msr_for_apic_access) printf(" HV_HINT_MSR_FOR_APIC_ACCESS");
		if (info.virt.hv_hint_msr_for_sys_reset) printf(" HV_HINT_MSR_FOR_SYS_RESET");
		if (info.virt.hv_hint_relax_time_checks) printf(" HV_HINT_RELAX_TIME_CHECKS");
		if (info.virt.hv_hint_dma_remapping) printf(" HV_HINT_DMA_REMAPPING");
		if (info.virt.hv_hint_interrupt_remapping) printf(" HV_HINT_INTERRUPT_REMAPPING");
		if (info.virt.hv_hint_x2apic_msrs) printf(" HV_HINT_X2APIC_MSRS");
		if (info.virt.hv_hint_deprecate_auto_eoi) printf(" HV_HINT_DEPRECATE_AUTO_EOI");
		if (info.virt.hv_hint_synth_cluster_ipi_hypercall) printf(" HV_HINT_SYNTH_CLUSTER_IPI_HYPERCALL");
		if (info.virt.hv_hint_ex_proc_masks_interface) printf(" HV_HINT_EX_PROC_MASKS_INTERFACE");
		if (info.virt.hv_hint_nested_hyperv) printf(" HV_HINT_NESTED_HYPERV");
		if (info.virt.hv_hint_int_for_mbec_syscalls) printf(" HV_HINT_INT_FOR_MBEC_SYSCALLS");
		if (info.virt.hv_hint_nested_enlightened_vmcs_interface) printf(" HV_HINT_NESTED_ENLIGHTENED_VMCS_INTERFACE");
		if (info.virt.hv_host_feat_avic) printf(" HV_HOST_FEAT_AVIC");
		if (info.virt.hv_host_feat_msr_bitmap) printf(" HV_HOST_FEAT_MSR_BITMAP");
		if (info.virt.hv_host_feat_perf_counter) printf(" HV_HOST_FEAT_PERF_COUNTER");
		if (info.virt.hv_host_feat_nested_paging) printf(" HV_HOST_FEAT_NESTED_PAGING");
		if (info.virt.hv_host_feat_dma_remapping) printf(" HV_HOST_FEAT_DMA_REMAPPING");
		if (info.virt.hv_host_feat_interrupt_remapping) printf(" HV_HOST_FEAT_INTERRUPT_REMAPPING");
		if (info.virt.hv_host_feat_mem_patrol_scrubber) printf(" HV_HOST_FEAT_MEM_PATROL_SCRUBBER");
		if (info.virt.hv_host_feat_dma_prot_in_use) printf(" HV_HOST_FEAT_DMA_PROT_IN_USE");
		if (info.virt.hv_host_feat_hpet_requested) printf(" HV_HOST_FEAT_HPET_REQUESTED");
		if (info.virt.hv_host_feat_stimer_volatile) printf(" HV_HOST_FEAT_STIMER_VOLATILE");
		break;
	case VirtVendor.KVM:
		if (info.virt.kvm_feature_clocksource) printf(" KVM_FEATURE_CLOCKSOURCE");
		if (info.virt.kvm_feature_nop_io_delay) printf(" KVM_FEATURE_NOP_IO_DELAY");
		if (info.virt.kvm_feature_mmu_op) printf(" KVM_FEATURE_MMU_OP");
		if (info.virt.kvm_feature_clocksource2) printf(" KVM_FEATURE_CLOCKSOURCE2");
		if (info.virt.kvm_feature_async_pf) printf(" KVM_FEATURE_ASYNC_PF");
		if (info.virt.kvm_feature_steal_time) printf(" KVM_FEATURE_STEAL_TIME");
		if (info.virt.kvm_feature_pv_eoi) printf(" KVM_FEATURE_PV_EOI");
		if (info.virt.kvm_feature_pv_unhault) printf(" KVM_FEATURE_PV_UNHAULT");
		if (info.virt.kvm_feature_pv_tlb_flush) printf(" KVM_FEATURE_PV_TLB_FLUSH");
		if (info.virt.kvm_feature_async_pf_vmexit) printf(" KVM_FEATURE_ASYNC_PF_VMEXIT");
		if (info.virt.kvm_feature_pv_send_ipi) printf(" KVM_FEATURE_PV_SEND_IPI");
		if (info.virt.kvm_feature_pv_poll_control) printf(" KVM_FEATURE_PV_POLL_CONTROL");
		if (info.virt.kvm_feature_pv_sched_yield) printf(" KVM_FEATURE_PV_SCHED_YIELD");
		if (info.virt.kvm_feature_clocsource_stable_bit) printf(" KVM_FEATURE_CLOCSOURCE_STABLE_BIT");
		if (info.virt.kvm_hint_realtime) printf(" KVM_HINTS_REALTIME");
		break;
	default:
	}
	
	printf("\nMemory      :");
	if (info.mem.phys_bits) printf(" P-Bits=%u", info.mem.phys_bits);
	if (info.mem.line_bits) printf(" L-Bits=%u", info.mem.line_bits);
	if (info.mem.pae) printf(" PAE");
	if (info.mem.pse) printf(" PSE");
	if (info.mem.pse_36) printf(" PSE-36");
	if (info.mem.page1gb) printf(" Page1GB");
	if (info.mem.nx)
		switch (info.vendor_id) {
		case Vendor.Intel: printf(" Intel-XD/NX"); break;
		case Vendor.AMD: printf(" AMD-EVP/NX"); break;
		default: printf(" NX");
		}
	if (info.mem.dca) printf(" DCA");
	if (info.mem.pat) printf(" PAT");
	if (info.mem.mtrr) printf(" MTRR");
	if (info.mem.pge) printf(" PGE");
	if (info.mem.smep) printf(" SMEP");
	if (info.mem.smap) printf(" SMAP");
	if (info.mem.pku) printf(" PKU");
	if (info.mem._5pl) printf(" 5PL");
	if (info.mem.fsrepmov) printf(" FSRM");
	if (info.mem.lam) printf(" LAM");
	
	printf("\nDebugging   :");
	if (info.dbg.mca) printf(" MCA");
	if (info.dbg.mce) printf(" MCE");
	if (info.dbg.de) printf(" DE");
	if (info.dbg.ds) printf(" DS");
	if (info.dbg.ds_cpl) printf(" DS-CPL");
	if (info.dbg.dtes64) printf(" DTES64");
	if (info.dbg.pdcm) printf(" PDCM");
	if (info.dbg.sdbg) printf(" SDBG");
	if (info.dbg.pbe) printf(" PBE");
	
	printf("\nSecurity    :");
	if (info.sec.ia32_arch_capabilities) printf(" IA32_ARCH_CAPABILITIES");
	if (info.sec.ibpb) printf(" IBPB");
	if (info.sec.ibrs) printf(" IBRS");
	if (info.sec.ibrs_on) printf(" IBRS_ON");	// AMD
	if (info.sec.ibrs_pref) printf(" IBRS_PREF");	// AMD
	if (info.sec.stibp) printf(" STIBP");
	if (info.sec.stibp_on) printf(" STIBP_ON");	// AMD
	if (info.sec.ssbd) printf(" SSBD");
	if (info.sec.l1d_flush) printf(" L1D_FLUSH");	// Intel
	if (info.sec.md_clear) printf(" MD_CLEAR");	// Intel
	if (info.sec.cet_ibt) printf(" CET_IBT");	// Intel
	if (info.sec.cet_ss) printf(" CET_SS");	// Intel
	
	printf("\nMisc.       : HLeaf=0x%x HVLeaf=0x%x HELeaf=0x%x Type=%s Index=%u",
		info.max_leaf, info.max_virt_leaf, info.max_ext_leaf,
		info.type_string, info.brand_index);
	if (info.misc.xtpr) printf(" xTPR");
	if (info.misc.psn) printf(" PSN");
	if (info.misc.pcid) printf(" PCID");
	if (info.misc.fsgsbase) printf(" FSGSBASE");
	if (info.misc.uintr) printf(" UINTR");
	
	putchar('\n');
	
	return 0;
}
