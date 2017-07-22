module ddcpuid;

import std.getopt;
import std.stdio;
import std.string : strip;

/// Version
enum VERSION = "0.4.0";

enum // Maximum supported leafs
    MAX_LEAF = 0x20, /// Maximum leaf with -o
    MAX_ELEAF = 0x8000_0020; /// Maximum extended leaf with -o

enum { // Vendor strings
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
    VENDOR_PARALLELS    = " lrpepyh vr"   /// Parallels
}

/**
 * Starting point.
 * Params: args = CLI Arguments
 * Returns: Error code.
 */
int main(string[] args)
{
    bool pre; /// Pretty
    bool raw; /// Raw
    bool det; /// Detailed output
    bool ovr; /// Override max leaf

    GetoptResult r;
	try {
		r = getopt(args,
            config.bundling, config.caseSensitive,
            "r|raw", "Only show raw CPUID data.", &raw,
            config.bundling, config.caseSensitive,
            "d|details", "Show more information.", &det,
            config.bundling, config.caseSensitive,
			"o|override", "Override leafs to 20h each, useful with -r.", &ovr,
            config.bundling, config.caseSensitive,
			"p|pretty", "Pretty up the output to be more readable.", &pre,
            "v|version", "Print version information.", &PrintVersion);
	} catch (GetOptException ex) {
		stderr.writeln("Error: ", ex.msg);
        return 1;
	}

    if (r.helpWanted) {
        PrintHelp;
        writeln("\nOption             Description");
        foreach (it; r.options) { // "custom" defaultGetoptPrinter
            writefln("%*s, %-*s%s%s",
                4,  it.optShort,
                12, it.optLong,
                it.required ? "Required: " : " ",
                it.help);
        }
        return 0;
    }

    if (raw)
    {
        // Maximum leaf
        const uint maxl = ovr ? MAX_LEAF : getHighestLeaf();
        // Maximum extended leaf
        const uint emaxl = ovr ? MAX_ELEAF : getHighestExtendedLeaf();

        debug
        writefln("[%4d] Max leaf: %X | Extended: %X", __LINE__, maxl, emaxl);

        writeln("|   Leaf   | S | EAX      | EBX      | ECX      | EDX      |");
        writeln("|:--------:|:-:|:---------|:---------|:---------|:---------| ");
        for (uint leaf = 0; leaf <= maxl; ++leaf)
            print_cpuid(leaf, 0);
        for (uint eleaf = 0x8000_0000; eleaf <= emaxl; ++eleaf)
            print_cpuid(eleaf, 0);
    }
    else
    {
        import core.stdc.string : memset;
        //TODO: Improve this section someday
        enum W = 52;
        enum LINE = "+--------------+------------------------------------------------------+";
        enum E    = "+---------------------------------------------------------------------+";

        debug writeln("[L%04d] Fetching info...", __LINE__);
        CpuInfo ci; ci.fetchInfo;

        with (ci)
        if (pre)
        {
            void printl() { writeln(LINE); }
            printl;
            writefln("| %s | %-*s |",
                VendorString, W, ProcessorBrandString);

            printl;
            writefln("| Identifier   | %-*s |", W, getIden(det));

            printl;
            enum Y = 'x', N = ' ';
            // I know this isn't the best code around but it's.. One way to do things. Sorry.
            // I'm lazy
            writefln(
            "| Extensions   | MMX[%c] Extended MMX[%c] 3DNow![%c] Extended 3DNow![%c]  |\n"~
            "|              | SSE[%c] SSE2[%c] SSE3[%c] SSSE3[%c]  x86-64[%c]           |\n"~
            "|              | SSE4.1[%c] SSE4.2[%c] SSE4a[%c]  VMX[%c]  SMX[%c]  NX[%c]  |\n"~
            "|              | AES-NI[%c] AVX[%c] AVX2[%c]                             |",
                MMX ? Y : N, MMXExt ? Y : N, _3DNow ? Y : N, _3DNowExt ? Y : N,
                SSE ? Y : N, SSE2 ? Y : N, SSE3 ? Y : N, SSSE3 ? Y : N, LongMode ? Y : N,
                SSE41 ? Y : N, SSE42 ? Y : N, SSE4a ? Y : N, Virt ? Y : N, SMX ? Y : N,
                    NX ? Y : N,
                SSE41 ? Y : N, SSE42 ? Y : N, SSE4a ? Y : N);

            if (det) {
            printl;
            writefln(
            "| Instructions | MONITOR/MWAIT[%c]  PCLMULQDQ[%c]  SYSENTER/SYSEXIT[%c]  |\n"~
            "|              | CMPXCHG8B[%c]  CMPXCHG16B[%c]  RDRAND[%c]  RDSEED[%c]    |\n"~
            "|              | CMOV[%c]  FCOMI/FCMOV[%c]  MOVBE[%c]                    |\n"~
            "|              | RDTSC[%c]  TSC-Deadline[%c]  TSC-Invariant[%c]          |\n"~
            "|              | LZCNT[%c]  POPCNT[%c]  RDMSR/WRMSR[%c]                  |\n"~
            "|              | XSAVE/XRSTOR[%c]  XSETBV/XGETBV[%c]  FXSAVE/FXRSTOR[%c] |\n"~
            "|              | VFMADDx (FMA)[%c] (FMA4)[%c]                           |",
                MONITOR ? Y : N, PCLMULQDQ ? Y : N, SEP ? Y : N,
                CX8 ? Y : N, CMPXCHG16B ? Y : N, RDRAND ? Y : N, RDSEED ? Y : N,
                CMOV ? Y : N, (FPU && CMOV)? Y : N, MOVBE ? Y : N,
                TSC ? Y : N, TscDeadline ? Y : N, TscInvariant ? Y : N,
                LZCNT ? Y : N, POPCNT ? Y : N, MSR ? Y : N,
                XSAVE ? Y : N, OSXSAVE ? Y : N, FXSR ? Y : N,
                FMA ? Y : N, FMA4 ? Y : N);
            printl;

            void printc(string c) {
                writeln(E);
                writefln("| %*s |", 67, c);
            }
            void printn(string n) {
                writefln("| %-*s |", 67, n);
            }
            writefln("| Highest Leaf: %02XH | Extended: %08XH                             |",
                MaximumLeaf, MaximumExtendedLeaf);
            final switch (ProcessorType) // 2 bit value
            { // Should return 0 nowadays.
            case 0b00: printn("Type: Original OEM Processor"); break;
            case 0b01: printn("Type: Intel OverDrive Processor"); break;
            case 0b10: printn("Type: Dual processor"); break;
            case 0b11: printn("Type: Intel reserved"); break;
            }

            printc("FPU");
            if (FPU) {
                printn("FPU Present [FPU]");
                printn("16-bit conversion [F16C]");
            }

            printc("APCI");
            if (APIC)
                printn("APIC [APIC]");
            if (x2APIC)
                printn("x2APIC [x2APIC]");
            if (TM)
                printn("Thermal Monitor [TM]");
            if (TM2)
                printn("Thermal Monitor 2 [TM2]");

            printc("Virtualization");
            if (Virt) {
                switch (VendorString)
                {
                case VENDOR_INTEL: printn("VT-x"); break; // VMX
                case VENDOR_AMD  : printn("AMD-V"); break; // SVM
                case VENDOR_VIA  : printn("VIA VT"); break;
                default          : printn("VMX"); break;
                }
                printn("Virtual 8086 Mode Enhancements [VME]",);
            }

            printc("Memory and Paging");
            if (PAE)
                printn("Page Size Extension [PAE]");
            if (PSE_36)
                printn("36-Bit Page Size Extension [PSE-36]");
            if (Page1GB)
                printn("1 GB Pages support [Page1GB]");
            if (DCA)
                printn("Direct Cache Access [DCA]");
            if (PAT)
                printn("Page Attribute Table [PAT]");
            if (MTRR)
                printn("Memory Type Range Registers [MTRR]");
            if (PGE)
                printn("Page Global Bit [PGE]");
            if (DTES64)
                printn("64-bit DS Area [DTES64]");

            printc("Debugging");
            if (MCE)
                printn("Machine Check Exception [MCE]");
            if (DE)
                printn("Debugging Extensions [DE]");
            if (DS)
                printn("Debug Store [DS]");
            if (DS_CPL)
                printn("Debug Store CPL [DS-CPL]");
            if (PDCM)
                printn("Perfmon and Debug Capability [PDCM]");
            if (SDBG)
                printn("SDBG");

            printc("Other features");
            if (CNXT_ID)
                printn("L1 Context ID [CNXT-ID]");
            if (xTPR)
                printn("xTPR Update Control [xTPR]");
            if (PCID)
                printn("Process-context identifiers [PCID]");
            if (MCA)
                printn("Machine Check Architecture [MCA]");
            if (PSN)
                printn("Processor Serial Number [PSN]");
            if (SS)
                printn("Self Snoop [SS]");
            if (PBE)
                printn("Pending Break Enable [PBE]");
            if (SMEP)
                printn("Supervisor Mode Execution Protection [SMEP]");
            if (BMI1)
                printn("Bit Manipulation Instructions 1 [BMI1]");
            if (BMI2)
                printn("Bit Manipulation Instructions 1 [BMI2]");
            } // if (det)

            writeln(E);
        }
        else
        {
            writeln("Vendor: ", VendorString);
            writeln("Model: ", ProcessorBrandString);

            write("Identifier: ");
            writeln(getIden(det));

            write("Extensions: \n  ");
            if (MMX) write("MMX, ");
            if (MMXExt) write("Extended MMX, ");
            if (_3DNow) write("3DNow!, ");
            if (_3DNowExt) write("3DNow!Ext, ");
            if (SSE) write("SSE, ");
            if (SSE2) write("SSE2, ");
            if (SSE3) write("SSE3, ");
            if (SSSE3) write("SSSE3, ");
            if (SSE41) write("SSE4.1, ");
            if (SSE42) write("SSE4.2, ");
            if (SSE4a) write("SSE4a, ");
            if (LongMode)
                switch (VendorString)
                {
                case VENDOR_INTEL: write("Intel64, "); break;
                case VENDOR_AMD  : write("AMD64, "); break;
                default          : write("x86-64, "); break;
                }
            if (Virt)
                switch (VendorString)
                {
                case VENDOR_INTEL: write("VT-x, "); break; // VMX
                case VENDOR_AMD  : write("AMD-V, "); break; // SVM
                case VENDOR_VIA  : write("VIA VT, "); break;
                default          : write("VMX, "); break;
                }
            if (SMX) write("Intel TXT (SMX), ");
            if (NX)
                switch (VendorString)
                {
                case VENDOR_INTEL: write("Intel XD (NX), "); break;
                case VENDOR_AMD  : write("AMD EVP (NX), "); break;
                default          : write("NX, "); break;
                }
            if (AES) write("AES-NI, ");
            if (AVX) write("AVX, ");
            if (AVX2) write("AVX2, ");
            writeln();
            if (det)
            {
                write("Instructions: \n  [ ");
                if (MONITOR)
                    write("MONITOR/MWAIT, ");
                if (PCLMULQDQ)
                    write("PCLMULQDQ, ");
                if (CX8)
                    write("CMPXCHG8B, ");
                if (CMPXCHG16B)
                    write("CMPXCHG16B, ");
                if (MOVBE)
                    write("MOVBE, "); // Intel Atom and quite a few AMD processorss.
                if (RDRAND)
                    write("RDRAND, ");
                if (RDSEED)
                    write("RDSEED, ");
                if (MSR)
                    write("RDMSR/WRMSR, ");
                if (SEP)
                    write("SYSENTER/SYSEXIT, ");
                if (TSC)
                {
                    write("RDTSC");
                    if (TscDeadline || TscInvariant)
                    {
                        write(" (");
                        if (TscDeadline)
                            write("TSC-Deadline");
                        if (TscInvariant)
                            write(", TSC-Invariant");
                        write(")");
                    }
                    write(", ");
                }
                if (CMOV)
                    write("CMOV, ");
                if (FPU && CMOV)
                    write("FCOMI/FCMOV, ");
                if (CLFSH)
                    writef("CLFLUSH (%d bytes), ", CLFLUSHLineSize * 8);
                if (PREFETCHW)
                    write("PREFETCHW, ");
                if (LZCNT)
                    write("LZCNT, ");
                if (POPCNT)
                    write("POPCNT, ");
                if (XSAVE)
                    write("XSAVE/XRSTOR, ");
                if (OSXSAVE)
                    write("XSETBV/XGETBV, ");
                if (FXSR)
                    write("FXSAVE/FXRSTOR, ");
                if (FMA || FMA4)
                {
                    write("VFMADDx (FMA");
                    if (FMA4) write("4");
                    write("), ");
                }
                writeln("]");
            }

            writeln;

            switch (VendorString) // VENDOR SPECIFIC
            {
            case VENDOR_INTEL:
                writeln("Enhanced SpeedStep(R) Technology: ", EIST);
                writeln("TurboBoost available: ", TurboBoost);
                break;
            default:
            }

            if (det)
            {
                writefln("Highest Leaf: %02XH | Extended: %02XH",
                    MaximumLeaf, MaximumExtendedLeaf);
                write("Type: ");
                final switch (ProcessorType) // 2 bit value
                { // Should return 0 nowadays.
                case 0b00: writeln("Original OEM Processor"); break;
                case 0b01: writeln("Intel OverDrive Processor"); break;
                case 0b10: writeln("Dual processor"); break;
                case 0b11: writeln("Intel reserved"); break;
                }

                writeln();
                writeln("FPU");
                writeln("  Floating Point Unit [FPU]: ", FPU);
                writeln("  16-bit conversion [F16]: ", F16C);

                writeln();
                writeln("APCI");
                writeln("  APCI: ", APCI);
                writefln("  APIC: %s (Initial ID: %d, Max: %d)", APIC, InitialAPICID, MaxIDs);
                writeln("  x2APIC: ", x2APIC);
                writeln("  Thermal Monitor: ", TM);
                writeln("  Thermal Monitor 2: ", TM2);

                writeln();
                writeln("Virtualization");
                writeln("  Virtual 8086 Mode Enhancements [VME]: ", VME);

                writeln();
                writeln("Memory and Paging");
                writeln("  Page Size Extension [PAE]: ", PAE);
                writeln("  36-Bit Page Size Extension [PSE-36]: ", PSE_36);
                writeln("  1 GB Pages support [Page1GB]: ", Page1GB);
                writeln("  Direct Cache Access [DCA]: ", DCA);
                writeln("  Page Attribute Table [PAT]: ", PAT);
                writeln("  Memory Type Range Registers [MTRR]: ", MTRR);
                writeln("  Page Global Bit [PGE]: ", PGE);
                writeln("  64-bit DS Area [DTES64]: ", DTES64);

                writeln();
                writeln("Debugging");
                writeln("  Machine Check Exception [MCE]: ", MCE);
                writeln("  Debugging Extensions [DE]: ", DE);
                writeln("  Debug Store [DS]: ", DS);
                writeln("  Debug Store CPL [DS-CPL]: ", DS_CPL);
                writeln("  Perfmon and Debug Capability [PDCM]: ", PDCM);
                writeln("  SDBG: ", SDBG);

                writeln();
                writeln("Other features");
                writeln("  Brand Index: ", BrandIndex);
                writeln("  L1 Context ID [CNXT-ID]: ", CNXT_ID);
                writeln("  xTPR Update Control [xTPR]: ", xTPR);
                writeln("  Process-context identifiers [PCID]: ", PCID);
                writeln("  Machine Check Architecture [MCA]: ", MCA);
                writeln("  Processor Serial Number [PSN]: ", PSN);
                writeln("  Self Snoop [SS]: ", SS);
                writeln("  Pending Break Enable [PBE]: ", PBE);
                writeln("  Supervisor Mode Execution Protection [SMEP]: ", SMEP);
                write("  Bit manipulation groups: ");
                if (BMI1 || BMI2)
                {
                    if (BMI1)
                        write("BMI1");
                    if (BMI2)
                        write(", BMI2");
                    writeln();
                }
                else
                    writeln("None");
            } // if (det)
        }
    }

    return 0;
} // main

/// Print description and sinopsys
void PrintHelp()
{
    writeln("CPUID magic.");
    writeln("  Usage: ddcpuid [<Options>]");
}

/// Print version and exits.
void PrintVersion()
{
    import core.stdc.stdlib : exit;
    writeln("ddcpuid v", VERSION);
    writeln("Copyright (c) dd86k 2016-2017");
    writeln("License: MIT License <http://opensource.org/licenses/MIT>");
    writeln("Project page: <https://github.com/dd86k/ddcpuid>");
    writefln("Compiled %s at %s, using %s version %s.",
        __FILE__, __TIMESTAMP__, __VENDOR__, __VERSION__);
    exit(0);
}

/// public CpuInfo object
CpuInfo ci;

/**
 * Get identifier string from ci object.
 * Params: more = More details
 * Returns: Identifier string
 */
string getIden(bool more)
{
    import std.format : format;
    with (ci)
    if (more)
        return format(
            "Family %Xh [%Xh:%Xh] Model %Xh [%Xh:%Xh] Stepping %Xh",
            Family, BaseFamily, ExtendedFamily,
            Model, BaseModel, ExtendedModel, Stepping);
    else
        return format("Family %d Model %d Stepping %d",
            Family, Model, Stepping);
}

/**
 * Print CPU registers on screen from leaf and sub-leaf
 * Params:
 *   leaf = EAX leaf
 *   subl = ECX sub-leaf
 */
void print_cpuid(uint leaf, uint subl)
{
    uint a, b, c, d;
    asm {
        mov EAX, leaf;
        mov ECX, subl;
        cpuid;
        mov a, EAX;
        mov b, EBX;
        mov c, ECX;
        mov d, EDX;
    }
    writefln("| %8X | %X | %8X | %8X | %8X | %8X |",
        leaf, subl, a, b, c, d);
}



/*****************************
 * CPU INFO
 *****************************/

/// <summary>
/// Processor information class.
/// </summary>
struct CpuInfo
{
    /// Fetch information and store it in class variables.
    public void fetchInfo()
    {
        VendorString = getVendor; // 0h.EBX:EDX:ECX
        ProcessorBrandString = strip(getProcessorBrandString);

        MaximumLeaf = getHighestLeaf(); // 0h.EAX
        MaximumExtendedLeaf = getHighestExtendedLeaf(); // 8000_0000h.EAX

        uint a, b, c, d; // EAX:EDX

        for (int leaf = 1; leaf <= MaximumLeaf; ++leaf)
        {
            asm @nogc nothrow pure
            {
                mov EAX, leaf;
                mov ECX, 0;
                cpuid;
                mov a, EAX;
                mov b, EBX;
                mov c, ECX;
                mov d, EDX;
            }

            switch (leaf)
            {
                case 1:
                    // EAX
                    Stepping       = a & 0xF;        // EAX[3:0]
                    BaseModel      = a >>  4 &  0xF; // EAX[7:4]
                    BaseFamily     = a >>  8 &  0xF; // EAX[11:8]
                    ProcessorType  = a >> 12 & 0b11; // EAX[13:12]
                    ExtendedModel  = a >> 16 &  0xF; // EAX[19:16]
                    ExtendedFamily = a >> 20 & 0xFF; // EAX[27:20]

                    switch (VendorString)
                    {
                        case VENDOR_INTEL:
                            if (BaseFamily != 0)
                                Family = BaseFamily;
                            else
                                Family = cast(ubyte)(ExtendedFamily + BaseFamily);

                            if (BaseFamily == 6 || BaseFamily == 0)
                                Model = cast(ubyte)((ExtendedModel << 4) + BaseModel);
                            else // DisplayModel = Model_ID;
                                Model = BaseModel;

                            // ECX
                            DTES64  = c >>  2 & 1;
                            DS_CPL  = c >>  4 & 1;
                            Virt    = c >>  5 & 1;
                            SMX     = c >>  6 & 1;
                            EIST    = c >>  7 & 1;
                            CNXT_ID = c >> 10 & 1;
                            SDBG    = c >> 11 & 1;
                            xTPR    = c >> 14 & 1;
                            PDCM    = c >> 15 & 1;
                            PCID    = c >> 17 & 1;
                            DCA     = c >> 18 & 1;
                            DS      = d >> 21 & 1;
                            APCI    = d >> 22 & 1;
                            SS      = d >> 27 & 1;
                            TM      = d >> 29 & 1;
                            PBE     = d >> 31 & 1;
                            break;

                        case VENDOR_AMD:
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
                    BrandIndex      = b & 0xFF;       // EBX[7:0]
                    CLFLUSHLineSize = b >> 8 & 0xFF;  // EBX[15:8]
                    MaxIDs          = b >> 16 & 0xFF; // EBX[23:16]
                    InitialAPICID   = b >> 24 & 0xFF; // EBX[31:24]
                    // ECX
                    SSE3        = c & 1;
                    PCLMULQDQ   = c >>  1 & 1;
                    MONITOR     = c >>  3 & 1;
                    TM2         = c >>  8 & 1;
                    SSSE3       = c >>  9 & 1;
                    FMA         = c >> 12 & 1;
                    CMPXCHG16B  = c >> 13 & 1;
                    SSE41       = c >> 19 & 1;
                    SSE42       = c >> 20 & 1;
                    x2APIC      = c >> 21 & 1;
                    MOVBE       = c >> 22 & 1;
                    POPCNT      = c >> 23 & 1;
                    TscDeadline = c >> 24 & 1;
                    AES         = c >> 25 & 1;
                    XSAVE       = c >> 26 & 1;
                    OSXSAVE     = c >> 27 & 1;
                    AVX         = c >> 28 & 1;
                    F16C        = c >> 29 & 1;
                    RDRAND      = c >> 30 & 1;
                    // EDX
                    FPU    = d & 1;
                    VME    = d >>  1 & 1;
                    DE     = d >>  2 & 1;
                    PSE    = d >>  3 & 1;
                    TSC    = d >>  4 & 1;
                    MSR    = d >>  5 & 1;
                    PAE    = d >>  6 & 1;
                    MCE    = d >>  7 & 1;
                    CX8    = d >>  8 & 1;
                    APIC   = d >>  9 & 1;
                    SEP    = d >> 11 & 1;
                    MTRR   = d >> 12 & 1;
                    PGE    = d >> 13 & 1;
                    MCA    = d >> 14 & 1;
                    CMOV   = d >> 15 & 1;
                    PAT    = d >> 16 & 1;
                    PSE_36 = d >> 17 & 1;
                    PSN    = d >> 18 & 1;
                    CLFSH  = d >> 19 & 1;
                    MMX    = d >> 23 & 1;
                    FXSR   = d >> 24 & 1;
                    SSE    = d >> 25 & 1;
                    SSE2   = d >> 26 & 1;
                    HTT    = d >> 28 & 1;
                    break;

                case 6:
                    switch (VendorString)
                    {
                        case VENDOR_INTEL:
                            TurboBoost = a >> 1 & 1;
                            break;
                        default:
                    }
                    break;

                    default:

                case 7:
                    switch (VendorString)
                    {
                        case VENDOR_INTEL:
                            TurboBoost = a >> 1 & 1;
                            break;
                        default:
                    }
                    break;

                    RDSEED = b >> 18 & 1;
                    BMI1 = b >> 3 & 1;
                    AVX2 = b >> 5 & 1;
                    SMEP = b >> 7 & 1;
                    BMI2 = b >> 8 & 1;
                    break;
            }
        }
        
        /*
         * Extended CPUID leafs
         */

        for (int eleaf = 0x8000_0000; eleaf < MaximumExtendedLeaf; ++eleaf)
        {
            asm @nogc nothrow
            {
                mov EAX, eleaf;
                mov ECX, 0;
                cpuid;
                mov a, EAX;
                mov b, EBX;
                mov c, ECX;
                mov d, EDX;
            }

            switch (eleaf)
            {
                case 0x8000_0001:
                    switch (VendorString)
                    {
                        case VENDOR_AMD:
                            Virt  = c >>  2 & 1; // SVM
                            SSE4a = c >>  6 & 1;
                            FMA4  = c >> 16 & 1;

                            MMXExt    = d >> 22 & 1;
                            _3DNowExt = d >> 30 & 1;
                            _3DNow    = d >> 31 & 1;
                            break;
                        default:
                    }

                    LZCNT     = c >> 5 & 1;
                    PREFETCHW = c >> 8 & 1;

                    NX       = d >> 20 & 1;
                    Page1GB  = d >> 26 & 1;
                    LongMode = d >> 29 & 1;
                    break;

                case 0x8000_0007:
                    switch (VendorString)
                    {
                        case VENDOR_INTEL:
                            RDSEED = b >> 18 & 1;
                            break;
                        case VENDOR_AMD:
                            TM = d >> 4 & 1;
                            break;
                        default:
                    }

                    TscInvariant = d >> 8 & 1;
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
    string VendorString;
    /// Processor brand string.
    string ProcessorBrandString;

    /// Maximum leaf supported by this processor.
    int MaximumLeaf;
    /// Maximum extended leaf supported by this processor.
    int MaximumExtendedLeaf;

    /// Number of physical cores.
    ushort NumberOfCores;
    /// Number of logical cores.
    ushort NumberOfThreads;

    /// Processor family. ID and extended ID included.
    ubyte Family;
    /// Base Family ID
    ubyte BaseFamily;
    /// Extended Family ID
    ubyte ExtendedFamily;
    /// Processor model. ID and extended ID included.
    ubyte Model;
    /// Base Model ID
    ubyte BaseModel;
    /// Extended Model ID
    ubyte ExtendedModel;
    /// Processor stepping.
    ubyte Stepping;
    /// Processor type.
    ubyte ProcessorType;

    /// MMX Technology.
    bool MMX;
    /// AMD MMX Extented set.
    bool MMXExt;
    /// Streaming SIMD Extensions.
    bool SSE;
    /// Streaming SIMD Extensions 2.
    bool SSE2;
    /// Streaming SIMD Extensions 3.
    bool SSE3;
    /// Supplemental Streaming SIMD Extensions 3 (SSSE3).
    bool SSSE3;
    /// Streaming SIMD Extensions 4.1.
    bool SSE41;
    /// Streaming SIMD Extensions 4.2.
    bool SSE42;
    /// Streaming SIMD Extensions 4a. AMD only.
    bool SSE4a;
    /// AES instruction extensions.
    bool AES;
    /// AVX instruction extensions.
    bool AVX;
    /// AVX2 instruction extensions.
    bool AVX2;

    /// 3DNow! extension. AMD only. Deprecated in 2010.
    bool _3DNow;
    /// 3DNow! Extension supplements. See 3DNow!
    bool _3DNowExt;

    // ---- 01h ----
    // -- EBX --
    /// Brand index. See Table 3-24. If 0, use normal BrandString.
    ubyte BrandIndex;
    /// The CLFLUSH line size. Multiply by 8 to get its size in bytes.
    ubyte CLFLUSHLineSize;
    /// Maximum number of addressable IDs for logical processors in this physical package.
    ubyte MaxIDs;
    /// Initial APIC ID that the process started on.
    ubyte InitialAPICID;
    // -- ECX --
    /// PCLMULQDQ instruction.
    bool PCLMULQDQ; // 1
    /// 64-bit DS Area (64-bit layout).
    bool DTES64;
    /// MONITOR/MWAIT.
    bool MONITOR;
    /// CPL Qualified Debug Store.
    bool DS_CPL;
    /// Virtualization | Virtual Machine eXtensions (Intel) | Secure Virtual Machine (AMD) 
    bool Virt;
    /// Safer Mode Extensions. Intel TXT/TPM
    bool SMX;
    /// Enhanced Intel SpeedStep® Technology.
    bool EIST;
    /// Thermal Monitor 2.
    bool TM2;
    /// L1 Context ID.
    bool CNXT_ID;
    /// Indicates the processor supports IA32_DEBUG_INTERFACE MSR for silicon debug.
    bool SDBG;
    /// FMA extensions using YMM state.
    bool FMA;
    /// Four-operand FMA instruction support.
    bool FMA4;
    /// CMPXCHG16B instruction.
    bool CMPXCHG16B;
    /// xTPR Update Control.
    bool xTPR;
    /// Perfmon and Debug Capability.
    bool PDCM;
    /// Process-context identifiers.
    bool PCID;
    /// Direct Cache Access.
    bool DCA;
    /// x2APIC feature (Intel programmable interrupt controller).
    bool x2APIC;
    /// MOVBE instruction.
    bool MOVBE;
    /// POPCNT instruction.
    bool POPCNT;
    /// Indicates if the APIC timer supports one-shot operation using a TSC deadline value.
    bool TscDeadline;
    /// Indicates the support of the XSAVE/XRSTOR extended states feature, XSETBV/XGETBV instructions, and XCR0.
    bool XSAVE;
    /// Indicates if the OS has set CR4.OSXSAVE[18] to enable XSETBV/XGETBV instructions for XCR0 and XSAVE.
    bool OSXSAVE;
    /// 16-bit floating-point conversion instructions.
    bool F16C;
    /// RDRAND instruction.
    bool RDRAND; // 30
    // -- EDX --
    /// Floating Point Unit On-Chip. The processor contains an x87 FPU.
    bool FPU; // 0
    /// Virtual 8086 Mode Enhancements.
    bool VME;
    /// Debugging Extensions.
    bool DE;
    /// Page Size Extension.
    bool PSE;
    /// Time Stamp Counter.
    bool TSC;
    /// Model Specific Registers RDMSR and WRMSR Instructions. 
    bool MSR;
    /// Physical Address Extension.
    bool PAE;
    /// Machine Check Exception.
    bool MCE;
    /// CMPXCHG8B Instruction.
    bool CX8;
    /// Indicates if the processor contains an Advanced Programmable Interrupt Controller.
    bool APIC;
    /// SYSENTER and SYSEXIT Instructions.
    bool SEP;
    /// Memory Type Range Registers.
    bool MTRR;
    /// Page Global Bit.
    bool PGE;
    /// Machine Check Architecture.
    bool MCA;
    /// Conditional Move Instructions.
    bool CMOV;
    /// Page Attribute Table.
    bool PAT;
    /// 36-Bit Page Size Extension.
    bool PSE_36;
    /// Processor Serial Number. Only Pentium 3 used this.
    bool PSN;
    /// CLFLUSH Instruction.
    bool CLFSH;
    /// Debug Store.
    bool DS;
    /// Thermal Monitor and Software Controlled Clock Facilities.
    bool APCI;
    /// FXSAVE and FXRSTOR Instructions.
    bool FXSR;
    /// Self Snoop.
    bool SS;
    /// Max APIC IDs reserved field is Valid. 0 if only unicore.
    bool HTT;
    /// Thermal Monitor.
    bool TM;
    /// Pending Break Enable.
    bool PBE; // 31

    // ---- 06h ----
    /// Turbo Boost Technology (Intel)
    bool TurboBoost;


    // ---- 07h ----
    // -- EBX --
    /*
     * Note: BMI1, BMI2, and SMEP were introduced in 4th Generation Core processors.
     */
    /// Bit manipulation group 1 instruction support.
    bool BMI1; // 3
    /// Supervisor Mode Execution Protection.
    bool SMEP; // 7
    /// Bit manipulation group 2 instruction support.
    bool BMI2; // 8

    // ---- 8000_0001 ----
    // ECX
    /// Advanced Bit Manipulation under AMD. LZCUNT under Intel.
    bool LZCNT;
    /// PREFETCHW under Intel. 3DNowPrefetch under AMD.
    bool PREFETCHW; // 8

    /// RDSEED instruction
    bool RDSEED;
    // EDX
    /// Intel: Execute Disable Bit. AMD: No-execute page protection.
    bool NX; // 20
    /// 1GB Pages
    bool Page1GB; // 26
    /// Also known as Intel64 or AMD64.
    bool LongMode; // 29

    // ---- 8000_0007 ----
    /// TSC Invariation support
    bool TscInvariant; // 8
} // Class CpuInfo

/// Get the maximum leaf.
/// Returns: Maximum leaf
extern (C) uint getHighestLeaf() pure @nogc nothrow
{
    asm pure @nogc nothrow { naked;
        mov EAX, 0;
        cpuid;
        ret;
    }
}

/// Get the maximum extended leaf.
/// Returns: Maximum extended leaf
extern (C) uint getHighestExtendedLeaf() pure @nogc nothrow
{
    asm pure @nogc nothrow { naked;
        mov EAX, 0x8000_0000;
        cpuid;
        ret;
    }
}

/// Gets the CPU Vendor string.
/// Returns: Vendor string
string getVendor()
{
    char[12] s;
    version (X86_64) asm pure @nogc nothrow {
        lea RDI, s;
        mov EAX, 0;
        cpuid;
        mov [RDI  ], EBX;
        mov [RDI+4], EDX;
        mov [RDI+8], ECX;
    } else asm pure @nogc nothrow {
        lea EDI, s;
        mov EAX, 0;
        cpuid;
        mov [EDI  ], EBX;
        mov [EDI+4], EDX;
        mov [EDI+8], ECX;
    }
    return s.idup;
}

/// Get the Extended Processor Brand string
/// Returns: Processor Brand string
string getProcessorBrandString()
{ //TODO: Check older list?
    char[48] s;
    version (X86_64) asm pure @nogc nothrow {
        lea RDI, s;
        mov EAX, 0x8000_0002;
        cpuid;
        mov [RDI   ], EAX;
        mov [RDI+4 ], EBX;
        mov [RDI+8 ], ECX;
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
        mov [EDI+4 ], EBX;
        mov [EDI+8 ], ECX;
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
extern (C) short getCoresIntel() {
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
}