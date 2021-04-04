/**
 * Program entry point.
 *
 * NOTE: printf is mainly used for two reasons. First, fputs with stdout
 *       crashes on Windows. Secondly, line buffering.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: See LICENSE
 * License: MIT
 */
module main;

import ddcpuid;

private:
@system:
extern (C):
__gshared:

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
	MAX_VLEAF	= 0x4000_0010, /// Maximum virt leaf override
	MAX_ELEAF	= 0x8000_0020, /// Maximum extended leaf override
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
	"  -o    Override maximum leaves to 20h, 4000_0010h, and 8000_0020h\n"~
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
				puts(DDCPUID_VERSION); return 0;
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

	if (opt_override == false) {
		getLeaves(info);
	} else {
		info.max_leaf = MAX_LEAF;
		info.max_virt_leaf = MAX_VLEAF;
		info.max_ext_leaf = MAX_ELEAF;
	}
	
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
	
	getVendor(info);
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
		printf("\n\tL%u-%c: %u %ciB\tx %u, %u ways, %u parts, %u B, %u sets",
			ca.level, ca.type, ca.size, c, ca.sharedCores,
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
	if (info.apivc) printf(" APICv");
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
		info.type_string, info.brand_index);
	if (info.xtpr) printf(" xTPR");
	if (info.psn) printf(" PSN");
	if (info.pcid) printf(" PCID");
	if (info.ia32_arch_capabilities) printf(" IA32_ARCH_CAPABILITIES");
	if (info.fsgsbase) printf(" FSGSBASE");
	if (info.uintr) printf(" UINTR");

	putchar('\n');

	return 0;
}
