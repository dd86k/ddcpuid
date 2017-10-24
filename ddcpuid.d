module ddcpuid;

import std.stdio : stderr, writef;
import std.getopt;
import std.string : strip;
import core.stdc.stdio : printf;

/// Version
enum VERSION = "0.5.2";

enum // Maximum supported leafs
    MAX_LEAF = 0x20, /// Maximum leaf with -o
    MAX_ELEAF = 0x80000020; /// Maximum extended leaf with -o

enum { // Vendor strings, only ones I've seen used are the first three
    VENDOR_INTEL     = "GenuineIntel", /// Intel
    VENDOR_AMD       = "AuthenticAMD", /// AMD
    VENDOR_VIA       = "VIA VIA VIA ", /// VIA
    VENDOR_CENTAUR   = "CentaurHauls", /// Centaur (VIA)
    VENDOR_TRANSMETA = "GenuineTMx86", /// Transmeta
    VENDOR_CYRIX     = "CyrixInstead", /// Cyrix
    VENDOR_NEXGEN    = "NexGenDriven", /// Nexgen
    VENDOR_UMC       = "UMC UMC UMC ", /// UMC
    VENDOR_SIS       = "SiS SiS SiS ", /// SiS
    VENDOR_NSC       = "Geode by NSC", /// Geode
    VENDOR_RISE      = "RiseRiseRise", /// Rise
    VENDOR_VORTEX    = "Vortex86 SoC", /// Vortex
    VENDOR_NS        = "Geode by NSC", /// National Semiconductor
    // Older vendor strings
    VENDOR_OLDAMD       = "AMDisbetter!", /// Early K5 AMD string
    VENDOR_OLDTRANSMETA = "TransmetaCPU", /// Old Transmeta string
    // Virtual Machines
    VENDOR_VMWARE       = "VMwareVMware", /// VMware
    VENDOR_XENHVM       = "XenVMMXenVMM", /// Xen VMM
    VENDOR_MICROSOFT_HV = "Microsoft Hv", /// Microsoft Hyper-V
    VENDOR_PARALLELS    = " lrpepyh  vr"  /// Parallels
}

enum : ubyte { // Vendor "IDs", more uniform than strings
    UNKNOWN = 0,
    ID_INTEL = 1,
    ID_AMD = 2,
    ID_VIA = 3
}
__gshared ubyte VendorID; /// Vendor "ID"

__gshared bool Raw; /// Raw
__gshared bool Details; /// Detailed output
__gshared bool Override; /// Override max leaf

int main(string[] args) {
    GetoptResult r;
	try {
		r = getopt(args,
            config.bundling, config.caseSensitive,
            "r|raw", "Only show Raw CPUID data.", &Raw,
            config.bundling, config.caseSensitive,
            "d|details", "Show more information.", &Details,
            config.bundling, config.caseSensitive,
			"o|override", "Override leafs to 20h each, useful with -r.", &Override,
            "v|version", "Print version information.", &PrintVersion);
	} catch (GetOptException ex) {
		stderr.writeln("Error: ", ex.msg);
        return 1;
	}

    if (r.helpWanted) {
        PrintHelp;
        printf("\nOption             Description\n");
        foreach (it; r.options) { // "custom" defaultGetoptPrinter
            writef("%*s, %-*s%s%s\n",
                4,  it.optShort,
                12, it.optLong,
                it.required ? "Required: " : " ",
                it.help);
        }
        return 0;
    }

    if (Raw) { // if Raw
        // Maximum leaf
        const uint maxl = Override ? MAX_LEAF : getHighestLeaf;
        // Maximum extended leaf
        const uint emaxl = Override ? MAX_ELEAF : getHighestExtendedLeaf;

        printf("|   Leaf   | S | EAX      | EBX      | ECX      | EDX      |\n");
        printf("|:--------:|:-:|:---------|:---------|:---------|:---------|\n");
        for (uint leaf; leaf <= maxl; ++leaf) 
            print_cpuid(leaf, 0);
        for (uint eleaf = 0x8000_0000; eleaf <= emaxl; ++eleaf)
            print_cpuid(eleaf, 0);
    } else {
        debug printf("[L%04d] Fetching info...", __LINE__);
        fetchInfo;

        printf("Vendor: %s\n", &VendorString[0]);
        printf("Model: %s\n", &ProcessorBrandString[0]);

        printf("Identifier: ");

        if (Details)
            printf(
                "Family %Xh [%Xh:%Xh] Model %Xh [%Xh:%Xh] Stepping %Xh\n",
                Family, BaseFamily, ExtendedFamily,
                Model, BaseModel, ExtendedModel, Stepping);
        else
            printf("Family %d Model %d Stepping %d\n",
                Family, Model, Stepping);

        printf("Extensions: \n  ");
        if (MMX) printf("MMX, ");
        if (MMXExt) printf("Extended MMX, ");
        if (_3DNow) printf("3DNow!, ");
        if (_3DNowExt) printf("3DNow!Ext, ");
        if (SSE) printf("SSE, ");
        if (SSE2) printf("SSE2, ");
        if (SSE3) printf("SSE3, ");
        if (SSSE3) printf("SSSE3, ");
        if (SSE41) printf("SSE4.1, ");
        if (SSE42) printf("SSE4.2, ");
        if (SSE4a) printf("SSE4a, ");
        if (LongMode)
            switch (VendorID) {
            case ID_INTEL: printf("Intel64, "); break;
            case ID_AMD: printf("AMD64, "); break;
            default: printf("x86-64, "); break;
            }
        if (Virt)
            switch (VendorID) {
            case ID_INTEL: printf("VT-x, "); break; // VMX
            case ID_AMD: printf("AMD-V, "); break; // SVM
            case ID_VIA: printf("VIA VT, "); break;
            default: printf("VMX, "); break;
            }
        if (NX)
            switch (VendorID) {
            case ID_INTEL: printf("Intel XD (NX), "); break;
            case ID_AMD  : printf("AMD EVP (NX), "); break;
            default          : printf("NX, "); break;
            }
        if (SMX) printf("Intel TXT (SMX), ");
        if (AES) printf("AES-NI, ");
        if (AVX) printf("AVX, ");
        if (AVX2) printf("AVX2, ");
        printf("\n");
        if (Details) {
            printf("Instructions: \n  [ ");
            if (MONITOR)
                printf("MONITOR/MWAIT, ");
            if (PCLMULQDQ)
                printf("PCLMULQDQ, ");
            if (CX8)
                printf("CMPXCHG8B, ");
            if (CMPXCHG16B)
                printf("CMPXCHG16B, ");
            if (MOVBE)
                printf("MOVBE, "); // Intel Atom and quite a few AMD processorss.
            if (RDRAND)
                printf("RDRAND, ");
            if (RDSEED)
                printf("RDSEED, ");
            if (MSR)
                printf("RDMSR/WRMSR, ");
            if (SEP)
                printf("SYSENTER/SYSEXIT, ");
            if (TSC) {
                printf("RDTSC");
                if (TscDeadline || TscInvariant) {
                    printf(" (");
                    if (TscDeadline)
                        printf("TSC-Deadline");
                    if (TscInvariant)
                        printf(", TSC-Invariant");
                    printf(")");
                }
                printf(", ");
            }
            if (CMOV)
                printf("CMOV, ");
            if (FPU && CMOV)
                printf("FCOMI/FCMOV, ");
            if (CLFSH)
                printf("CLFLUSH (%d bytes), ", CLFLUSHLineSize * 8);
            if (PREFETCHW)
                printf("PREFETCHW, ");
            if (LZCNT)
                printf("LZCNT, ");
            if (POPCNT)
                printf("POPCNT, ");
            if (XSAVE)
                printf("XSAVE/XRSTOR, ");
            if (OSXSAVE)
                printf("XSETBV/XGETBV, ");
            if (FXSR)
                printf("FXSAVE/FXRSTOR, ");
            if (FMA || FMA4) {
                printf("VFMADDx (FMA");
                if (FMA4) printf("4");
                printf("), ");
            }
            printf("]\n");
        }

        printf("\n");

        switch (VendorID) { // VENDOR SPECIFIC
        case ID_INTEL:
            printf("Enhanced SpeedStep(R) Technology: %s\n", B(EIST));
            printf("TurboBoost available: %s\n", B(TurboBoost));
            break;
        default: printf("\n");
        }

        if (Details) {
            printf("\n== Details ==\n\n");
            printf("Highest Leaf: %02XH | Extended: %02XH\n",
                MaximumLeaf, MaximumExtendedLeaf);

            printf("Type: ");
            final switch (ProcessorType) { // 2 bit value
            case 0b00: printf("Original OEM Processor\n"); break;
            case 0b01: printf("Intel OverDrive Processor\n"); break;
            case 0b10: printf("Dual processor\n"); break;
            case 0b11: printf("Intel reserved\n"); break;
            }

            printf("\nFPU\n");
            printf("  Floating Point Unit [FPU]: %s\n", B(FPU));
            printf("  16-bit conversion [F16]: %s\n", B(F16C));

            printf("\nAPCI\n");
            printf("  APCI: %s\n", B(APCI));
            printf("  APIC: %s (Initial ID: %d, Max: %d)\n",
                B(APIC), InitialAPICID, MaxIDs);
            printf("  x2APIC: %s\n", B(x2APIC));
            printf("  Thermal Monitor: %s\n", B(TM));
            printf("  Thermal Monitor 2: %s\n", B(TM2));

            printf("\nVirtualization\n");
            printf("  Virtual 8086 Mode Enhancements [VME]: %s\n", B(VME));

            printf("\nMemory and Paging\n");
            printf("  Page Size Extension [PAE]: %s\n", B(PAE));
            printf("  36-Bit Page Size Extension [PSE-36]: %s\n", B(PSE_36));
            printf("  1 GB Pages support [Page1GB]: %s\n", B(Page1GB));
            printf("  Direct Cache Access [DCA]: %s\n", B(DCA));
            printf("  Page Attribute Table [PAT]: %s\n", B(PAT));
            printf("  Memory Type Range Registers [MTRR]: %s\n", B(MTRR));
            printf("  Page Global Bit [PGE]: %s\n", B(PGE));
            printf("  64-bit DS Area [DTES64]: %s\n", B(DTES64));

            printf("\nDebugging\n");
            printf("  Machine Check Exception [MCE]: %s\n", B(MCE));
            printf("  Debugging Extensions [DE]: %s\n", B(DE));
            printf("  Debug Store [DS]: %s\n", B(DS));
            printf("  Debug Store CPL [DS-CPL]: %s\n", B(DS_CPL));
            printf("  Perfmon and Debug Capability [PDCM]: %s\n", B(PDCM));
            printf("  SDBG: %s\n", B(SDBG));

            printf("\n");
            printf("Other features\n");
            printf("  Brand Index: %d\n", BrandIndex);
            printf("  L1 Context ID [CNXT-ID]: %s\n", B(CNXT_ID));
            printf("  xTPR Update Control [xTPR]: %s\n", B(xTPR));
            printf("  Process-context identifiers [PCID]: %s\n", B(PCID));
            printf("  Machine Check Architecture [MCA]: %s\n", B(MCA));
            printf("  Processor Serial Number [PSN]: %s\n", B(PSN));
            printf("  Self Snoop [SS]: %s\n", B(SS));
            printf("  Pending Break Enable [PBE]: %s\n", B(PBE));
            printf("  Supervisor Mode Execution Protection [SMEP]: %s\n", B(SMEP));
            printf("  Bit manipulation groups: ");
            if (BMI1 || BMI2) {
                if (BMI1)
                    printf("BMI1");
                if (BMI2)
                    printf(", BMI2");
                printf("\n");
            } else
                printf("None\n");
        } // if (det)
    }

    return 0;
} // main

extern(C) void PrintHelp() {
    printf("CPUID magic.\n");
    printf("  Usage: ddcpuid [<options>]\n");
}

extern(C) void PrintVersion() {
    import core.stdc.stdlib : exit;
    printf("ddcpuid v%s\n", &VERSION[0]);
    printf("Copyright (c) dd86k 2016-2017\n");
    printf("License: MIT License <http://opensource.org/licenses/MIT>\n");
    printf("Project page: <https://github.com/dd86k/ddcpuid>\n");
    printf("Compiled %s at %s, using %s v%d.\n",
        &__FILE__[0], &__TIMESTAMP__[0], &__VENDOR__[0], __VERSION__);
    exit(0);
}

extern(C) immutable(char)* B(uint c) {
    return c ? "Yes\0" : "No\0";
}

extern(C) void print_cpuid(uint leaf, uint subl) @nogc nothrow {
    uint a, b, c, d;
    asm pure @nogc nothrow {
        mov EAX, leaf;
        mov ECX, subl;
        cpuid;
        mov a, EAX;
        mov b, EBX;
        mov c, ECX;
        mov d, EDX;
    }
    printf("| %8X | %X | %8X | %8X | %8X | %8X |\n", leaf, subl, a, b, c, d);
}

/*****************************
 * CPU INFO
 *****************************/

/// Fetch information and store it in class variables.
public void fetchInfo() {
    VendorString = getVendor[0..$-1]; // 0h->EBX:EDX:ECX
    ProcessorBrandString = strip(getProcessorBrandString);
    switch (VendorString) {
        case VENDOR_INTEL: VendorID = ID_INTEL; break;
        case VENDOR_AMD: VendorID = ID_AMD; break;
        case VENDOR_VIA: VendorID = ID_VIA; break;
        default:
    } // Otherwise I don't know man

    MaximumLeaf = getHighestLeaf(); // 0h.EAX
    MaximumExtendedLeaf = getHighestExtendedLeaf(); // 8000_0000h.EAX

    const uint max = Override ? MAX_LEAF : MaximumLeaf;
    const uint emax = Override ? MAX_ELEAF : MaximumExtendedLeaf;

    uint a, b, c, d; // EAX to EDX

    for (int leaf = 1; leaf <= max; ++leaf) {
        asm @nogc nothrow pure {
            mov EAX, leaf;
            mov ECX, 0;
            cpuid;
            mov a, EAX;
            mov b, EBX;
            mov c, ECX;
            mov d, EDX;
        }

        switch (leaf) {
        case 1:
            // EAX
            Stepping       = a & 0xF;        // EAX[3:0]
            BaseModel      = a >>  4 &  0xF; // EAX[7:4]
            BaseFamily     = a >>  8 &  0xF; // EAX[11:8]
            ProcessorType  = a >> 12 & 0b11; // EAX[13:12]
            ExtendedModel  = a >> 16 &  0xF; // EAX[19:16]
            ExtendedFamily = cast(ubyte)(a >> 20); // EAX[27:20]

            switch (VendorID) {
            case ID_INTEL:
                if (BaseFamily != 0)
                    Family = BaseFamily;
                else
                    Family = cast(ubyte)(ExtendedFamily + BaseFamily);

                if (BaseFamily == 6 || BaseFamily == 0)
                    Model = cast(ubyte)((ExtendedModel << 4) + BaseModel);
                else // DisplayModel = Model_ID;
                    Model = BaseModel;

                // ECX
                DTES64  = c & 4;
                DS_CPL  = c & 0x10;
                Virt    = c & 0x20;
                SMX     = c & 0x40;
                EIST    = c & 0x80;
                CNXT_ID = c & 0x400;
                SDBG    = c & 0x800;
                xTPR    = c & 0x4000;
                PDCM    = c & 0x8000;
                PCID    = c & 0x2_0000;
                DCA     = c & 0x4_0000;
                DS      = d & 0x20_0000;
                APCI    = d & 0x40_0000;
                SS      = d & 0x800_0000;
                TM      = d & 0x2000_0000;
                PBE     = d & 0x8000_0000;
                break;
            case ID_AMD:
                if (BaseFamily < 0xF) {
                    Family = BaseFamily;
                    Model = BaseModel;
                } else {
                    Family = cast(ubyte)(ExtendedFamily + BaseFamily);
                    Model = cast(ubyte)((ExtendedModel << 4) + BaseModel);
                }
                break;
                default:
            }

            // EBX
            BrandIndex      = cast(ubyte)(b);       // EBX[7:0]
            CLFLUSHLineSize = cast(ubyte)(b >> 8);  // EBX[15:8]
            MaxIDs          = cast(ubyte)(b >> 16); // EBX[23:16]
            InitialAPICID   = cast(ubyte)(b >> 24); // EBX[31:24]
            // ECX
            SSE3        = c & 1;
            PCLMULQDQ   = c & 2;
            MONITOR     = c & 8;
            TM2         = c & 0x100;
            SSSE3       = c & 0x200;
            FMA         = c & 0x1000;
            CMPXCHG16B  = c & 0x2000;
            SSE41       = c & 0x8_0000;
            SSE42       = c & 0x10_0000;
            x2APIC      = c & 0x20_0000;
            MOVBE       = c & 0x40_0000;
            POPCNT      = c & 0x80_0000;
            TscDeadline = c & 0x100_0000;
            AES         = c & 0x200_0000;
            XSAVE       = c & 0x400_0000;
            OSXSAVE     = c & 0x800_0000;
            AVX         = c & 0x1000_0000;
            F16C        = c & 0x2000_0000;
            RDRAND      = c & 0x4000_0000;
            // EDX
            FPU    = d & 1;
            VME    = d & 2;
            DE     = d & 4;
            PSE    = d & 8;
            TSC    = d & 0x10;
            MSR    = d & 0x20;
            PAE    = d & 0x40;
            MCE    = d & 0x80;
            CX8    = d & 0x100;
            APIC   = d & 0x200;
            SEP    = d & 0x800;
            MTRR   = d & 0x1000;
            PGE    = d & 0x2000;
            MCA    = d & 0x4000;
            CMOV   = d & 0x8000;
            PAT    = d & 0x1_0000;
            PSE_36 = d & 0x2_0000;
            PSN    = d & 0x4_0000;
            CLFSH  = d & 0x8_0000;
            MMX    = d & 0x80_0000;
            FXSR   = d & 0x100_0000;
            SSE    = d & 0x200_0000;
            SSE2   = d & 0x400_0000;
            HTT    = d & 0x1000_0000;
            break;

        case 6:
            switch (VendorID) {
            case ID_INTEL:
                TurboBoost = a & 2;
                break;
            default:
            }
            break;

        case 7:
            BMI1 = b & 8;
            AVX2 = b & 0x20;
            SMEP = b & 0x80;
            BMI2 = b & 0x100;
            RDSEED = b & 0x4_0000;
            break;

            default:
        }
    }
    
    /*
     * Extended CPUID leafs
     */

    for (int eleaf = 0x8000_0000; eleaf < emax; ++eleaf) {
        asm @nogc nothrow pure {
            mov EAX, eleaf;
            mov ECX, 0;
            cpuid;
            mov a, EAX;
            mov b, EBX;
            mov c, ECX;
            mov d, EDX;
        }

        switch (eleaf) {
        case 0x8000_0001:
            switch (VendorID) {
            case ID_AMD:
                Virt  = c & 4;// SVM
                SSE4a = c & 0x40;
                FMA4  = c & 0x1_0000;

                MMXExt    = d & 0x40_0000;
                _3DNowExt = d & 0x4000_0000;
                _3DNow    = d & 0x8000_0000;
                break;
            default:
            }

            LZCNT     = c & 0x20;
            PREFETCHW = c & 0x100;

            NX       = d & 0x10_0000;
            Page1GB  = d & 0x400_0000;
            LongMode = d & 0x2000_0000;
            break;

        case 0x8000_0007:
            switch (VendorID) {
            case ID_INTEL:
                RDSEED = b & 0x4_0000;
                break;
            case ID_AMD:
                TM = d & 0x10;
                break;
            default:
            }

            TscInvariant = d & 0x100;
            break;
        default:
        }
    }
}

/*
 * Properties
 */

// ---- Basic information ----
/// Processor vendor.
__gshared string VendorString;
/// Processor brand string.
__gshared string ProcessorBrandString;

/// Maximum leaf supported by this processor.
__gshared int MaximumLeaf;
/// Maximum extended leaf supported by this processor.
__gshared int MaximumExtendedLeaf;

/// Number of physical cores.
__gshared ushort NumberOfCores;
/// Number of logical cores.
__gshared ushort NumberOfThreads;

/// Processor family. ID and extended ID included.
__gshared ubyte Family;
/// Base Family ID
__gshared ubyte BaseFamily;
/// Extended Family ID
__gshared ubyte ExtendedFamily;
/// Processor model. ID and extended ID included.
__gshared ubyte Model;
/// Base Model ID
__gshared ubyte BaseModel;
/// Extended Model ID
__gshared ubyte ExtendedModel;
/// Processor stepping.
__gshared ubyte Stepping;
/// Processor type.
__gshared ubyte ProcessorType;

/// MMX Technology.
__gshared uint MMX;
/// AMD MMX Extented set.
__gshared uint MMXExt;
/// Streaming SIMD Extensions.
__gshared uint SSE;
/// Streaming SIMD Extensions 2.
__gshared uint SSE2;
/// Streaming SIMD Extensions 3.
__gshared uint SSE3;
/// Supplemental Streaming SIMD Extensions 3 (SSSE3).
__gshared uint SSSE3;
/// Streaming SIMD Extensions 4.1.
__gshared uint SSE41;
/// Streaming SIMD Extensions 4.2.
__gshared uint SSE42;
/// Streaming SIMD Extensions 4a. AMD only.
__gshared uint SSE4a;
/// AES instruction extensions.
__gshared uint AES;
/// AVX instruction extensions.
__gshared uint AVX;
/// AVX2 instruction extensions.
__gshared uint AVX2;

/// 3DNow! extension. AMD only. Deprecated in 2010.
__gshared uint _3DNow;
/// 3DNow! Extension supplements. See 3DNow!
__gshared uint _3DNowExt;

// ---- 01h ----
// -- EBX --
/// Brand index. See Table 3-24. If 0, use normal BrandString.
__gshared ubyte BrandIndex;
/// The CLFLUSH line size. Multiply by 8 to get its size in bytes.
__gshared ubyte CLFLUSHLineSize;
/// Maximum number of addressable IDs for logical processors in this physical package.
__gshared ubyte MaxIDs;
/// Initial APIC ID that the process started on.
__gshared ubyte InitialAPICID;
// -- ECX --
/// PCLMULQDQ instruction.
__gshared uint PCLMULQDQ; // 1
/// 64-bit DS Area (64-bit layout).
__gshared uint DTES64;
/// MONITOR/MWAIT.
__gshared uint MONITOR;
/// CPL Qualified Debug Store.
__gshared uint DS_CPL;
/// Virtualization | Virtual Machine eXtensions (Intel) | Secure Virtual Machine (AMD) 
__gshared uint Virt;
/// Safer Mode Extensions. Intel TXT/TPM
__gshared uint SMX;
/// Enhanced Intel SpeedStep® Technology.
__gshared uint EIST;
/// Thermal Monitor 2.
__gshared uint TM2;
/// L1 Context ID.
__gshared uint CNXT_ID;
/// Indicates the processor supports IA32_DEBUG_INTERFACE MSR for silicon debug.
__gshared uint SDBG;
/// FMA extensions using YMM state.
__gshared uint FMA;
/// Four-operand FMA instruction support.
__gshared uint FMA4;
/// CMPXCHG16B instruction.
__gshared uint CMPXCHG16B;
/// xTPR Update Control.
__gshared uint xTPR;
/// Perfmon and Debug Capability.
__gshared uint PDCM;
/// Process-context identifiers.
__gshared uint PCID;
/// Direct Cache Access.
__gshared uint DCA;
/// x2APIC feature (Intel programmable interrupt controller).
__gshared uint x2APIC;
/// MOVBE instruction.
__gshared uint MOVBE;
/// POPCNT instruction.
__gshared uint POPCNT;
/// Indicates if the APIC timer supports one-shot operation using a TSC deadline value.
__gshared uint TscDeadline;
/// Indicates the support of the XSAVE/XRSTOR extended states feature, XSETBV/XGETBV instructions, and XCR0.
__gshared uint XSAVE;
/// Indicates if the OS has set CR4.OSXSAVE[18] to enable XSETBV/XGETBV instructions for XCR0 and XSAVE.
__gshared uint OSXSAVE;
/// 16-bit floating-point conversion instructions.
__gshared uint F16C;
/// RDRAND instruction.
__gshared uint RDRAND; // 30
// -- EDX --
/// Floating Point Unit On-Chip. The processor contains an x87 FPU.
__gshared uint FPU; // 0
/// Virtual 8086 Mode Enhancements.
__gshared uint VME;
/// Debugging Extensions.
__gshared uint DE;
/// Page Size Extension.
__gshared uint PSE;
/// Time Stamp Counter.
__gshared uint TSC;
/// Model Specific Registers RDMSR and WRMSR Instructions. 
__gshared uint MSR;
/// Physical Address Extension.
__gshared uint PAE;
/// Machine Check Exception.
__gshared uint MCE;
/// CMPXCHG8B Instruction.
__gshared uint CX8;
/// Indicates if the processor contains an Advanced Programmable Interrupt Controller.
__gshared uint APIC;
/// SYSENTER and SYSEXIT Instructions.
__gshared uint SEP;
/// Memory Type Range Registers.
__gshared uint MTRR;
/// Page Global Bit.
__gshared uint PGE;
/// Machine Check Architecture.
__gshared uint MCA;
/// Conditional Move Instructions.
__gshared uint CMOV;
/// Page Attribute Table.
__gshared uint PAT;
/// 36-Bit Page Size Extension.
__gshared uint PSE_36;
/// Processor Serial Number. Only Pentium 3 used this.
__gshared uint PSN;
/// CLFLUSH Instruction.
__gshared uint CLFSH;
/// Debug Store.
__gshared uint DS;
/// Thermal Monitor and Software Controlled Clock Facilities.
__gshared uint APCI;
/// FXSAVE and FXRSTOR Instructions.
__gshared uint FXSR;
/// Self Snoop.
__gshared uint SS;
/// Max APIC IDs reserved field is Valid. 0 if only unicore.
__gshared uint HTT;
/// Thermal Monitor.
__gshared uint TM;
/// Pending Break Enable.
__gshared uint PBE; // 31

// ---- 06h ----
/// Turbo Boost Technology (Intel)
__gshared uint TurboBoost;


// ---- 07h ----
// -- EBX --
// Note: BMI1, BMI2, and SMEP were introduced in 4th Generation Core processors.
/// Bit manipulation group 1 instruction support.
__gshared uint BMI1; // 3
/// Supervisor Mode Execution Protection.
__gshared uint SMEP; // 7
/// Bit manipulation group 2 instruction support.
__gshared uint BMI2; // 8

// ---- 8000_0001 ----
// ECX
/// Advanced Bit Manipulation under AMD. LZCUNT under Intel.
__gshared uint LZCNT;
/// PREFETCHW under Intel. 3DNowPrefetch under AMD.
__gshared uint PREFETCHW; // 8

/// RDSEED instruction
__gshared uint RDSEED;
// EDX
/// Intel: Execute Disable Bit. AMD: No-execute page protection.
__gshared uint NX; // 20
/// 1GB Pages
__gshared uint Page1GB; // 26
/// Also known as Intel64 or AMD64.
__gshared uint LongMode; // 29

// ---- 8000_0007 ----
/// TSC Invariation support
__gshared uint TscInvariant; // 8

/// Get the maximum leaf.
/// Returns: Maximum leaf
extern (C) uint getHighestLeaf() {
    asm { naked;
        mov EAX, 0;
        cpuid;
        ret;
    }
}

/// Get the maximum extended leaf.
/// Returns: Maximum extended leaf
extern (C) uint getHighestExtendedLeaf() {
    asm { naked;
        mov EAX, 0x8000_0000;
        cpuid;
        ret;
    }
}

/// Gets the CPU Vendor string.
/// Returns: Vendor string
string getVendor() {
    char[13] s;
    version (X86_64) asm pure @nogc nothrow {
        lea RDI, s;
        mov EAX, 0;
        cpuid;
        mov [RDI  ], EBX;
        mov [RDI+4], EDX;
        mov [RDI+8], ECX;
        mov byte ptr [RDI+12], 0;
    } else asm pure @nogc nothrow {
        lea EDI, s;
        mov EAX, 0;
        cpuid;
        mov [EDI  ], EBX;
        mov [EDI+4], EDX;
        mov [EDI+8], ECX;
        mov byte ptr [EDI+12], 0;
    }
    return s.idup;
}

/// Get the Extended Processor Brand string
/// Returns: Processor Brand string
string getProcessorBrandString() { //TODO: Check older list?
    char[48] s;
    version (X86_64) asm pure @nogc nothrow {
        lea RDI, s;
        mov EAX, 0x8000_0002;
        cpuid;
        mov [RDI   ], EAX;
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
    } else asm pure @nogc nothrow {
        lea EDI, s;
        mov EAX, 0x8000_0002;
        cpuid;
        mov [EDI   ], EAX;
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
    return s.idup;
}

/*string getSocVendorIntel()
{
    char[16] c;
    asm { naked;
        mov EAX, 0;
        cpuid;
        cmp EAX, 0x17;
        jge INTEL_S;
        mov AX, -2;
        ret;
    }
    version (X86) asm {
INTEL_S:
        lea EDI, c;
        mov [EDI], EAX;
        mov [EDI+4], EBX;
        mov [EDI+8], ECX;
        mov [EDI+12], EDX;
    } else version (X86_64) asm {
INTEL_S:
        lea RDI, c;
        mov [RDI], EAX;
        mov [RDI+4], EBX;
        mov [RDI+8], ECX;
        mov [RDI+12], EDX;
    }
    return c.idup;
}*/

/**
 * Get the number of logical cores for an Intel processor.
 * Returns:
 *   The number of logical cores.
 * Errorcodes:
 *   -2 = Feature not supported.
 */
/*extern (C) short getCoresIntel() {
    asm pure @nogc nothrow { naked;
        mov EAX, 0;
        cpuid;
        cmp EAX, 0xB;
        jge INTEL_S;
        mov AX, -2; //TODO: go accross NUMA nodes instead
        ret;
INTEL_S:
        mov EAX, 0xB;
        mov ECX, 1;
        cpuid;
        mov AX, BX;
        ret;
    }
}*/