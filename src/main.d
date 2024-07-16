/**
 * Program entry point.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: © 2016-2023 dd86k
 * License: MIT
 */
module main;

import core.stdc.stdio : printf; // sscanf
import core.stdc.string : strcmp, strtok, strncpy;
import ddcpuid;

// NOTE: printf is used for a few reasons:
//       - fputs with stdout crashes on Windows due to improper externs.
//       - line buffering is used by default, which can be an advantage.

// NOTE: Avoid using floats to make this run proper on the i486SX

private:
@system:
extern (C):

// because wrong extern
int putchar(int);
// because wrong extern
int puts(scope const char* s);
// because GDC's pragma(scanf) whinning about %i and int*
int sscanf(scope const char* s, scope const char* format, scope ...);

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
	MAX_LEAF	= 0x40, /// Maximum leaf override
	MAX_VLEAF	= 0x4000_0000 + MAX_LEAF, /// Maximum virt leaf override
	MAX_ELEAF	= 0x8000_0000 + MAX_LEAF, /// Maximum extended leaf override
}

/// Command-line options
struct options_t {
	int maxLevel;	/// Maximum leaf for -r (-S)
	int maxSubLevel;	/// Maximum subleaf for -r (-s)
	bool hasLevel;	/// If -S has been used
	bool override_;	/// Override leaves (-o)
	bool baseline;	/// Get x86-64 optimization feature level or baseline for processor
	bool platform;	/// Get x86-64 optimization feature level or baseline for platform
	bool list;	/// Get processor details in a list
	bool raw;	/// Raw CPUID value table (-r/--raw)
	bool rawInput;	/// Raw values were supplied, avoid fetching
}

// One day I'll make this italics.
immutable const(char) *secret = r"
                            ############
                     ######################
                ###########################
            #################
         ############              #######
       #########     _      _     ### R #####
     #######        | |    | |     ###########
   #######        __| |  __| |          ########
  #####          / _  | / _  |             ######
 #####          | (_| || (_| |               #####
####             \____| \____|                ####
###                             _              ###
###      [_]            [_]    | |              ##
##        _  _ __   ___  _   __| | ____        ###
###      | || '_  \/ __/| | / _  |/ __ \       ###
###      | || | | |\__ \| || (_| ||  __/      ####
 ###     |_||_| |_||___/|_| \____|\____|    #####
 #####                                     #####
  ######                               ######
    #######                          #######
      #########                ###########
        ###############################
            ######################
";

/// print help page
void clih() {
	puts(
	"x86/AMD64 CPUID information tool\n"~
	"\n"~
	"USAGE\n"~
	" ddcpuid [OPTIONS...]\n"~
	"\n"~
	"OPTIONS\n"~
	" -b, --baseline           Print the processor's feature level\n"~
	" -l, --list               Show all processor information in a list\n"~
	" -o                       Override max leaves to 0x40 for each sections\n"~
	" -p, --platform           Print the processor's feature level, context-aware\n"~
	" -r, --raw [leaf,[sub]]   Display CPUID values\n"~
	"\n"~
	"PAGES\n"~
	" -h, --help   Print this help screen and quit\n"~
	" --version    Print version screen and quit\n"~
	" --ver        Print only version string and quit\n"
	);
}

/// print version page
void cliv() {
	puts(
	"ddcpuid-"~DDCPUID_PLATFORM~" "~DDCPUID_VERSION~" (built: "~__TIMESTAMP__~")\n"~
	"Copyright (c) 2016-2023 dd86k <dd@dax.moe>\n"~
	"License: MIT License <http://opensource.org/licenses/MIT>\n"~
	"Homepage: <https://github.com/dd86k/ddcpuid>\n"~
	"Compiler: "~__VENDOR__~" "~CVER!(__VERSION__)
	);
}

void outcpuid(uint leaf, uint sub) {
	REGISTERS regs = void;
	ddcpuid_id(regs, leaf, sub);
	printcpuid(regs, leaf, sub);
}

/// Print cpuid table entry into stdout.
/// Params:
/// 	leaf = EAX input
/// 	sub = ECX input
pragma(inline, false) // ldc optimization bug
void printcpuid(ref REGISTERS regs, uint leaf, uint sub) {
	with (regs)
	printf("| %8x | %8x | %8x | %8x | %8x | %8x |\n",
		leaf, sub, eax, ebx, ecx, edx);
}

deprecated
char adjust(ref float size) {
	version (Trace) trace("size=%u", size);
	if (size >= 1024.0) {
		size /= 1024;
		return 'M';
	}
	return 'K';
}

struct cachesize_t {
	uint dec;
	uint rem;
	char prefix;
}
cachesize_t cacheSize(uint base) {
	cachesize_t s = void;
	
	if (base >= 1024) {
		uint rem = base % 1024;
		s.prefix = 'M';
		s.dec = base / 1024;
		s.rem = (rem * 10) / 1024;
		return s;
	}
	
	s.prefix = 'K';
	s.dec = base;
	s.rem = 0;
	return s;
}
unittest {
	cachesize_t c = cacheSize(16);
	assert(c.prefix == 'K');
	assert(c.dec == 16);
	assert(c.rem == 0);
	
	c = cacheSize(1024);
	assert(c.prefix == 'M');
	assert(c.dec == 1);
	assert(c.rem == 0);
	
	c = cacheSize(1024 + 512);
	assert(c.prefix == 'M');
	assert(c.dec == 1);
	assert(c.rem == 5);
}

// Adjust binary size (IEC)
const(char)* adjustBits(ref uint size, int bitpos) {
	version (Trace) trace("size=%u bit=%d", size, bitpos);
	static immutable const(char)*[8] SIZES = [
		"B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB"
	];
	size_t s;
	while (bitpos >= 10) { bitpos -= 10; ++s; }
	size = 1 << bitpos;
	return SIZES[s];
}
//TODO: Make DUB to include this main, somehow
/// adjustBits
/*
@system unittest {
	float size;
	assert(adjustBits(size, 0) == "B");
	assert(size == 1);
	assert(adjustBits(size, 1) == "B");
	assert(size == 2);
	assert(adjustBits(size, 10) == "KiB");
	assert(size == 1);
	assert(adjustBits(size, 11) == "KiB");
	assert(size == 2);
	assert(adjustBits(size, 20) == "MiB");
	assert(size == 1);
	assert(adjustBits(size, 36) == "GiB");
	assert(size == 64);
	assert(adjustBits(size, 48) == "TiB");
	assert(size == 256);
}
*/

const(char)* platform(ref CPUINFO cpu) {
	if (cpu.x86_64) return "x86-64";
	switch (cpu.family) {
	case 3:  return "i386"; // 80386
	case 4:  return "i486"; // 80486
	case 5:  return "i586"; // Pentium / MMX
	default: return "i686"; // Pentium Pro / II
	}
}

void printLegacy(ref CPUINFO cpu) {
	if (cpu.fpu) {
		printf(" x87/fpu");
		if (cpu.f16c) printf(" +f16c");
	}
	if (cpu.mmx) {
		printf(" mmx");
		if (cpu.mmxExtended) printf(" extmmx");
	}
	if (cpu._3DNow) {
		printf(" 3dnow!");
		if (cpu._3DNowExtended) printf(" ext3dnow!");
	}
}
void printFeatures(ref CPUINFO cpu) {
	switch (cpu.vendor.id) with (Vendor) {
	case Intel:
		if (cpu.eist) printf(" eist");
		if (cpu.turboboost) {
			printf(" turboboost");
			if (cpu.turboboost30) printf("-3.0");
		}
		if (cpu.tsx) {
			printf(" tsx");
			if (cpu.hle)
				printf(" +hle");
			if (cpu.rtm)
				printf(" +rtm");
			if (cpu.tsxldtrk)
				printf(" +tsxldtrk");
		}
		if (cpu.smx) printf(" intel-txt/smx");
		if (cpu.sgx) {
			// NOTE: SGX system configuration
			//       "enabled" in BIOS: only CPUID.7h.EBX[2]
			//       "user controlled" in BIOS: SGX1/SGX2/size bits
			if (cpu.sgx1 || cpu.sgx2) {
				if (cpu.sgx1) printf(" sgx1");
				if (cpu.sgx2) printf(" sgx2");
			} else printf(" sgx"); // Fallback per-say
			if (cpu.sgxMaxSize) {
				uint s32 = void, s64 = void;
				const(char) *m32 = adjustBits(s32, cpu.sgxMaxSize);
				const(char) *m64 = adjustBits(s64, cpu.sgxMaxSize64);
				printf(" +maxsize=%u%s +maxsize64=%u%s", s32, m32, s64, m64);
			}
		}
		break;
	case AMD:
		if (cpu.turboboost) printf(" core-performance-boost");
		break;
	default:
	}
	if (cpu.htt) printf(" htt");
}
void printSSE(ref CPUINFO cpu) {
	printf(" sse");
	if (cpu.sse2) printf(" sse2");
	if (cpu.sse3) printf(" sse3");
	if (cpu.ssse3) printf(" ssse3");
	if (cpu.sse41) printf(" sse4.1");
	if (cpu.sse42) printf(" sse4.2");
	if (cpu.sse4a) printf(" sse4a");
}
void printAVX(ref CPUINFO cpu) {
	printf(" avx");
	if (cpu.avx2) printf(" avx2");
	if (cpu.avx512f) {
		printf(" avx512f");
		if (cpu.avx512er) printf(" +er");
		if (cpu.avx512pf) printf(" +pf");
		if (cpu.avx512cd) printf(" +cd");
		if (cpu.avx512dq) printf(" +dq");
		if (cpu.avx512bw) printf(" +bw");
		if (cpu.avx512vl) printf(" +vl");
		if (cpu.avx512_ifma) printf(" +ifma");
		if (cpu.avx512_vbmi) printf(" +vbmi");
		if (cpu.avx512_4vnniw) printf(" +4vnniw");
		if (cpu.avx512_4fmaps) printf(" +4fmaps");
		if (cpu.avx512_vbmi2) printf(" +vbmi2");
		if (cpu.avx512_gfni) printf(" +gfni");
		if (cpu.avx512_vaes) printf(" +vaes");
		if (cpu.avx512_vnni) printf(" +vnni");
		if (cpu.avx512_bitalg) printf(" +bitalg");
		if (cpu.avx512_bf16) printf(" +bf16");
		if (cpu.avx512_vp2intersect) printf(" +vp2intersect");
	}
	if (cpu.xop) printf(" xop");
}
void printFMA(ref CPUINFO cpu) {
	if (cpu.fma)  printf(" fma");
	if (cpu.fma4) printf(" fma4");
}
void printAMX(ref CPUINFO cpu) {
	printf(" amx");
	if (cpu.amx_bf16) printf(" +bf16");
	if (cpu.amx_int8) printf(" +int8");
	if (cpu.amx_xtilecfg) printf(" +xtilecfg");
	if (cpu.amx_xtiledata) printf(" +xtiledata");
	if (cpu.amx_xfd) printf(" +xfd");
}
void printOthers(ref CPUINFO cpu) {
	const(char) *tstr = void;
	if (cpu.x86_64) {
		switch (cpu.vendor.id) with (Vendor) {
		case Intel:	tstr = " intel64/x86-64"; break;
		case AMD:	tstr = " amd64/x86-64"; break;
		default:	tstr = " x86-64";
		}
		printf(tstr);
		if (cpu.lahf64)
			printf(" +lahf64");
	}
	if (cpu.virtualization)
		switch (cpu.vendor.id) with (Vendor) {
		case Intel: printf(" vt-x/vmx"); break;
		case AMD: // SVM
			printf(" amd-v/vmx");
			if (cpu.virtVersion)
				printf(" +svm=v%u", cpu.virtVersion);
			break;
		case VIA: printf(" via-vt/vmx"); break;
		default:  printf(" vmx");
		}
	if (cpu.aes_ni)	printf(" aes-ni");
	if (cpu.adx)	printf(" adx");
	if (cpu.sha)	printf(" sha");
	if (cpu.tbm)	printf(" tbm");
	if (cpu.bmi1)	printf(" bmi1");
	if (cpu.bmi2)	printf(" bmi2");
	if (cpu.waitpkg)	printf(" waitpkg");
}
void printSecurity(ref CPUINFO cpu) {
	if (cpu.ibpb)	printf(" ibpb");
	if (cpu.ibrs)	printf(" ibrs");
	if (cpu.ibrsAlwaysOn)	printf(" ibrs_on");	// AMD
	if (cpu.ibrsPreferred)	printf(" ibrs_pref");	// AMD
	if (cpu.stibp)	printf(" stibp");
	if (cpu.stibpAlwaysOn)	printf(" stibp_on");	// AMD
	if (cpu.ssbd)	printf(" ssbd");
	if (cpu.l1dFlush)	printf(" l1d_flush");	// Intel
	if (cpu.md_clear)	printf(" md_clear");	// Intel
	if (cpu.cetIbt)	printf(" cet_ibt");	// Intel
	if (cpu.cetSs)	printf(" cet_ss");	// Intel
}
void printCacheFeats(ushort feats) {
	if (feats == 0) return;
	putchar(',');
	if (feats & BIT!(0)) printf(" si");   // Self Initiative
	if (feats & BIT!(1)) printf(" fa");   // Fully Associative
	if (feats & BIT!(2)) printf(" nwbv"); // No Write-Back Validation
	if (feats & BIT!(3)) printf(" ci");   // Cache Inclusive
	if (feats & BIT!(4)) printf(" cci");  // Complex Cache Indexing
}

int optionRaw(ref options_t options, const(char) *arg) {
	enum MAX = 16;
	char[MAX] buf = void;
	
	version (Trace) trace("arg=%s", arg);
	
	options.raw = true;
	if (arg == null) return 0;
	
	options.rawInput = true;
	strncpy(buf.ptr, arg, MAX);
	arg = strtok(buf.ptr, ",");
	version (Trace) trace("token=%s", arg);
	if (arg == null) {
		puts("Empty value for leaf");
		return 1;
	}
	sscanf(arg, "%i", &options.maxLevel);
	arg = strtok(null, ",");
	version (Trace) trace("token=%s", arg);
	if (arg)
		sscanf(arg, "%i", &options.maxSubLevel);
	return 0;
}

version (unittest) {} else
int main(int argc, const(char) **argv) {
	options_t options; /// Command-line options
	int error = void;
	
	const(char) *arg = void;	/// Temp argument holder
	const(char) *val = void;	/// Temp value holder
	for (int argi = 1; argi < argc; ++argi) {
		if (argv[argi][1] == '-') { // Long arguments
			arg = argv[argi] + 2;
			if (strcmp(arg, "raw") == 0) {
				val = argi + 1 >= argc ? null : argv[argi + 1];
				if (val && val[0] == '-') val = null;
				error = optionRaw(options, val);
				if (error) return error;
				continue;
			}
			if (strcmp(arg, "platform") == 0) {
				options.platform = true;
				continue;
			}
			if (strcmp(arg, "baseline") == 0) {
				options.baseline = true;
				continue;
			}
			if (strcmp(arg, "list") == 0) {
				options.list = true;
				continue;
			}
			if (strcmp(arg, "version") == 0) {
				cliv;
				return 0;
			}
			if (strcmp(arg, "ver") == 0) {
				puts(DDCPUID_VERSION);
				return 0;
			}
			if (strcmp(arg, "help") == 0) {
				clih;
				return 0;
			}
			if (strcmp(arg, "inside") == 0) {
				puts(secret);
				return 0;
			}
			printf("Unknown parameter: '%s'\n", arg);
			return 1;
		} else if (argv[argi][0] == '-') { // Short arguments
			arg = argv[argi] + 1;
			char o = void;
			while ((o = *arg) != 0) {
				++arg;
				switch (o) {
				case 'l': options.list = true; continue;
				case 'p': options.platform = true; continue;
				case 'b': options.baseline = true; continue;
				case 'o': options.override_ = true; continue;
				case 'r':
					val = argi + 1 >= argc ? null : argv[argi + 1];
					if (val && val[0] == '-') val = null;
					error = optionRaw(options, val);
					if (error) return error;
					continue;
				case 'h': clih; return 0;
				case 'V': cliv; return 0;
				default:
					printf("Unknown parameter: '-%c'\n", o);
					return 1;
				}
			} // while
		} // else if
	} // for
	
	if (options.raw) {
		uint l = void, s = void;
		
		puts(
		"| Leaf     | Sub-leaf | EAX      | EBX      | ECX      | EDX      |\n"~
		"|----------|----------|----------|----------|----------|----------|"
		);
		
		if (options.rawInput) {
			outcpuid(options.maxLevel, options.maxSubLevel);
			return 0;
		}
		
		REGISTERS regs = void;
		for (uint base; base <= 0xf; ++base) {
			uint leaf = base << 28;
			ddcpuid_id(regs, leaf, 0);
			
			// Check bounds (e.g. eax >= 0x4000_0000 && eax < 0x5000_0000)
			if (regs.eax < leaf) continue;
			if (base < 0xf && regs.eax >= leaf + 0x1000_0000) continue;
			
			uint maxleaf = options.override_ ? leaf + MAX_LEAF : regs.eax;
			for (l = leaf; l <= maxleaf; ++l)
				for (s = 0; s <= options.maxSubLevel; ++s)
					outcpuid(l, s);
		}
		
		return 0;
	}
	
	CPUINFO cpu;
	
	if (options.override_) {
		cpu.maxLeaf = MAX_LEAF;
		cpu.maxLeafVirt = MAX_VLEAF;
		cpu.maxLeafExtended = MAX_ELEAF;
	} else {
		ddcpuid_leaves(cpu);
	}
	
	ddcpuid_cpuinfo(cpu);
	
	if (options.baseline) {
		puts(ddcpuid_baseline(cpu));
		return 0;
	}
	if (options.platform) {
		puts(platform(cpu));
		return 0;
	}
	
	// NOTE: .ptr crash with GDC -O3
	//       glibc!__strlen_sse2 (in printf)
	version (GNU) {
		char *vendorstr = cast(char*)cpu.vendor.string_;
		char *brandstr  = cast(char*)cpu.brandString;
	} else {
		char *vendorstr = cpu.vendor.string_.ptr;
		char *brandstr  = cpu.brandString.ptr;
	}
	
	// Brand string left space trimming
	// While very common in Intel, let's also do it for others (in case of)
	while (*brandstr == ' ') ++brandstr;
	
	CACHEINFO *cache = void;	/// Current cache level
	
	//
	// ANCHOR Summary
	//
	
	if (options.list == false) {
		const(char) *s_cores = cpu.physicalCores == 1 ? "core" : "cores";
		const(char) *s_threads = cpu.logicalCores == 1 ? "thread" : "threads";
		with (cpu) printf(
		"Name:        %.12s %.48s\n"~
		"Identifier:  Family 0x%x Model 0x%x Stepping 0x%x\n"~
		"Cores:       %u %s, %u %s\n",
		vendorstr, brandstr,
		family, model, stepping,
		physicalCores, s_cores, logicalCores, s_threads
		);
		
		if (cpu.physicalBits || cpu.linearBits) {
			uint maxPhys = void, maxLine = void;
			const(char) *cphys = adjustBits(maxPhys, cpu.physicalBits);
			const(char) *cline = adjustBits(maxLine, cpu.linearBits);
			with (cpu) printf(
			"Max. Memory: %u %s physical, %u %s virtual\n",
			maxPhys, cphys, maxLine, cline,
			);
		}
		
		with (cpu) printf(
		"Platform:    %s\n"~
		"Baseline:    %s\n"~
		"Features:   ",
			platform(cpu),
			ddcpuid_baseline(cpu)
		);
		
		printFeatures(cpu);
		
		printf("\nExtensions: ");
		printLegacy(cpu);
		printOthers(cpu);
		
		printf("\nSSE:        ");
		if (cpu.sse)
			printSSE(cpu);
		printFMA(cpu);
		putchar('\n');
		
		printf("AVX:        ");
		if (cpu.avx)
			printAVX(cpu);
		putchar('\n');
		
		printf("AMX:        ");
		if (cpu.amx)
			printAMX(cpu);
		putchar('\n');
		
		printf("Mitigations:");
		printSecurity(cpu);
		putchar('\n');
		
		if (cpu.maxLeafVirt >= 0x4000_0000) {
			const(char) *vv = void;
			switch (cpu.virtVendor.id) with (VirtVendor) {
			case KVM:        vv = "KVM"; break;
			case HyperV:     vv = "Hyper-V"; break;
			case VBoxHyperV: vv = "VirtualBox Hyper-V"; break;
			case VBoxMin:    vv = "VirtualBox Minimal"; break;
			default:         vv = "Unknown";
			}
			printf("ParaVirt.:   %s\n", vv);
		}
		
		for (size_t i; i < cpu.cacheLevels; ++i) {
			cache = &cpu.cache[i];
			
			cachesize_t c = cacheSize(cache.size);
			cachesize_t t = cacheSize(cache.size * cache.sharedCores);
			
			with (cache)
			printf("Cache L%u-%c:  %3ux %4u.%02u %ciB, %4u.%02u %ciB total",
				level, type, sharedCores,
				c.dec, c.rem, c.prefix,
				t.dec, t.rem, t.prefix);
			printCacheFeats(cache.features);
			putchar('\n');
		}
		
		return 0;
	}
	
	//
	// ANCHOR Detailed view
	//
	
	with (cpu) printf(
	"Vendor      : %.12s\n"~
	"Brand       : %.48s\n"~
	"Identifier  : 0x%x\n"~
	"Family      : 0x%x\n"~
	"BaseFamily  : 0x%x\n"~
	"ExtFamily   : 0x%x\n"~
	"Model       : 0x%x\n"~
	"BaseModel   : 0x%x\n"~
	"ExtModel    : 0x%x\n"~
	"Stepping    : 0x%x\n"~
	"Cores       : %u\n"~
	"Threads     : %u\n"~
	"Extensions  :",
	vendorstr, brandstr,
	identifier,
	family, familyBase, familyExtended,
	model, modelBase, modelExtended,
	stepping,
	physicalCores, logicalCores
	);
	
	// Extensions
	
	const(char) *tstr = void;
	printLegacy(cpu);
	if (cpu.sse) printSSE(cpu);
	if (cpu.avx) printAVX(cpu);
	printFMA(cpu);
	printOthers(cpu);
	if (cpu.amx) printAMX(cpu);
	
	//
	// ANCHOR Extra/lone instructions
	//
	
	printf("\nExtra       :");
	if (cpu.monitor) {
		printf(" monitor+mwait");
		if (cpu.mwaitMin)
			printf(" +min=%u +max=%u",
				cpu.mwaitMin, cpu.mwaitMax);
		if (cpu.monitorx) printf(" monitorx+mwaitx");
	}
	if (cpu.pclmulqdq) printf(" pclmulqdq");
	if (cpu.cmpxchg8b) printf(" cmpxchg8b");
	if (cpu.cmpxchg16b) printf(" cmpxchg16b");
	if (cpu.movbe) printf(" movbe");
	if (cpu.rdrand) printf(" rdrand");
	if (cpu.rdseed) printf(" rdseed");
	if (cpu.rdmsr) printf(" rdmsr+wrmsr");
	if (cpu.sysenter) printf(" sysenter+sysexit");
	if (cpu.syscall) printf(" syscall+sysret");
	if (cpu.rdtsc) {
		printf(" rdtsc");
		if (cpu.rdtscDeadline)
			printf(" +tsc-deadline");
		if (cpu.rdtscInvariant)
			printf(" +tsc-invariant");
	}
	if (cpu.rdtscp) printf(" rdtscp");
	if (cpu.rdpid) printf(" rdpid");
	if (cpu.cmov) {
		printf(" cmov");
		if (cpu.fpu) printf(" fcomi+fcmov");
	}
	if (cpu.lzcnt) printf(" lzcnt");
	if (cpu.popcnt) printf(" popcnt");
	if (cpu.xsave) printf(" xsave+xrstor");
	if (cpu.osxsave) printf(" xsetbv+xgetbv");
	if (cpu.fxsr) printf(" fxsave+fxrstor");
	if (cpu.pconfig) printf(" pconfig");
	if (cpu.cldemote) printf(" cldemote");
	if (cpu.movdiri) printf(" movdiri");
	if (cpu.movdir64b) printf(" movdir64b");
	if (cpu.enqcmd) printf(" enqcmd");
	if (cpu.skinit) printf(" skinit+stgi");
	if (cpu.serialize) printf(" serialize");
	
	//
	// ANCHOR Vendor specific technologies
	//
	
	printf("\nFeatures    :");
	printFeatures(cpu);
	
	//
	// ANCHOR Cache information
	//
	
	printf("\nCache       :");
	if (cpu.clflush)
		printf(" clflush=%uB", cpu.clflushLinesize << 3);
	if (cpu.clflushopt) printf(" clflushopt");
	if (cpu.cnxtId) printf(" cnxt-id");
	if (cpu.ss) printf(" ss");
	if (cpu.prefetchw) printf(" prefetchw");
	if (cpu.invpcid) printf(" invpcid");
	if (cpu.wbnoinvd) printf(" wbnoinvd");
	
	for (uint i; i < cpu.cacheLevels; ++i) {
		cache = &cpu.cache[i];
		printf("\nLevel %u-%c   : %2ux %6u KiB, %u ways, %u parts, %u B, %u sets",
			cache.level, cache.type, cache.sharedCores, cache.size,
			cache.ways, cache.partitions, cache.lineSize, cache.sets
		);
		printCacheFeats(cache.features);
	}
	
	printf("\nSystem      :");
	if (cpu.apci) printf(" acpi");
	if (cpu.apic) printf(" apic");
	if (cpu.x2apic) printf(" x2apic");
	if (cpu.arat) printf(" arat");
	if (cpu.tm) printf(" tm");
	if (cpu.tm2) printf(" tm2");
	printf(" apic-id=%u", cpu.apicId);
	if (cpu.apicMaxId) printf(" max-id=%u", cpu.apicMaxId);
	
	printf("\nVirtual     :");
	if (cpu.vme) printf(" vme");
	if (cpu.apicv) printf(" apicv");
	
	// Paravirtualization
	if (cpu.maxLeafVirt >= 0x4000_0000) {
		if (cpu.virtVendor.id) {
			// See vendor string case
			printf(" host=%.12s", cast(char*)cpu.virtVendor.string_);
		} else {
			printf(" host=(null)");
		}
		switch (cpu.virtVendor.id) with (VirtVendor) {
		case VBoxMin:
			if (cpu.vbox.tsc_freq_khz)
				printf(" tsc_freq_khz=%u", cpu.vbox.tsc_freq_khz);
			if (cpu.vbox.apic_freq_khz)
				printf(" apic_freq_khz=%u", cpu.vbox.apic_freq_khz);
			break;
		case HyperV:
			printf(" opensource=%d vendor_id=%d os=%d major=%d minor=%d service=%d build=%d",
				cpu.hv.guest_opensource,
				cpu.hv.guest_vendor_id,
				cpu.hv.guest_os,
				cpu.hv.guest_major,
				cpu.hv.guest_minor,
				cpu.hv.guest_service,
				cpu.hv.guest_build);
			if (cpu.hv.base_feat_vp_runtime_msr) printf(" hv_base_feat_vp_runtime_msr");
			if (cpu.hv.base_feat_part_time_ref_count_msr) printf(" hv_base_feat_part_time_ref_count_msr");
			if (cpu.hv.base_feat_basic_synic_msrs) printf(" hv_base_feat_basic_synic_msrs");
			if (cpu.hv.base_feat_stimer_msrs) printf(" hv_base_feat_stimer_msrs");
			if (cpu.hv.base_feat_apic_access_msrs) printf(" hv_base_feat_apic_access_msrs");
			if (cpu.hv.base_feat_hypercall_msrs) printf(" hv_base_feat_hypercall_msrs");
			if (cpu.hv.base_feat_vp_id_msr) printf(" hv_base_feat_vp_id_msr");
			if (cpu.hv.base_feat_virt_sys_reset_msr) printf(" hv_base_feat_virt_sys_reset_msr");
			if (cpu.hv.base_feat_stat_pages_msr) printf(" hv_base_feat_stat_pages_msr");
			if (cpu.hv.base_feat_part_ref_tsc_msr) printf(" hv_base_feat_part_ref_tsc_msr");
			if (cpu.hv.base_feat_guest_idle_state_msr) printf(" hv_base_feat_guest_idle_state_msr");
			if (cpu.hv.base_feat_timer_freq_msrs) printf(" hv_base_feat_timer_freq_msrs");
			if (cpu.hv.base_feat_debug_msrs) printf(" hv_base_feat_debug_msrs");
			if (cpu.hv.part_flags_create_part) printf(" hv_part_flags_create_part");
			if (cpu.hv.part_flags_access_part_id) printf(" hv_part_flags_access_part_id");
			if (cpu.hv.part_flags_access_memory_pool) printf(" hv_part_flags_access_memory_pool");
			if (cpu.hv.part_flags_adjust_msg_buffers) printf(" hv_part_flags_adjust_msg_buffers");
			if (cpu.hv.part_flags_post_msgs) printf(" hv_part_flags_post_msgs");
			if (cpu.hv.part_flags_signal_events) printf(" hv_part_flags_signal_events");
			if (cpu.hv.part_flags_create_port) printf(" hv_part_flags_create_port");
			if (cpu.hv.part_flags_connect_port) printf(" hv_part_flags_connect_port");
			if (cpu.hv.part_flags_access_stats) printf(" hv_part_flags_access_stats");
			if (cpu.hv.part_flags_debugging) printf(" hv_part_flags_debugging");
			if (cpu.hv.part_flags_cpu_mgmt) printf(" hv_part_flags_cpu_mgmt");
			if (cpu.hv.part_flags_cpu_profiler) printf(" hv_part_flags_cpu_profiler");
			if (cpu.hv.part_flags_expanded_stack_walk) printf(" hv_part_flags_expanded_stack_walk");
			if (cpu.hv.part_flags_access_vsm) printf(" hv_part_flags_access_vsm");
			if (cpu.hv.part_flags_access_vp_regs) printf(" hv_part_flags_access_vp_regs");
			if (cpu.hv.part_flags_extended_hypercalls) printf(" hv_part_flags_extended_hypercalls");
			if (cpu.hv.part_flags_start_vp) printf(" hv_part_flags_start_vp");
			if (cpu.hv.pm_max_cpu_power_state_c0) printf(" hv_pm_max_cpu_power_state_c0");
			if (cpu.hv.pm_max_cpu_power_state_c1) printf(" hv_pm_max_cpu_power_state_c1");
			if (cpu.hv.pm_max_cpu_power_state_c2) printf(" hv_pm_max_cpu_power_state_c2");
			if (cpu.hv.pm_max_cpu_power_state_c3) printf(" hv_pm_max_cpu_power_state_c3");
			if (cpu.hv.pm_hpet_reqd_for_c3) printf(" hv_pm_hpet_reqd_for_c3");
			if (cpu.hv.misc_feat_mwait) printf(" hv_misc_feat_mwait");
			if (cpu.hv.misc_feat_guest_debugging) printf(" hv_misc_feat_guest_debugging");
			if (cpu.hv.misc_feat_perf_mon) printf(" hv_misc_feat_perf_mon");
			if (cpu.hv.misc_feat_pcpu_dyn_part_event) printf(" hv_misc_feat_pcpu_dyn_part_event");
			if (cpu.hv.misc_feat_xmm_hypercall_input) printf(" hv_misc_feat_xmm_hypercall_input");
			if (cpu.hv.misc_feat_guest_idle_state) printf(" hv_misc_feat_guest_idle_state");
			if (cpu.hv.misc_feat_hypervisor_sleep_state) printf(" hv_misc_feat_hypervisor_sleep_state");
			if (cpu.hv.misc_feat_query_numa_distance) printf(" hv_misc_feat_query_numa_distance");
			if (cpu.hv.misc_feat_timer_freq) printf(" hv_misc_feat_timer_freq");
			if (cpu.hv.misc_feat_inject_synmc_xcpt) printf(" hv_misc_feat_inject_synmc_xcpt");
			if (cpu.hv.misc_feat_guest_crash_msrs) printf(" hv_misc_feat_guest_crash_msrs");
			if (cpu.hv.misc_feat_debug_msrs) printf(" hv_misc_feat_debug_msrs");
			if (cpu.hv.misc_feat_npiep1) printf(" hv_misc_feat_npiep1");
			if (cpu.hv.misc_feat_disable_hypervisor) printf(" hv_misc_feat_disable_hypervisor");
			if (cpu.hv.misc_feat_ext_gva_range_for_flush_va_list) printf(" hv_misc_feat_ext_gva_range_for_flush_va_list");
			if (cpu.hv.misc_feat_hypercall_output_xmm) printf(" hv_misc_feat_hypercall_output_xmm");
			if (cpu.hv.misc_feat_sint_polling_mode) printf(" hv_misc_feat_sint_polling_mode");
			if (cpu.hv.misc_feat_hypercall_msr_lock) printf(" hv_misc_feat_hypercall_msr_lock");
			if (cpu.hv.misc_feat_use_direct_synth_msrs) printf(" hv_misc_feat_use_direct_synth_msrs");
			if (cpu.hv.hint_hypercall_for_process_switch) printf(" hv_hint_hypercall_for_process_switch");
			if (cpu.hv.hint_hypercall_for_tlb_flush) printf(" hv_hint_hypercall_for_tlb_flush");
			if (cpu.hv.hint_hypercall_for_tlb_shootdown) printf(" hv_hint_hypercall_for_tlb_shootdown");
			if (cpu.hv.hint_msr_for_apic_access) printf(" hv_hint_msr_for_apic_access");
			if (cpu.hv.hint_msr_for_sys_reset) printf(" hv_hint_msr_for_sys_reset");
			if (cpu.hv.hint_relax_time_checks) printf(" hv_hint_relax_time_checks");
			if (cpu.hv.hint_dma_remapping) printf(" hv_hint_dma_remapping");
			if (cpu.hv.hint_interrupt_remapping) printf(" hv_hint_interrupt_remapping");
			if (cpu.hv.hint_x2apic_msrs) printf(" hv_hint_x2apic_msrs");
			if (cpu.hv.hint_deprecate_auto_eoi) printf(" hv_hint_deprecate_auto_eoi");
			if (cpu.hv.hint_synth_cluster_ipi_hypercall) printf(" hv_hint_synth_cluster_ipi_hypercall");
			if (cpu.hv.hint_ex_proc_masks_interface) printf(" hv_hint_ex_proc_masks_interface");
			if (cpu.hv.hint_nested_hyperv) printf(" hv_hint_nested_hyperv");
			if (cpu.hv.hint_int_for_mbec_syscalls) printf(" hv_hint_int_for_mbec_syscalls");
			if (cpu.hv.hint_nested_enlightened_vmcs_interface) printf(" hv_hint_nested_enlightened_vmcs_interface");
			if (cpu.hv.host_feat_avic) printf(" hv_host_feat_avic");
			if (cpu.hv.host_feat_msr_bitmap) printf(" hv_host_feat_msr_bitmap");
			if (cpu.hv.host_feat_perf_counter) printf(" hv_host_feat_perf_counter");
			if (cpu.hv.host_feat_nested_paging) printf(" hv_host_feat_nested_paging");
			if (cpu.hv.host_feat_dma_remapping) printf(" hv_host_feat_dma_remapping");
			if (cpu.hv.host_feat_interrupt_remapping) printf(" hv_host_feat_interrupt_remapping");
			if (cpu.hv.host_feat_mem_patrol_scrubber) printf(" hv_host_feat_mem_patrol_scrubber");
			if (cpu.hv.host_feat_dma_prot_in_use) printf(" hv_host_feat_dma_prot_in_use");
			if (cpu.hv.host_feat_hpet_requested) printf(" hv_host_feat_hpet_requested");
			if (cpu.hv.host_feat_stimer_volatile) printf(" hv_host_feat_stimer_volatile");
			break;
		case VirtVendor.KVM:
			if (cpu.kvm.feature_clocksource) printf(" kvm_feature_clocksource");
			if (cpu.kvm.feature_nop_io_delay) printf(" kvm_feature_nop_io_delay");
			if (cpu.kvm.feature_mmu_op) printf(" kvm_feature_mmu_op");
			if (cpu.kvm.feature_clocksource2) printf(" kvm_feature_clocksource2");
			if (cpu.kvm.feature_async_pf) printf(" kvm_feature_async_pf");
			if (cpu.kvm.feature_steal_time) printf(" kvm_feature_steal_time");
			if (cpu.kvm.feature_pv_eoi) printf(" kvm_feature_pv_eoi");
			if (cpu.kvm.feature_pv_unhault) printf(" kvm_feature_pv_unhault");
			if (cpu.kvm.feature_pv_tlb_flush) printf(" kvm_feature_pv_tlb_flush");
			if (cpu.kvm.feature_async_pf_vmexit) printf(" kvm_feature_async_pf_vmexit");
			if (cpu.kvm.feature_pv_send_ipi) printf(" kvm_feature_pv_send_ipi");
			if (cpu.kvm.feature_pv_poll_control) printf(" kvm_feature_pv_poll_control");
			if (cpu.kvm.feature_pv_sched_yield) printf(" kvm_feature_pv_sched_yield");
			if (cpu.kvm.feature_clocsource_stable_bit) printf(" kvm_feature_clocsource_stable_bit");
			if (cpu.kvm.hint_realtime) printf(" kvm_hints_realtime");
			break;
		default:
		}
	}
	
	printf("\nMemory      :");
	
	if (cpu.pae) printf(" pae");
	if (cpu.pse) printf(" pse");
	if (cpu.pse36) printf(" pse-36");
	if (cpu.page1gb) printf(" page1gb");
	if (cpu.nx) {
		switch (cpu.vendor.id) with (Vendor) {
		case Intel:	tstr = " intel-xd/nx"; break;
		case AMD:	tstr = " amd-evp/nx"; break;
		default:	tstr = " nx";
		}
		printf(tstr);
	}
	if (cpu.dca) printf(" dca");
	if (cpu.pat) printf(" pat");
	if (cpu.mtrr) printf(" mtrr");
	if (cpu.pge) printf(" pge");
	if (cpu.smep) printf(" smep");
	if (cpu.smap) printf(" smap");
	if (cpu.pku) printf(" pku");
	if (cpu._5pl) printf(" 5pl");
	if (cpu.fsrepmov) printf(" fsrm");
	if (cpu.lam) printf(" lam");
	
	printf("\nPhysicalBits: %u\nLinearBits  : %u\nDebugging   :",
		cpu.physicalBits, cpu.linearBits);
	
	if (cpu.mca) printf(" mca");
	if (cpu.mce) printf(" mce");
	if (cpu.de) printf(" de");
	if (cpu.ds) printf(" ds");
	if (cpu.ds_cpl) printf(" ds-cpl");
	if (cpu.dtes64) printf(" dtes64");
	if (cpu.pdcm) printf(" pdcm");
	if (cpu.sdbg) printf(" sdbg");
	if (cpu.pbe) printf(" pbe");
	
	printf("\nSecurity    :");
	if (cpu.ia32_arch_capabilities) printf(" ia32_arch_capabilities");
	printSecurity(cpu);
	
	with (cpu) printf(
	"\n"~
	"Max. Leaf   : 0x%x\n"~
	"Max. V-Leaf : 0x%x\n"~
	"Max. E-Leaf : 0x%x\n"~
	"Type        : %s\n"~
	"Brand Index : %u\n"~
	"Misc.       :",
		maxLeaf, maxLeafVirt, maxLeafExtended, typeString, brandIndex);
	
	if (cpu.xtpr) printf(" xtpr");
	if (cpu.psn) printf(" psn");
	if (cpu.pcid) printf(" pcid");
	if (cpu.fsgsbase) printf(" fsgsbase");
	if (cpu.uintr) printf(" uintr");
	
	putchar('\n');
	
	return 0;
}
