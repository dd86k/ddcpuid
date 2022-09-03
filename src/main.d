/**
 * Program entry point.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: © 2016-2022 dd86k
 * License: MIT
 */
module main;

import core.stdc.stdio : printf; // sscanf
import core.stdc.errno : errno;
import core.stdc.stdlib : malloc, free;
import core.stdc.string : strcmp, strtok, strncpy, strerror;
import ddcpuid;

// NOTE: printf is used for a few reasons:
//       - fputs with stdout crashes on Windows due to improper externs.
//       - line buffering is used by default, which can be an advantage.
//TODO: Consider using WriteFile+STD_OUTPUT_HANDLE and write(2)+STDOUT_FILENO?
//      No real benefit than maybe save some instructions

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
	MAX_LEAF	= 0x30, /// Maximum leaf override
	MAX_VLEAF	= 0x4000_0000 + MAX_LEAF, /// Maximum virt leaf override
	MAX_ELEAF	= 0x8000_0000 + MAX_LEAF, /// Maximum extended leaf override
}

/// Command-line options
struct options_t { align(1):
	int maxLevel;	/// Maximum leaf for -r (-S)
	int maxSubLevel;	/// Maximum subleaf for -r (-s)
	bool hasLevel;	/// If -S has been used
	bool table;	/// To be deprecated
	bool override_;	/// Override leaves (-o)
	bool baseline;	/// Get x86-64 optimization feature level or baseline
	bool all;	/// Get all processor details
	bool raw;	/// Raw CPUID value table (-r/--raw)
	bool rawInput;	/// Raw values were supplied, avoid fetching
	bool[1] reserved;	/// 
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
	" -a, --all        Show all processor information\n"~
	" -b, --baseline   Print the processor's feature level\n"~
	" -d, --details    (Deprecated) Alias of --all\n"~
	" -l, --level      (Deprecated) Alias of --baseline\n"~
	" -o               Override maximum leaves to 0x20, 0x4000_0020, and 0x8000_0020\n"~
	" -r, --raw        Display raw CPUID values. Takes optional leaf,subleaf values.\n"~
	" -S               (Deprecated) Alias of --raw eax, requires --table\n"~
	" -s               (Deprecated) Alias of --raw eax,ecx, requires --table\n"~
	"     --table      (Deprecated) Alias of --raw\n"~
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
	"Copyright (c) 2016-2022 dd86k <dd@dax.moe>\n"~
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
pragma(inline, false) // ldc optimization thing
void printcpuid(ref REGISTERS regs, uint leaf, uint sub) {
	with (regs)
	printf("| %8x | %8x | %8x | %8x | %8x | %8x |\n",
		leaf, sub, eax, ebx, ecx, edx);
}

char adjust(ref float size) {
	version (Trace) trace("size=%u", size);
	if (size >= 1024.0) {
		size /= 1024;
		return 'M';
	}
	return 'K';
}
/// adjust
@system unittest {
	uint size = 1;
	assert(adjust(size) == 'K');
	assert(size == 1);
	size = 1024;
	assert(adjust(size) == 'M');
	assert(size == 1);
	size = 4096;
	assert(adjust(size) == 'M');
	assert(size == 4);
}
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

void printLegacy(ref CPUINFO info) {
	if (info.extensions.fpu) {
		printf(" x87/fpu");
		if (info.extensions.f16c) printf(" +f16c");
	}
	if (info.extensions.mmx) {
		printf(" mmx");
		if (info.extensions.mmxExtended) printf(" extmmx");
	}
	if (info.extensions._3DNow) {
		printf(" 3dnow!");
		if (info.extensions._3DNowExtended) printf(" ext3dnow!");
	}
}
void printTechs(ref CPUINFO info) {
	switch (info.vendor.id) with (Vendor) {
	case Intel:
		if (info.tech.eist) printf(" eist");
		if (info.tech.turboboost) {
			printf(" turboboost");
			if (info.tech.turboboost30) printf("-3.0");
		}
		if (info.memory.tsx) {
			printf(" tsx");
			if (info.memory.hle)
				printf(" +hle");
			if (info.memory.rtm)
				printf(" +rtm");
			if (info.memory.tsxldtrk)
				printf(" +tsxldtrk");
		}
		if (info.tech.smx) printf(" intel-txt/smx");
		if (info.sgx.supported) {
			// NOTE: SGX system configuration
			//       "enabled" in BIOS: only CPUID.7h.EBX[2]
			//       "user controlled" in BIOS: SGX1/SGX2/size bits
			if (info.sgx.sgx1 || info.sgx.sgx2) {
				if (info.sgx.sgx1) printf(" sgx1");
				if (info.sgx.sgx2) printf(" sgx2");
			} else printf(" sgx"); // Fallback per-say
			if (info.sgx.maxSize) {
				uint s32 = void, s64 = void;
				const(char) *m32 = adjustBits(s32, info.sgx.maxSize);
				const(char) *m64 = adjustBits(s64, info.sgx.maxSize64);
				printf(" +maxsize=%u%s +maxsize64=%u%s", s32, m32, s64, m64);
			}
		}
		break;
	case AMD:
		if (info.tech.turboboost) printf(" core-performance-boost");
		break;
	default:
	}
	if (info.tech.htt) printf(" htt");
}
void printSSE(ref CPUINFO info) {
	printf(" sse");
	if (info.sse.sse2) printf(" sse2");
	if (info.sse.sse3) printf(" sse3");
	if (info.sse.ssse3) printf(" ssse3");
	if (info.sse.sse41) printf(" sse4.1");
	if (info.sse.sse42) printf(" sse4.2");
	if (info.sse.sse4a) printf(" sse4a");
}
void printAVX(ref CPUINFO info) {
	printf(" avx");
	if (info.avx.avx2) printf(" avx2");
	if (info.avx.avx512f) {
		printf(" avx512f");
		if (info.avx.avx512er) printf(" +er");
		if (info.avx.avx512pf) printf(" +pf");
		if (info.avx.avx512cd) printf(" +cd");
		if (info.avx.avx512dq) printf(" +dq");
		if (info.avx.avx512bw) printf(" +bw");
		if (info.avx.avx512vl) printf(" +vl");
		if (info.avx.avx512_ifma) printf(" +ifma");
		if (info.avx.avx512_vbmi) printf(" +vbmi");
		if (info.avx.avx512_4vnniw) printf(" +4vnniw");
		if (info.avx.avx512_4fmaps) printf(" +4fmaps");
		if (info.avx.avx512_vbmi2) printf(" +vbmi2");
		if (info.avx.avx512_gfni) printf(" +gfni");
		if (info.avx.avx512_vaes) printf(" +vaes");
		if (info.avx.avx512_vnni) printf(" +vnni");
		if (info.avx.avx512_bitalg) printf(" +bitalg");
		if (info.avx.avx512_bf16) printf(" +bf16");
		if (info.avx.avx512_vp2intersect) printf(" +vp2intersect");
	}
	if (info.extensions.xop) printf(" xop");
}
void printFMA(ref CPUINFO info) {
	if (info.extensions.fma3) printf(" fma3");
	if (info.extensions.fma4) printf(" fma4");
}
void printAMX(ref CPUINFO info) {
	printf(" amx");
	if (info.amx.bf16) printf(" +bf16");
	if (info.amx.int8) printf(" +int8");
	if (info.amx.xtilecfg) printf(" +xtilecfg");
	if (info.amx.xtiledata) printf(" +xtiledata");
	if (info.amx.xfd) printf(" +xfd");
}
void printOthers(ref CPUINFO info) {
	const(char) *tstr = void;
	if (info.extensions.x86_64) {
		switch (info.vendor.id) with (Vendor) {
		case Intel:	tstr = " intel64/x86-64"; break;
		case AMD:	tstr = " amd64/x86-64"; break;
		default:	tstr = " x86-64";
		}
		printf(tstr);
		if (info.extensions.lahf64)
			printf(" +lahf64");
	}
	if (info.virt.available)
		switch (info.vendor.id) with (Vendor) {
		case Intel: printf(" vt-x/vmx"); break;
		case AMD: // SVM
			printf(" amd-v/vmx");
			if (info.virt.version_)
				printf(" +svm=v%u", info.virt.version_);
			break;
		case VIA: printf(" via-vt/vmx"); break;
		default: printf(" vmx");
		}
	if (info.extensions.aes_ni) printf(" aes-ni");
	if (info.extensions.adx) printf(" adx");
	if (info.extensions.sha) printf(" sha");
	if (info.extensions.tbm) printf(" tbm");
	if (info.extensions.bmi1) printf(" bmi1");
	if (info.extensions.bmi2) printf(" bmi2");
	if (info.extensions.waitpkg) printf(" waitpkg");
}
void printSecurity(ref CPUINFO info) {
	if (info.security.ibpb) printf(" ibpb");
	if (info.security.ibrs) printf(" ibrs");
	if (info.security.ibrsAlwaysOn) printf(" ibrs_on");	// AMD
	if (info.security.ibrsPreferred) printf(" ibrs_pref");	// AMD
	if (info.security.stibp) printf(" stibp");
	if (info.security.stibpAlwaysOn) printf(" stibp_on");	// AMD
	if (info.security.ssbd) printf(" ssbd");
	if (info.security.l1dFlush) printf(" l1d_flush");	// Intel
	if (info.security.md_clear) printf(" md_clear");	// Intel
	if (info.security.cetIbt) printf(" cet_ibt");	// Intel
	if (info.security.cetSs) printf(" cet_ss");	// Intel
}
void printCacheFeats(ushort feats) {
	if (feats == 0) return;
	putchar(',');
	if (feats & BIT!(0)) printf(" si"); // Self Initiative
	if (feats & BIT!(1)) printf(" fa"); // Fully Associative
	if (feats & BIT!(2)) printf(" nwbv"); // No Write-Back Validation
	if (feats & BIT!(3)) printf(" ci"); // Cache Inclusive
	if (feats & BIT!(4)) printf(" cci"); // Complex Cache Indexing
}

int optionRaw(ref options_t options, const(char) *arg) {
	enum MAX = 512;
	
	version (Trace) trace("arg=%s", arg);
	
	options.raw = true;
	if (arg == null) return 0;
	
	char *s = cast(char*)malloc(MAX);
	if (s == null) {
		puts(strerror(errno));
		return 1;
	}
	
	options.rawInput = true;
	strncpy(s, arg, MAX);
	arg = strtok(s, ",");
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
	free(s);
	return 0;
}

//TODO: --no-header for -c/--cpuid
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
			if (strcmp(arg, "table") == 0) {
				options.table = true;
				continue;
			}
			if (strcmp(arg, "level") == 0 || strcmp(arg, "baseline") == 0) {
				options.baseline = true;
				continue;
			}
			if (strcmp(arg, "details") == 0 || strcmp(arg, "all") == 0) {
				options.all = true;
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
				case 'a', 'd': options.all = true; continue;
				case 'b', 'l': options.baseline = true; continue;
				case 'o': options.override_ = true; continue;
				case 'r':
					val = argi + 1 >= argc ? null : argv[argi + 1];
					if (val && val[0] == '-') val = null;
					error = optionRaw(options, val);
					if (error) return error;
					continue;
				case 'S':
					if (++argi >= argc) {
						puts("Missing parameter: leaf");
						return 1;
					}
					options.hasLevel = sscanf(argv[argi], "%i", &options.maxLevel) == 1;
					options.rawInput = true;
					if (options.hasLevel == false) {
						puts("Could not parse level (-S)");
						return 2;
					}
					continue;
				case 's':
					if (++argi >= argc) {
						puts("Missing parameter: sub-leaf (-s)");
						return 1;
					}
					if (sscanf(argv[argi], "%i", &options.maxSubLevel) != 1) {
						puts("Could not parse sub-level (-s)");
						return 2;
					}
					options.rawInput = true;
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
	
	CPUINFO info;
	
	if (options.override_) {
		info.maxLeaf = MAX_LEAF;
		info.maxLeafVirt = MAX_VLEAF;
		info.maxLeafExtended = MAX_ELEAF;
	} else if (options.rawInput == false) {
		ddcpuid_leaves(info);
	}
	
	if (options.raw || options.table) {
		uint l = void, s = void;
		
		puts(
		"| Leaf     | Sub-leaf | EAX      | EBX      | ECX      | EDX      |\n"~
		"|----------|----------|----------|----------|----------|----------|"
		);
		
		if (options.rawInput) {
			outcpuid(options.maxLevel, options.maxSubLevel);
			return 0;
		}
		
		// Normal
		for (l = 0; l <= info.maxLeaf; ++l)
			for (s = 0; s <= options.maxSubLevel; ++s)
				outcpuid(l, s);
		
		// Paravirtualization
		if (info.maxLeafVirt > 0x4000_0000)
		for (l = 0x4000_0000; l <= info.maxLeafVirt; ++l)
			for (s = 0; s <= options.maxSubLevel; ++s)
				outcpuid(l, s);
		
		// Extended
		for (l = 0x8000_0000; l <= info.maxLeafExtended; ++l)
			for (s = 0; s <= options.maxSubLevel; ++s)
				outcpuid(l, s);
		return 0;
	}
	
	ddcpuid_cpuinfo(info);
	
	if (options.baseline) {
		puts(ddcpuid_baseline(info));
		return 0;
	}
	
	// NOTE: .ptr crash with GDC -O3
	//       glibc!__strlen_sse2 (in printf)
	char *vendorstr = cast(char*)info.vendor.string_;
	char *brandstr  = cast(char*)info.brandString;
	
	// Brand string left space trimming
	// While very common in Intel, let's also do it for others (in case of)
	while (*brandstr == ' ') ++brandstr;
	
	CACHEINFO *cache = void;	/// Current cache level
	
	//
	// ANCHOR Summary
	//
	
	if (options.all == false) {
		const(char) *s_cores = info.cores.physical == 1 ? "core" : "cores";
		const(char) *s_threads = info.cores.logical == 1 ? "thread" : "threads";
		with (info) printf(
		"Name:        %.12s %.48s\n"~
		"Identifier:  Family 0x%x Model 0x%x Stepping 0x%x\n"~
		"Cores:       %u %s, %u %s\n",
		vendorstr, brandstr,
		family, model, stepping,
		cores.physical, s_cores, cores.logical, s_threads
		);
		
		if (info.memory.physBits || info.memory.lineBits) {
			uint maxPhys = void, maxLine = void;
			const(char) *cphys = adjustBits(maxPhys, info.memory.physBits);
			const(char) *cline = adjustBits(maxLine, info.memory.lineBits);
			with (info) printf(
			"Max. Memory: %u %s physical, %u %s virtual\n",
			maxPhys, cphys, maxLine, cline,
			);
		}
		
		with (info) printf(
		"Baseline:    %s\n"~
		"Techs:      ",
		ddcpuid_baseline(info)
		);
		
		printTechs(info);
		
		printf("\nExtensions: ");
		printLegacy(info);
		printOthers(info);
		
		printf("\nSSE:        ");
		if (info.sse.sse)
			printSSE(info);
		printFMA(info);
		putchar('\n');
		
		printf("AVX:        ");
		if (info.avx.avx)
			printAVX(info);
		putchar('\n');
		
		printf("AMX:        ");
		if (info.amx.enabled)
			printAMX(info);
		putchar('\n');
		
		printf("Mitigations:");
		printSecurity(info);
		putchar('\n');
		
		// NOTE: id=0 would be vboxmin, so using this is more reliable
		if (info.maxLeafVirt) {
			const(char) *virtVendor = void;
			switch (info.virt.vendor.id) with (VirtVendor) {
			case KVM:        virtVendor = "KVM"; break;
			case HyperV:     virtVendor = "Hyper-V"; break;
			case VBoxHyperV: virtVendor = "VirtualBox Hyper-V"; break;
			case VBoxMin:    virtVendor = "VirtualBox Minimal"; break;
			default:         virtVendor = "Unknown";
			}
			printf("ParaVirt.:   %s\n", virtVendor);
		}
		
		for (size_t i; i < info.cache.levels; ++i) {
			cache = &info.cache.level[i];
			float csize = cache.size;
			float tsize = csize * cache.sharedCores;
			char cc = adjust(csize);
			char ct = adjust(tsize);
			with (cache)
			printf("Cache L%u-%c:  %3ux %4g %ciB, %4g %ciB total",
				level, type, sharedCores, csize, cc, tsize, ct);
			printCacheFeats(cache.features);
			putchar('\n');
		}
		
		return 0;
	}
	
	//
	// ANCHOR Detailed view
	//
	
	with (info) printf(
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
	cores.physical, cores.logical
	);
	
	// Extensions
	
	const(char) *tstr = void;
	printLegacy(info);
	if (info.sse.sse) printSSE(info);
	if (info.avx.avx) printAVX(info);
	printFMA(info);
	printOthers(info);
	if (info.amx.enabled) printAMX(info);
	
	//
	// ANCHOR Extra/lone instructions
	//
	
	printf("\nExtra       :");
	if (info.extras.monitor) {
		printf(" monitor+mwait");
		if (info.extras.mwaitMin)
			printf(" +min=%u +max=%u",
				info.extras.mwaitMin, info.extras.mwaitMax);
		if (info.extras.monitorx) printf(" monitorx+mwaitx");
	}
	if (info.extras.pclmulqdq) printf(" pclmulqdq");
	if (info.extras.cmpxchg8b) printf(" cmpxchg8b");
	if (info.extras.cmpxchg16b) printf(" cmpxchg16b");
	if (info.extras.movbe) printf(" movbe");
	if (info.extras.rdrand) printf(" rdrand");
	if (info.extras.rdseed) printf(" rdseed");
	if (info.extras.rdmsr) printf(" rdmsr+wrmsr");
	if (info.extras.sysenter) printf(" sysenter+sysexit");
	if (info.extras.syscall) printf(" syscall+sysret");
	if (info.extras.rdtsc) {
		printf(" rdtsc");
		if (info.extras.rdtscDeadline)
			printf(" +tsc-deadline");
		if (info.extras.rdtscInvariant)
			printf(" +tsc-invariant");
	}
	if (info.extras.rdtscp) printf(" rdtscp");
	if (info.extras.rdpid) printf(" rdpid");
	if (info.extras.cmov) {
		printf(" cmov");
		if (info.extensions.fpu) printf(" fcomi+fcmov");
	}
	if (info.extras.lzcnt) printf(" lzcnt");
	if (info.extras.popcnt) printf(" popcnt");
	if (info.extras.xsave) printf(" xsave+xrstor");
	if (info.extras.osxsave) printf(" xsetbv+xgetbv");
	if (info.extras.fxsr) printf(" fxsave+fxrstor");
	if (info.extras.pconfig) printf(" pconfig");
	if (info.extras.cldemote) printf(" cldemote");
	if (info.extras.movdiri) printf(" movdiri");
	if (info.extras.movdir64b) printf(" movdir64b");
	if (info.extras.enqcmd) printf(" enqcmd");
	if (info.extras.skinit) printf(" skinit+stgi");
	if (info.extras.serialize) printf(" serialize");
	
	//
	// ANCHOR Vendor specific technologies
	//
	
	printf("\nTechnologies:");
	printTechs(info);
	
	//
	// ANCHOR Cache information
	//
	
	printf("\nCache       :");
	if (info.cache.clflush)
		printf(" clflush=%uB", info.cache.clflushLinesize << 3);
	if (info.cache.clflushopt) printf(" clflushopt");
	if (info.cache.cnxtId) printf(" cnxt-id");
	if (info.cache.ss) printf(" ss");
	if (info.cache.prefetchw) printf(" prefetchw");
	if (info.cache.invpcid) printf(" invpcid");
	if (info.cache.wbnoinvd) printf(" wbnoinvd");
	
	for (uint i; i < info.cache.levels; ++i) {
		cache = &info.cache.level[i];
		printf("\nLevel %u-%c   : %2ux %6u KiB, %u ways, %u parts, %u B, %u sets",
			cache.level, cache.type, cache.sharedCores, cache.size,
			cache.ways, cache.partitions, cache.lineSize, cache.sets
		);
		printCacheFeats(cache.features);
	}
	
	printf("\nSystem      :");
	if (info.sys.available) printf(" acpi");
	if (info.sys.apic) printf(" apic");
	if (info.sys.x2apic) printf(" x2apic");
	if (info.sys.arat) printf(" arat");
	if (info.sys.tm) printf(" tm");
	if (info.sys.tm2) printf(" tm2");
	printf(" apic-id=%u", info.sys.apicId);
	if (info.sys.maxApicId) printf(" max-id=%u", info.sys.maxApicId);
	
	printf("\nVirtual     :");
	if (info.virt.vme) printf(" vme");
	if (info.virt.apicv) printf(" apicv");
	
	// Paravirtualization
	if (info.virt.vendor.id) {
		// See vendor string case
		char *virtvendor = cast(char*)info.virt.vendor.string_;
		printf(" host=%.12s", virtvendor);
	}
	switch (info.virt.vendor.id) with (VirtVendor) {
	case VBoxMin:
		if (info.virt.vbox.tsc_freq_khz)
			printf(" tsc_freq_khz=%u", info.virt.vbox.tsc_freq_khz);
		if (info.virt.vbox.apic_freq_khz)
			printf(" apic_freq_khz=%u", info.virt.vbox.apic_freq_khz);
		break;
	case HyperV:
		printf(" opensource=%d vendor_id=%d os=%d major=%d minor=%d service=%d build=%d",
			info.virt.hv.guest_opensource,
			info.virt.hv.guest_vendor_id,
			info.virt.hv.guest_os,
			info.virt.hv.guest_major,
			info.virt.hv.guest_minor,
			info.virt.hv.guest_service,
			info.virt.hv.guest_build);
		if (info.virt.hv.base_feat_vp_runtime_msr) printf(" hv_base_feat_vp_runtime_msr");
		if (info.virt.hv.base_feat_part_time_ref_count_msr) printf(" hv_base_feat_part_time_ref_count_msr");
		if (info.virt.hv.base_feat_basic_synic_msrs) printf(" hv_base_feat_basic_synic_msrs");
		if (info.virt.hv.base_feat_stimer_msrs) printf(" hv_base_feat_stimer_msrs");
		if (info.virt.hv.base_feat_apic_access_msrs) printf(" hv_base_feat_apic_access_msrs");
		if (info.virt.hv.base_feat_hypercall_msrs) printf(" hv_base_feat_hypercall_msrs");
		if (info.virt.hv.base_feat_vp_id_msr) printf(" hv_base_feat_vp_id_msr");
		if (info.virt.hv.base_feat_virt_sys_reset_msr) printf(" hv_base_feat_virt_sys_reset_msr");
		if (info.virt.hv.base_feat_stat_pages_msr) printf(" hv_base_feat_stat_pages_msr");
		if (info.virt.hv.base_feat_part_ref_tsc_msr) printf(" hv_base_feat_part_ref_tsc_msr");
		if (info.virt.hv.base_feat_guest_idle_state_msr) printf(" hv_base_feat_guest_idle_state_msr");
		if (info.virt.hv.base_feat_timer_freq_msrs) printf(" hv_base_feat_timer_freq_msrs");
		if (info.virt.hv.base_feat_debug_msrs) printf(" hv_base_feat_debug_msrs");
		if (info.virt.hv.part_flags_create_part) printf(" hv_part_flags_create_part");
		if (info.virt.hv.part_flags_access_part_id) printf(" hv_part_flags_access_part_id");
		if (info.virt.hv.part_flags_access_memory_pool) printf(" hv_part_flags_access_memory_pool");
		if (info.virt.hv.part_flags_adjust_msg_buffers) printf(" hv_part_flags_adjust_msg_buffers");
		if (info.virt.hv.part_flags_post_msgs) printf(" hv_part_flags_post_msgs");
		if (info.virt.hv.part_flags_signal_events) printf(" hv_part_flags_signal_events");
		if (info.virt.hv.part_flags_create_port) printf(" hv_part_flags_create_port");
		if (info.virt.hv.part_flags_connect_port) printf(" hv_part_flags_connect_port");
		if (info.virt.hv.part_flags_access_stats) printf(" hv_part_flags_access_stats");
		if (info.virt.hv.part_flags_debugging) printf(" hv_part_flags_debugging");
		if (info.virt.hv.part_flags_cpu_mgmt) printf(" hv_part_flags_cpu_mgmt");
		if (info.virt.hv.part_flags_cpu_profiler) printf(" hv_part_flags_cpu_profiler");
		if (info.virt.hv.part_flags_expanded_stack_walk) printf(" hv_part_flags_expanded_stack_walk");
		if (info.virt.hv.part_flags_access_vsm) printf(" hv_part_flags_access_vsm");
		if (info.virt.hv.part_flags_access_vp_regs) printf(" hv_part_flags_access_vp_regs");
		if (info.virt.hv.part_flags_extended_hypercalls) printf(" hv_part_flags_extended_hypercalls");
		if (info.virt.hv.part_flags_start_vp) printf(" hv_part_flags_start_vp");
		if (info.virt.hv.pm_max_cpu_power_state_c0) printf(" hv_pm_max_cpu_power_state_c0");
		if (info.virt.hv.pm_max_cpu_power_state_c1) printf(" hv_pm_max_cpu_power_state_c1");
		if (info.virt.hv.pm_max_cpu_power_state_c2) printf(" hv_pm_max_cpu_power_state_c2");
		if (info.virt.hv.pm_max_cpu_power_state_c3) printf(" hv_pm_max_cpu_power_state_c3");
		if (info.virt.hv.pm_hpet_reqd_for_c3) printf(" hv_pm_hpet_reqd_for_c3");
		if (info.virt.hv.misc_feat_mwait) printf(" hv_misc_feat_mwait");
		if (info.virt.hv.misc_feat_guest_debugging) printf(" hv_misc_feat_guest_debugging");
		if (info.virt.hv.misc_feat_perf_mon) printf(" hv_misc_feat_perf_mon");
		if (info.virt.hv.misc_feat_pcpu_dyn_part_event) printf(" hv_misc_feat_pcpu_dyn_part_event");
		if (info.virt.hv.misc_feat_xmm_hypercall_input) printf(" hv_misc_feat_xmm_hypercall_input");
		if (info.virt.hv.misc_feat_guest_idle_state) printf(" hv_misc_feat_guest_idle_state");
		if (info.virt.hv.misc_feat_hypervisor_sleep_state) printf(" hv_misc_feat_hypervisor_sleep_state");
		if (info.virt.hv.misc_feat_query_numa_distance) printf(" hv_misc_feat_query_numa_distance");
		if (info.virt.hv.misc_feat_timer_freq) printf(" hv_misc_feat_timer_freq");
		if (info.virt.hv.misc_feat_inject_synmc_xcpt) printf(" hv_misc_feat_inject_synmc_xcpt");
		if (info.virt.hv.misc_feat_guest_crash_msrs) printf(" hv_misc_feat_guest_crash_msrs");
		if (info.virt.hv.misc_feat_debug_msrs) printf(" hv_misc_feat_debug_msrs");
		if (info.virt.hv.misc_feat_npiep1) printf(" hv_misc_feat_npiep1");
		if (info.virt.hv.misc_feat_disable_hypervisor) printf(" hv_misc_feat_disable_hypervisor");
		if (info.virt.hv.misc_feat_ext_gva_range_for_flush_va_list) printf(" hv_misc_feat_ext_gva_range_for_flush_va_list");
		if (info.virt.hv.misc_feat_hypercall_output_xmm) printf(" hv_misc_feat_hypercall_output_xmm");
		if (info.virt.hv.misc_feat_sint_polling_mode) printf(" hv_misc_feat_sint_polling_mode");
		if (info.virt.hv.misc_feat_hypercall_msr_lock) printf(" hv_misc_feat_hypercall_msr_lock");
		if (info.virt.hv.misc_feat_use_direct_synth_msrs) printf(" hv_misc_feat_use_direct_synth_msrs");
		if (info.virt.hv.hint_hypercall_for_process_switch) printf(" hv_hint_hypercall_for_process_switch");
		if (info.virt.hv.hint_hypercall_for_tlb_flush) printf(" hv_hint_hypercall_for_tlb_flush");
		if (info.virt.hv.hint_hypercall_for_tlb_shootdown) printf(" hv_hint_hypercall_for_tlb_shootdown");
		if (info.virt.hv.hint_msr_for_apic_access) printf(" hv_hint_msr_for_apic_access");
		if (info.virt.hv.hint_msr_for_sys_reset) printf(" hv_hint_msr_for_sys_reset");
		if (info.virt.hv.hint_relax_time_checks) printf(" hv_hint_relax_time_checks");
		if (info.virt.hv.hint_dma_remapping) printf(" hv_hint_dma_remapping");
		if (info.virt.hv.hint_interrupt_remapping) printf(" hv_hint_interrupt_remapping");
		if (info.virt.hv.hint_x2apic_msrs) printf(" hv_hint_x2apic_msrs");
		if (info.virt.hv.hint_deprecate_auto_eoi) printf(" hv_hint_deprecate_auto_eoi");
		if (info.virt.hv.hint_synth_cluster_ipi_hypercall) printf(" hv_hint_synth_cluster_ipi_hypercall");
		if (info.virt.hv.hint_ex_proc_masks_interface) printf(" hv_hint_ex_proc_masks_interface");
		if (info.virt.hv.hint_nested_hyperv) printf(" hv_hint_nested_hyperv");
		if (info.virt.hv.hint_int_for_mbec_syscalls) printf(" hv_hint_int_for_mbec_syscalls");
		if (info.virt.hv.hint_nested_enlightened_vmcs_interface) printf(" hv_hint_nested_enlightened_vmcs_interface");
		if (info.virt.hv.host_feat_avic) printf(" hv_host_feat_avic");
		if (info.virt.hv.host_feat_msr_bitmap) printf(" hv_host_feat_msr_bitmap");
		if (info.virt.hv.host_feat_perf_counter) printf(" hv_host_feat_perf_counter");
		if (info.virt.hv.host_feat_nested_paging) printf(" hv_host_feat_nested_paging");
		if (info.virt.hv.host_feat_dma_remapping) printf(" hv_host_feat_dma_remapping");
		if (info.virt.hv.host_feat_interrupt_remapping) printf(" hv_host_feat_interrupt_remapping");
		if (info.virt.hv.host_feat_mem_patrol_scrubber) printf(" hv_host_feat_mem_patrol_scrubber");
		if (info.virt.hv.host_feat_dma_prot_in_use) printf(" hv_host_feat_dma_prot_in_use");
		if (info.virt.hv.host_feat_hpet_requested) printf(" hv_host_feat_hpet_requested");
		if (info.virt.hv.host_feat_stimer_volatile) printf(" hv_host_feat_stimer_volatile");
		break;
	case VirtVendor.KVM:
		if (info.virt.kvm.feature_clocksource) printf(" kvm_feature_clocksource");
		if (info.virt.kvm.feature_nop_io_delay) printf(" kvm_feature_nop_io_delay");
		if (info.virt.kvm.feature_mmu_op) printf(" kvm_feature_mmu_op");
		if (info.virt.kvm.feature_clocksource2) printf(" kvm_feature_clocksource2");
		if (info.virt.kvm.feature_async_pf) printf(" kvm_feature_async_pf");
		if (info.virt.kvm.feature_steal_time) printf(" kvm_feature_steal_time");
		if (info.virt.kvm.feature_pv_eoi) printf(" kvm_feature_pv_eoi");
		if (info.virt.kvm.feature_pv_unhault) printf(" kvm_feature_pv_unhault");
		if (info.virt.kvm.feature_pv_tlb_flush) printf(" kvm_feature_pv_tlb_flush");
		if (info.virt.kvm.feature_async_pf_vmexit) printf(" kvm_feature_async_pf_vmexit");
		if (info.virt.kvm.feature_pv_send_ipi) printf(" kvm_feature_pv_send_ipi");
		if (info.virt.kvm.feature_pv_poll_control) printf(" kvm_feature_pv_poll_control");
		if (info.virt.kvm.feature_pv_sched_yield) printf(" kvm_feature_pv_sched_yield");
		if (info.virt.kvm.feature_clocsource_stable_bit) printf(" kvm_feature_clocsource_stable_bit");
		if (info.virt.kvm.hint_realtime) printf(" kvm_hints_realtime");
		break;
	default:
	}
	
	printf("\nMemory      :");
	
	if (info.memory.pae) printf(" pae");
	if (info.memory.pse) printf(" pse");
	if (info.memory.pse36) printf(" pse-36");
	if (info.memory.page1gb) printf(" page1gb");
	if (info.memory.nx) {
		switch (info.vendor.id) with (Vendor) {
		case Intel:	tstr = " intel-xd/nx"; break;
		case AMD:	tstr = " amd-evp/nx"; break;
		default:	tstr = " nx";
		}
		printf(tstr);
	}
	if (info.memory.dca) printf(" dca");
	if (info.memory.pat) printf(" pat");
	if (info.memory.mtrr) printf(" mtrr");
	if (info.memory.pge) printf(" pge");
	if (info.memory.smep) printf(" smep");
	if (info.memory.smap) printf(" smap");
	if (info.memory.pku) printf(" pku");
	if (info.memory._5pl) printf(" 5pl");
	if (info.memory.fsrepmov) printf(" fsrm");
	if (info.memory.lam) printf(" lam");
	
	with (info.memory)
	printf("\nPhysicalBits: %u\nLinearBits  : %u\nDebugging   :",
		physBits, lineBits);
	
	if (info.debugging.mca) printf(" mca");
	if (info.debugging.mce) printf(" mce");
	if (info.debugging.de) printf(" de");
	if (info.debugging.ds) printf(" ds");
	if (info.debugging.ds_cpl) printf(" ds-cpl");
	if (info.debugging.dtes64) printf(" dtes64");
	if (info.debugging.pdcm) printf(" pdcm");
	if (info.debugging.sdbg) printf(" sdbg");
	if (info.debugging.pbe) printf(" pbe");
	
	printf("\nSecurity    :");
	if (info.security.ia32_arch_capabilities) printf(" ia32_arch_capabilities");
	printSecurity(info);
	
	with (info)
	printf(
	"\nMax. Leaf   : 0x%x\n"~
	"Max. V-Leaf : 0x%x\n"~
	"Max. E-Leaf : 0x%x\n"~
	"Type        : %s\n"~
	"Brand Index : %u\n"~
	"Misc.       :",
		maxLeaf, maxLeafVirt, maxLeafExtended, typeString, brandIndex);
	
	if (info.misc.xtpr) printf(" xtpr");
	if (info.misc.psn) printf(" psn");
	if (info.misc.pcid) printf(" pcid");
	if (info.misc.fsgsbase) printf(" fsgsbase");
	if (info.misc.uintr) printf(" uintr");
	
	putchar('\n');
	
	return 0;
}
