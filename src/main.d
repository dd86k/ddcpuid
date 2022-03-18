/**
 * Program entry point.
 *
 * NOTE: printf is mainly used for two reasons.  First, fputs with stdout
 *       crashes on Windows. Secondly, line buffering is used by default.
 *
 * Authors: dd86k (dd@dax.moe)
 * Copyright: © 2016-2022 dd86k
 * License: MIT
 */
module main;

import core.stdc.errno : errno;
import core.stdc.stdio : printf, sscanf, FILE, fopen, fread, fwrite;
import core.stdc.string : strcmp;
import ddcpuid;

private:
@system:
extern (C):

int putchar(int);
int puts(scope const char* s);

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
	MAX_VLEAF	= 0x4000_0000 + MAX_LEAF, /// Maximum virt leaf override
	MAX_ELEAF	= 0x8000_0000 + MAX_LEAF, /// Maximum extended leaf override
}

/// Command-line options
struct options_t { align(1):
	int maxLevel;	/// Maximum leaf for -r (-S)
	int maxSub;	/// Maximum subleaf for -r (-s)
	bool hasLevel;	/// If -S has been used
	bool table;	/// Raw table (-r)
	bool override_;	/// Override leaves (-o)
	bool getLevel;	/// Get x86-64 optimization feature level
	bool getDetails;	/// Get the boring details
	bool[3] reserved;	/// 
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

//TODO: Consider having a CPUINFO instance globally to avoid parameter spam

/// print help page
void clih() {
	puts(
	"x86/AMD64 CPUID information tool\n"~
	"\n"~
	"USAGE\n"~
	" ddcpuid [OPTIONS...]\n"~
	"\n"~
	"OPTIONS\n"~
	" -d, --details  Show detailed processor information\n"~
	" -r, --table    Show raw CPUID data in a table\n"~
	" -S             Table: Set leaf (EAX) input value\n"~
	" -s             Table: Set subleaf (ECX) input value\n"~
//	" -D, --dump     Dump CPUID data into binary\n"~
	" -o             Override maximum leaves to 0x20, 0x4000_0020, and 0x8000_0020\n"~
	" -l, --level    Print the processor's feature level\n"~
	"\n"~
	"PAGES\n"~
	" --version    Print version screen and quit\n"~
	" --ver        Print version and quit\n"~
	" -h, --help   Print this help screen and quit"
	);
}

/// print version page
void cliv() {
	puts(
	"ddcpuid-"~DDCPUID_PLATFORM~" "~DDCPUID_VERSION~" (built: "~__TIMESTAMP__~")\n"~
	"Copyright (c) 2016-2021 dd86k <dd@dax.moe>\n"~
	"License: MIT License <http://opensource.org/licenses/MIT>\n"~
	"Homepage: <https://github.com/dd86k/ddcpuid>\n"~
	"Compiler: "~__VENDOR__~" "~CVER!(__VERSION__)
	);
}

void outcpuid(uint leaf, uint sub) {
	REGISTERS regs = void;
	__cpuid(regs, leaf, sub);
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

const(char) *baseline(ref CPUINFO info) {
	if (info.extensions.x86_64 == false) {
		if (info.family >= 6) // Pentium Pro / II
			return "i686";
		// NOTE: K7 is still family 5 and didn't have SSE2.
		return info.family == 5 ? "i586" : "i486"; // Pentium / MMX
	}
	
	// v4
	if (info.avx.avx512f && info.avx.avx512bw &&
		info.avx.avx512cd && info.avx.avx512dq &&
		info.avx.avx512vl) {
		return "x86-64-v4";
	}
	
	// v3
	if (info.avx.avx2 && info.avx.avx &&
		info.extensions.bmi2 && info.extensions.bmi1 &&
		info.extensions.f16c && info.extensions.fma3 &&
		info.extras.lzcnt && info.extras.movbe &&
		info.extras.osxsave) {
		return "x86-64-v3";
	}
	
	// v2
	if (info.sse.sse42 && info.sse.sse41 &&
		info.sse.ssse3 && info.sse.sse3 &&
		info.extensions.lahf64 && info.extras.popcnt &&
		info.extras.cmpxchg16b) {
		return "x86-64-v2";
	}
	
	// baseline (v1)
	/*if (info.sse.sse2 && info.sse.sse &&
		info.extensions.mmx && info.extras.fxsr &&
		info.extras.cmpxchg8b && info.extras.cmov &&
		info.extensions.fpu && info.extras.syscall) {
		return "x86-64";
	}*/
	
	return "x86-64"; // v1 anyway
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
char adjustBits(ref uint size, int bitpos) {
	version (Trace) trace("size=%u bit=%d", size, bitpos);
	immutable char[8] SIZE = [ 0, 'K', 'M', 'G', 'T', 'P', 'E', 'Z' ];
	size_t s;
	while (bitpos >= 10) {
		bitpos -= 10;
		++s;
	}
	size = 1 << bitpos;
	return SIZE[s];
}
//TODO: Make DUB to include this main, somehow
/// adjustBits
@system unittest {
	float size;
	assert(adjustBits(size, 0) == 0);
	assert(size == 1);
	assert(adjustBits(size, 1) == 0);
	assert(size == 2);
	assert(adjustBits(size, 10) == 'K');
	assert(size == 1);
	assert(adjustBits(size, 11) == 'K');
	assert(size == 2);
	assert(adjustBits(size, 20) == 'M');
	assert(size == 1);
	assert(adjustBits(size, 36) == 'G');
	assert(size == 64);
	assert(adjustBits(size, 48) == 'T');
	assert(size == 256);
}

void printLegacy(ref CPUINFO info) {
	if (info.extensions.fpu) {
		printf(" x87/FPU");
		if (info.extensions.f16c) printf(" +F16C");
	}
	if (info.extensions.mmx) {
		printf(" MMX");
		if (info.extensions.mmxExtended) printf(" ExtMMX");
	}
	if (info.extensions._3DNow) {
		printf(" 3DNow!");
		if (info.extensions._3DNowExtended) printf(" Ext3DNow!");
	}
}
void printTechs(ref CPUINFO info) {
	switch (info.vendor.id) with (Vendor) {
	case Intel:
		if (info.tech.eist) printf(" EIST");
		if (info.tech.turboboost) {
			printf(" TurboBoost");
			if (info.tech.turboboost30) printf("-3.0");
		}
		if (info.memory.tsx) {
			printf(" TSX");
			if (info.memory.hle)
				printf(" +HLE");
			if (info.memory.rtm)
				printf(" +RTM");
			if (info.memory.tsxldtrk)
				printf(" +TSXLDTRK");
		}
		if (info.tech.smx) printf(" Intel-TXT/SMX");
		if (info.sgx.supported) {
			// NOTE: SGX system configuration
			//       "enabled" in BIOS: only CPUID.7h.EBX[2]
			//       "user controlled" in BIOS: SGX1/SGX2/size bits
			if (info.sgx.sgx1 && info.sgx.sgx2) {
				if (info.sgx.sgx1) printf(" SGX1");
				if (info.sgx.sgx2) printf(" SGX2");
			} else printf(" SGX"); // Fallback per-say
			if (info.sgx.maxSize) {
				uint s32 = void, s64 = void;
				char m32 = adjustBits(s32, info.sgx.maxSize);
				char m64 = adjustBits(s64, info.sgx.maxSize64);
				printf(" +maxSize=%u%cB +maxSize64=%u%cB", s32, m32, s64, m64);
			}
		}
		break;
	case AMD:
		if (info.tech.turboboost) printf(" Core-Performance-Boost");
		break;
	default:
	}
	if (info.tech.htt) printf(" HTT");
}
void printSSE(ref CPUINFO info) {
	printf(" SSE");
	if (info.sse.sse2) printf(" SSE2");
	if (info.sse.sse3) printf(" SSE3");
	if (info.sse.ssse3) printf(" SSSE3");
	if (info.sse.sse41) printf(" SSE4.1");
	if (info.sse.sse42) printf(" SSE4.2");
	if (info.sse.sse4a) printf(" SSE4a");
}
void printAVX(ref CPUINFO info) {
	printf(" AVX");
	if (info.avx.avx2) printf(" AVX2");
	if (info.avx.avx512f) {
		printf(" AVX512F");
		if (info.avx.avx512er) printf(" +ER");
		if (info.avx.avx512pf) printf(" +PF");
		if (info.avx.avx512cd) printf(" +CD");
		if (info.avx.avx512dq) printf(" +DQ");
		if (info.avx.avx512bw) printf(" +BW");
		if (info.avx.avx512vl) printf(" +VL");
		if (info.avx.avx512_ifma) printf(" +IFMA");
		if (info.avx.avx512_vbmi) printf(" +VBMI");
		if (info.avx.avx512_4vnniw) printf(" +4VNNIW");
		if (info.avx.avx512_4fmaps) printf(" +4FMAPS");
		if (info.avx.avx512_vbmi2) printf(" +VBMI2");
		if (info.avx.avx512_gfni) printf(" +GFNI");
		if (info.avx.avx512_vaes) printf(" +VAES");
		if (info.avx.avx512_vnni) printf(" +VNNI");
		if (info.avx.avx512_bitalg) printf(" +BITALG");
		if (info.avx.avx512_bf16) printf(" +BF16");
		if (info.avx.avx512_vp2intersect) printf(" +VP2INTERSECT");
	}
	if (info.extensions.xop) printf(" XOP");
}
void printFMA(ref CPUINFO info) {
	if (info.extensions.fma3) printf(" FMA3");
	if (info.extensions.fma4) printf(" FMA4");
}
void printAMX(ref CPUINFO info) {
	printf(" AMX");
	if (info.amx.bf16) printf(" +BF16");
	if (info.amx.int8) printf(" +INT8");
	if (info.amx.xtilecfg) printf(" +XTILECFG");
	if (info.amx.xtiledata) printf(" +XTILEDATA");
	if (info.amx.xfd) printf(" +XFD");
}
void printOthers(ref CPUINFO info) {
	if (info.extensions.aes_ni) printf(" AES-NI");
	if (info.extensions.adx) printf(" ADX");
	if (info.extensions.sha) printf(" SHA");
	if (info.extensions.tbm) printf(" TBM");
	if (info.extensions.bmi1) printf(" BMI1");
	if (info.extensions.bmi2) printf(" BMI2");
	if (info.extensions.waitpkg) printf(" WAITPKG");
}
void printSecurity(ref CPUINFO info) {
	if (info.security.ibpb) printf(" IBPB");
	if (info.security.ibrs) printf(" IBRS");
	if (info.security.ibrsAlwaysOn) printf(" IBRS_ON");	// AMD
	if (info.security.ibrsPreferred) printf(" IBRS_PREF");	// AMD
	if (info.security.stibp) printf(" STIBP");
	if (info.security.stibpAlwaysOn) printf(" STIBP_ON");	// AMD
	if (info.security.ssbd) printf(" SSBD");
	if (info.security.l1dFlush) printf(" L1D_FLUSH");	// Intel
	if (info.security.md_clear) printf(" MD_CLEAR");	// Intel
	if (info.security.cetIbt) printf(" CET_IBT");	// Intel
	if (info.security.cetSs) printf(" CET_SS");	// Intel
}
void printCacheFeats(ushort feats) {
	if (feats & BIT!(0)) printf(" SI"); // Self Initiative
	if (feats & BIT!(1)) printf(" FA"); // Fully Associative
	if (feats & BIT!(2)) printf(" NWBV"); // No Write-Back Validation
	if (feats & BIT!(3)) printf(" CI"); // Cache Inclusive
	if (feats & BIT!(4)) printf(" CCI"); // Complex Cache Indexing
}

//TODO: --no-header for -c/--cpuid
version (unittest) {} else
int main(int argc, const(char) **argv) {
	options_t options;	/// Command-line options
	
	const(char) *arg = void;
	for (int argi = 1; argi < argc; ++argi) {
		if (argv[argi][1] == '-') { // Long arguments
			arg = argv[argi] + 2;
			if (strcmp(arg, "table") == 0) {
				options.table = true;
				continue;
			}
			if (strcmp(arg, "level") == 0) {
				options.getLevel = true;
				continue;
			}
			if (strcmp(arg, "details") == 0) {
				options.getDetails = true;
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
				case 'd': options.getDetails = true; continue;
				case 'l': options.getLevel = true; continue;
				case 'o': options.override_ = true; continue;
				case 'r': options.table = true; continue;
				case 'S':
					if (++argi >= argc) {
						puts("Missing parameter: leaf");
						return 1;
					}
					options.hasLevel = sscanf(argv[argi], "%i", &options.maxLevel) == 1;
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
					if (sscanf(argv[argi], "%i", &options.maxSub) != 1) {
						puts("Could not parse sub-level (-s)");
						return 2;
					}
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
	
	if (options.override_ == false) {
		getLeaves(info);
	} else {
		info.maxLeaf = MAX_LEAF;
		info.maxLeafVirt = MAX_VLEAF;
		info.maxLeafExtended = MAX_ELEAF;
	}
	
	if (options.table) {
		uint l = void, s = void;
		
		puts(
		"| Leaf     | Sub-leaf | EAX      | EBX      | ECX      | EDX      |\n"~
		"|----------|----------|----------|----------|----------|----------|"
		);
		
		if (options.hasLevel) {
			for (s = 0; s <= options.maxSub; ++s)
				outcpuid(options.maxLevel, s);
			return 0;
		}
		
		// Normal
		for (l = 0; l <= info.maxLeaf; ++l)
			for (s = 0; s <= options.maxSub; ++s)
				outcpuid(l, s);
		
		// Paravirtualization
		if (info.maxLeafVirt > 0x4000_0000)
		for (l = 0x4000_0000; l <= info.maxLeafVirt; ++l)
			for (s = 0; s <= options.maxSub; ++s)
				outcpuid(l, s);
		
		// Extended
		for (l = 0x8000_0000; l <= info.maxLeafExtended; ++l)
			for (s = 0; s <= options.maxSub; ++s)
				outcpuid(l, s);
		return 0;
	}
	
	getInfo(info);
	
	if (options.getLevel) {
		puts(baseline(info));
		return 0;
	}
	
	// NOTE: .ptr crash with GDC -O3
	//       glibc!__strlen_sse2 (in printf)
	char *vendorstr = cast(char*)info.vendor.string_;
	char *brandstr  = cast(char*)info.brandString;
	
	// Brand string left space trimming
	// Extremely common in Intel but let's also do it for others
	while (*brandstr == ' ') ++brandstr;
	
	CACHEINFO *cache = void;	/// Current cache level
	
	//
	// ANCHOR Summary
	//
	
	if (options.getDetails == false) {
		with (info) printf(
		"Name:        %.12s %.48s\n"~
		"Identifier:  Family 0x%x Model 0x%x Stepping 0x%x\n"~
		"Cores:       %u cores %u threads\n",
		vendorstr, brandstr,
		family, model, stepping,
		cores.physical, cores.logical,
		);
		
		if (info.memory.physBits || info.memory.lineBits) {
			uint maxPhys = void, maxLine = void;
			char cphys = adjustBits(maxPhys, info.memory.physBits);
			char cline = adjustBits(maxLine, info.memory.lineBits);
			with (info) printf(
			"Max. Memory: %u %ciB physical, %u %ciB virtual\n",
			maxPhys, cphys, maxLine, cline,
			);
		}
		
		with (info) printf(
		"Baseline:    %s\n"~
		"Techs:      ",
		baseline(info)
		);
		
		printTechs(info);
		
		immutable const(char) *none = " None";
		
		printf("\nSSE:        ");
		if (info.sse.sse) {
			printSSE(info);
			putchar('\n');
		} else puts(none);
		
		printf("AVX:        ");
		if (info.avx.avx) {
			printAVX(info);
			putchar('\n');
		} else puts(none);
		
		printf("AMX:        ");
		if (info.amx.enabled) {
			printAMX(info);
			putchar('\n');
		} else puts(none);
		
		printf("Others:     ");
		printLegacy(info);
		printOthers(info);
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
			printf("Cache L%u-%c:  %3ux %4g %ciB (%4g %ciB)",
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
	
	const(char) *tstr = void;
	
	printLegacy(info);
	if (info.sse.sse) printSSE(info);
	if (info.extensions.x86_64) {
		switch (info.vendor.id) with (Vendor) {
		case Intel:	tstr = " Intel64/x86-64"; break;
		case AMD:	tstr = " AMD64/x86-64"; break;
		default:	tstr = " x86-64";
		}
		printf(tstr);
		if (info.extensions.lahf64)
			printf(" +LAHF64");
	}
	if (info.virt.available)
		switch (info.vendor.id) with (Vendor) {
		case Intel: printf(" VT-x/VMX"); break;
		case AMD: // SVM
			printf(" AMD-V/VMX");
			if (info.virt.version_)
				printf(":v%u", info.virt.version_);
			break;
		case VIA: printf(" VIA-VT/VMX"); break;
		default: printf(" VMX");
		}
	if (info.avx.avx) printAVX(info);
	printFMA(info);
	printOthers(info);
	if (info.amx.enabled) printAMX(info);
	
	//
	// ANCHOR Extra/lone instructions
	//
	
	printf("\nExtra       :");
	if (info.extras.monitor) {
		printf(" MONITOR+MWAIT");
		if (info.extras.mwaitMin)
			printf(" +MIN=%u +MAX=%u",
				info.extras.mwaitMin, info.extras.mwaitMax);
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
		if (info.extras.rdtscDeadline)
			printf(" +TSC-Deadline");
		if (info.extras.rdtscInvariant)
			printf(" +TSC-Invariant");
	}
	if (info.extras.rdtscp) printf(" RDTSCP");
	if (info.extras.rdpid) printf(" RDPID");
	if (info.extras.cmov) {
		printf(" CMOV");
		if (info.extensions.fpu) printf(" FCOMI+FCMOV");
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
	printTechs(info);
	
	//
	// ANCHOR Cache information
	//
	
	printf("\nCache       :");
	if (info.cache.clflush)
		printf(" CLFLUSH=%uB", info.cache.clflushLinesize << 3);
	if (info.cache.clflushopt) printf(" CLFLUSHOPT");
	if (info.cache.cnxtId) printf(" CNXT-ID");
	if (info.cache.ss) printf(" SS");
	if (info.cache.prefetchw) printf(" PREFETCHW");
	if (info.cache.invpcid) printf(" INVPCID");
	if (info.cache.wbnoinvd) printf(" WBNOINVD");
	
	for (uint i; i < info.cache.levels; ++i) {
		cache = &info.cache.level[i];
		printf("\nLevel %u-%c   : %ux %5u KB, %u ways, %u parts, %u B, %u sets",
			cache.level, cache.type, cache.sharedCores, cache.size,
			cache.ways, cache.partitions, cache.lineSize, cache.sets
		);
		printCacheFeats(cache.features);
	}
	
	printf("\nSystem      :");
	if (info.sys.available) printf(" ACPI");
	if (info.sys.apic) printf(" APIC");
	if (info.sys.x2apic) printf(" x2APIC");
	if (info.sys.arat) printf(" ARAT");
	if (info.sys.tm) printf(" TM");
	if (info.sys.tm2) printf(" TM2");
	printf(" APIC-ID=%u", info.sys.apicId);
	if (info.sys.maxApicId) printf(" MAX-ID=%u", info.sys.maxApicId);
	
	printf("\nVirtual     :");
	if (info.virt.vme) printf(" VME");
	if (info.virt.apicv) printf(" APICv");
	
	// Paravirtualization
	if (info.virt.vendor.id) {
		// See vendor string case
		char *virtvendor = cast(char*)info.virt.vendor.string_;
		printf(" HOST=%.12s", virtvendor);
	}
	switch (info.virt.vendor.id) with (VirtVendor) {
	case VBoxMin:
		if (info.virt.vbox.tsc_freq_khz)
			printf(" TSC_FREQ_KHZ=%u", info.virt.vbox.tsc_freq_khz);
		if (info.virt.vbox.apic_freq_khz)
			printf(" APIC_FREQ_KHZ=%u", info.virt.vbox.apic_freq_khz);
		break;
	case HyperV:
		printf(" OPENSOURCE=%d VENDOR_ID=%d OS=%d MAJOR=%d MINOR=%d SERVICE=%d BUILD=%d",
			info.virt.hv.guest_opensource,
			info.virt.hv.guest_vendor_id,
			info.virt.hv.guest_os,
			info.virt.hv.guest_major,
			info.virt.hv.guest_minor,
			info.virt.hv.guest_service,
			info.virt.hv.guest_build);
		if (info.virt.hv.base_feat_vp_runtime_msr) printf(" HV_BASE_FEAT_VP_RUNTIME_MSR");
		if (info.virt.hv.base_feat_part_time_ref_count_msr) printf(" HV_BASE_FEAT_PART_TIME_REF_COUNT_MSR");
		if (info.virt.hv.base_feat_basic_synic_msrs) printf(" HV_BASE_FEAT_BASIC_SYNIC_MSRS");
		if (info.virt.hv.base_feat_stimer_msrs) printf(" HV_BASE_FEAT_STIMER_MSRS");
		if (info.virt.hv.base_feat_apic_access_msrs) printf(" HV_BASE_FEAT_APIC_ACCESS_MSRS");
		if (info.virt.hv.base_feat_hypercall_msrs) printf(" HV_BASE_FEAT_HYPERCALL_MSRS");
		if (info.virt.hv.base_feat_vp_id_msr) printf(" HV_BASE_FEAT_VP_ID_MSR");
		if (info.virt.hv.base_feat_virt_sys_reset_msr) printf(" HV_BASE_FEAT_VIRT_SYS_RESET_MSR");
		if (info.virt.hv.base_feat_stat_pages_msr) printf(" HV_BASE_FEAT_STAT_PAGES_MSR");
		if (info.virt.hv.base_feat_part_ref_tsc_msr) printf(" HV_BASE_FEAT_PART_REF_TSC_MSR");
		if (info.virt.hv.base_feat_guest_idle_state_msr) printf(" HV_BASE_FEAT_GUEST_IDLE_STATE_MSR");
		if (info.virt.hv.base_feat_timer_freq_msrs) printf(" HV_BASE_FEAT_TIMER_FREQ_MSRS");
		if (info.virt.hv.base_feat_debug_msrs) printf(" HV_BASE_FEAT_DEBUG_MSRS");
		if (info.virt.hv.part_flags_create_part) printf(" HV_PART_FLAGS_CREATE_PART");
		if (info.virt.hv.part_flags_access_part_id) printf(" HV_PART_FLAGS_ACCESS_PART_ID");
		if (info.virt.hv.part_flags_access_memory_pool) printf(" HV_PART_FLAGS_ACCESS_MEMORY_POOL");
		if (info.virt.hv.part_flags_adjust_msg_buffers) printf(" HV_PART_FLAGS_ADJUST_MSG_BUFFERS");
		if (info.virt.hv.part_flags_post_msgs) printf(" HV_PART_FLAGS_POST_MSGS");
		if (info.virt.hv.part_flags_signal_events) printf(" HV_PART_FLAGS_SIGNAL_EVENTS");
		if (info.virt.hv.part_flags_create_port) printf(" HV_PART_FLAGS_CREATE_PORT");
		if (info.virt.hv.part_flags_connect_port) printf(" HV_PART_FLAGS_CONNECT_PORT");
		if (info.virt.hv.part_flags_access_stats) printf(" HV_PART_FLAGS_ACCESS_STATS");
		if (info.virt.hv.part_flags_debugging) printf(" HV_PART_FLAGS_DEBUGGING");
		if (info.virt.hv.part_flags_cpu_mgmt) printf(" HV_PART_FLAGS_CPU_MGMT");
		if (info.virt.hv.part_flags_cpu_profiler) printf(" HV_PART_FLAGS_CPU_PROFILER");
		if (info.virt.hv.part_flags_expanded_stack_walk) printf(" HV_PART_FLAGS_EXPANDED_STACK_WALK");
		if (info.virt.hv.part_flags_access_vsm) printf(" HV_PART_FLAGS_ACCESS_VSM");
		if (info.virt.hv.part_flags_access_vp_regs) printf(" HV_PART_FLAGS_ACCESS_VP_REGS");
		if (info.virt.hv.part_flags_extended_hypercalls) printf(" HV_PART_FLAGS_EXTENDED_HYPERCALLS");
		if (info.virt.hv.part_flags_start_vp) printf(" HV_PART_FLAGS_START_VP");
		if (info.virt.hv.pm_max_cpu_power_state_c0) printf(" HV_PM_MAX_CPU_POWER_STATE_C0");
		if (info.virt.hv.pm_max_cpu_power_state_c1) printf(" HV_PM_MAX_CPU_POWER_STATE_C1");
		if (info.virt.hv.pm_max_cpu_power_state_c2) printf(" HV_PM_MAX_CPU_POWER_STATE_C2");
		if (info.virt.hv.pm_max_cpu_power_state_c3) printf(" HV_PM_MAX_CPU_POWER_STATE_C3");
		if (info.virt.hv.pm_hpet_reqd_for_c3) printf(" HV_PM_HPET_REQD_FOR_C3");
		if (info.virt.hv.misc_feat_mwait) printf(" HV_MISC_FEAT_MWAIT");
		if (info.virt.hv.misc_feat_guest_debugging) printf(" HV_MISC_FEAT_GUEST_DEBUGGING");
		if (info.virt.hv.misc_feat_perf_mon) printf(" HV_MISC_FEAT_PERF_MON");
		if (info.virt.hv.misc_feat_pcpu_dyn_part_event) printf(" HV_MISC_FEAT_PCPU_DYN_PART_EVENT");
		if (info.virt.hv.misc_feat_xmm_hypercall_input) printf(" HV_MISC_FEAT_XMM_HYPERCALL_INPUT");
		if (info.virt.hv.misc_feat_guest_idle_state) printf(" HV_MISC_FEAT_GUEST_IDLE_STATE");
		if (info.virt.hv.misc_feat_hypervisor_sleep_state) printf(" HV_MISC_FEAT_HYPERVISOR_SLEEP_STATE");
		if (info.virt.hv.misc_feat_query_numa_distance) printf(" HV_MISC_FEAT_QUERY_NUMA_DISTANCE");
		if (info.virt.hv.misc_feat_timer_freq) printf(" HV_MISC_FEAT_TIMER_FREQ");
		if (info.virt.hv.misc_feat_inject_synmc_xcpt) printf(" HV_MISC_FEAT_INJECT_SYNMC_XCPT");
		if (info.virt.hv.misc_feat_guest_crash_msrs) printf(" HV_MISC_FEAT_GUEST_CRASH_MSRS");
		if (info.virt.hv.misc_feat_debug_msrs) printf(" HV_MISC_FEAT_DEBUG_MSRS");
		if (info.virt.hv.misc_feat_npiep1) printf(" HV_MISC_FEAT_NPIEP1");
		if (info.virt.hv.misc_feat_disable_hypervisor) printf(" HV_MISC_FEAT_DISABLE_HYPERVISOR");
		if (info.virt.hv.misc_feat_ext_gva_range_for_flush_va_list) printf(" HV_MISC_FEAT_EXT_GVA_RANGE_FOR_FLUSH_VA_LIST");
		if (info.virt.hv.misc_feat_hypercall_output_xmm) printf(" HV_MISC_FEAT_HYPERCALL_OUTPUT_XMM");
		if (info.virt.hv.misc_feat_sint_polling_mode) printf(" HV_MISC_FEAT_SINT_POLLING_MODE");
		if (info.virt.hv.misc_feat_hypercall_msr_lock) printf(" HV_MISC_FEAT_HYPERCALL_MSR_LOCK");
		if (info.virt.hv.misc_feat_use_direct_synth_msrs) printf(" HV_MISC_FEAT_USE_DIRECT_SYNTH_MSRS");
		if (info.virt.hv.hint_hypercall_for_process_switch) printf(" HV_HINT_HYPERCALL_FOR_PROCESS_SWITCH");
		if (info.virt.hv.hint_hypercall_for_tlb_flush) printf(" HV_HINT_HYPERCALL_FOR_TLB_FLUSH");
		if (info.virt.hv.hint_hypercall_for_tlb_shootdown) printf(" HV_HINT_HYPERCALL_FOR_TLB_SHOOTDOWN");
		if (info.virt.hv.hint_msr_for_apic_access) printf(" HV_HINT_MSR_FOR_APIC_ACCESS");
		if (info.virt.hv.hint_msr_for_sys_reset) printf(" HV_HINT_MSR_FOR_SYS_RESET");
		if (info.virt.hv.hint_relax_time_checks) printf(" HV_HINT_RELAX_TIME_CHECKS");
		if (info.virt.hv.hint_dma_remapping) printf(" HV_HINT_DMA_REMAPPING");
		if (info.virt.hv.hint_interrupt_remapping) printf(" HV_HINT_INTERRUPT_REMAPPING");
		if (info.virt.hv.hint_x2apic_msrs) printf(" HV_HINT_X2APIC_MSRS");
		if (info.virt.hv.hint_deprecate_auto_eoi) printf(" HV_HINT_DEPRECATE_AUTO_EOI");
		if (info.virt.hv.hint_synth_cluster_ipi_hypercall) printf(" HV_HINT_SYNTH_CLUSTER_IPI_HYPERCALL");
		if (info.virt.hv.hint_ex_proc_masks_interface) printf(" HV_HINT_EX_PROC_MASKS_INTERFACE");
		if (info.virt.hv.hint_nested_hyperv) printf(" HV_HINT_NESTED_HYPERV");
		if (info.virt.hv.hint_int_for_mbec_syscalls) printf(" HV_HINT_INT_FOR_MBEC_SYSCALLS");
		if (info.virt.hv.hint_nested_enlightened_vmcs_interface) printf(" HV_HINT_NESTED_ENLIGHTENED_VMCS_INTERFACE");
		if (info.virt.hv.host_feat_avic) printf(" HV_HOST_FEAT_AVIC");
		if (info.virt.hv.host_feat_msr_bitmap) printf(" HV_HOST_FEAT_MSR_BITMAP");
		if (info.virt.hv.host_feat_perf_counter) printf(" HV_HOST_FEAT_PERF_COUNTER");
		if (info.virt.hv.host_feat_nested_paging) printf(" HV_HOST_FEAT_NESTED_PAGING");
		if (info.virt.hv.host_feat_dma_remapping) printf(" HV_HOST_FEAT_DMA_REMAPPING");
		if (info.virt.hv.host_feat_interrupt_remapping) printf(" HV_HOST_FEAT_INTERRUPT_REMAPPING");
		if (info.virt.hv.host_feat_mem_patrol_scrubber) printf(" HV_HOST_FEAT_MEM_PATROL_SCRUBBER");
		if (info.virt.hv.host_feat_dma_prot_in_use) printf(" HV_HOST_FEAT_DMA_PROT_IN_USE");
		if (info.virt.hv.host_feat_hpet_requested) printf(" HV_HOST_FEAT_HPET_REQUESTED");
		if (info.virt.hv.host_feat_stimer_volatile) printf(" HV_HOST_FEAT_STIMER_VOLATILE");
		break;
	case VirtVendor.KVM:
		if (info.virt.kvm.feature_clocksource) printf(" KVM_FEATURE_CLOCKSOURCE");
		if (info.virt.kvm.feature_nop_io_delay) printf(" KVM_FEATURE_NOP_IO_DELAY");
		if (info.virt.kvm.feature_mmu_op) printf(" KVM_FEATURE_MMU_OP");
		if (info.virt.kvm.feature_clocksource2) printf(" KVM_FEATURE_CLOCKSOURCE2");
		if (info.virt.kvm.feature_async_pf) printf(" KVM_FEATURE_ASYNC_PF");
		if (info.virt.kvm.feature_steal_time) printf(" KVM_FEATURE_STEAL_TIME");
		if (info.virt.kvm.feature_pv_eoi) printf(" KVM_FEATURE_PV_EOI");
		if (info.virt.kvm.feature_pv_unhault) printf(" KVM_FEATURE_PV_UNHAULT");
		if (info.virt.kvm.feature_pv_tlb_flush) printf(" KVM_FEATURE_PV_TLB_FLUSH");
		if (info.virt.kvm.feature_async_pf_vmexit) printf(" KVM_FEATURE_ASYNC_PF_VMEXIT");
		if (info.virt.kvm.feature_pv_send_ipi) printf(" KVM_FEATURE_PV_SEND_IPI");
		if (info.virt.kvm.feature_pv_poll_control) printf(" KVM_FEATURE_PV_POLL_CONTROL");
		if (info.virt.kvm.feature_pv_sched_yield) printf(" KVM_FEATURE_PV_SCHED_YIELD");
		if (info.virt.kvm.feature_clocsource_stable_bit) printf(" KVM_FEATURE_CLOCSOURCE_STABLE_BIT");
		if (info.virt.kvm.hint_realtime) printf(" KVM_HINTS_REALTIME");
		break;
	default:
	}
	
	printf("\nMemory      :");
	
	if (info.memory.pae) printf(" PAE");
	if (info.memory.pse) printf(" PSE");
	if (info.memory.pse36) printf(" PSE-36");
	if (info.memory.page1gb) printf(" Page1GB");
	if (info.memory.nx) {
		switch (info.vendor.id) with (Vendor) {
		case Intel:	tstr = " Intel-XD/NX"; break;
		case AMD:	tstr = " AMD-EVP/NX"; break;
		default:	tstr = " NX";
		}
		printf(tstr);
	}
	if (info.memory.dca) printf(" DCA");
	if (info.memory.pat) printf(" PAT");
	if (info.memory.mtrr) printf(" MTRR");
	if (info.memory.pge) printf(" PGE");
	if (info.memory.smep) printf(" SMEP");
	if (info.memory.smap) printf(" SMAP");
	if (info.memory.pku) printf(" PKU");
	if (info.memory._5pl) printf(" 5PL");
	if (info.memory.fsrepmov) printf(" FSRM");
	if (info.memory.lam) printf(" LAM");
	
	with (info.memory)
	printf("\nPhysicalBits: %u\nLinearBits  : %u\nDebugging   :",
		physBits, lineBits);
	
	if (info.debugging.mca) printf(" MCA");
	if (info.debugging.mce) printf(" MCE");
	if (info.debugging.de) printf(" DE");
	if (info.debugging.ds) printf(" DS");
	if (info.debugging.dsCpl) printf(" DS-CPL");
	if (info.debugging.dtes64) printf(" DTES64");
	if (info.debugging.pdcm) printf(" PDCM");
	if (info.debugging.sdbg) printf(" SDBG");
	if (info.debugging.pbe) printf(" PBE");
	
	printf("\nSecurity    :");
	if (info.security.ia32_arch_capabilities) printf(" IA32_ARCH_CAPABILITIES");
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
	
	if (info.misc.xtpr) printf(" xTPR");
	if (info.misc.psn) printf(" PSN");
	if (info.misc.pcid) printf(" PCID");
	if (info.misc.fsgsbase) printf(" FSGSBASE");
	if (info.misc.uintr) printf(" UINTR");
	
	putchar('\n');
	
	return 0;
}
