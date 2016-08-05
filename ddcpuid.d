import std.stdio, std.string;
/*import core.sys.windows.windows;
import core.sys.windows.dll;
 
__gshared HINSTANCE g_hInst;
 
extern (Windows)
BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    switch (ulReason)
    {
        case DLL_PROCESS_ATTACH:
            g_hInst = hInstance;
            dll_process_attach( hInstance, true );
            break;
    
        case DLL_PROCESS_DETACH:
            dll_process_detach( hInstance, true );
            break;
    
        case DLL_THREAD_ATTACH:
            dll_thread_attach( true, true );
            break;
    
        case DLL_THREAD_DETACH:
            dll_thread_detach( true, true );
            break;
 
        default:
    }
    return true;
}*/

/// Version
const string ver = "0.1.0";

void main(string[] args)
{
    bool _dbg = false; // Debug
    bool _det = false; // Detailed output
    bool _oml = false; // Override max leaf

    foreach (s; args)
    {
        switch (s)
        {
        case "/?":
        case "-h":
        case "--help":
            writeln(" ddcpuid [<Options>]");
            writeln();
            writeln(" --details, -D    Gets more details.");
            writeln(" --override, -O   Overrides the maximum leaf and extended leaf.");
            writeln(" --debug          Gets debugging information.");
            writeln();
            writeln(" --help      Prints help and quit.");
            writeln(" --version   Prints version and quit.");
            return;
 
        case "--version":
            writeln("ddcpuid v", ver);
            writeln("Copyright (c) guitarxhero 2016");
            writeln("License: MIT License <http://opensource.org/licenses/MIT>");
            writeln("Project page: <https://github.com/guitarxhero/ddcpuid>");
            return;

        case "-D":
        case "--details":
            _det = true;
            break;

        case "-O":
        case "--override":
            _oml = true;
            break;

        case "--debug":
            _dbg = true;
            break;

        default:
        }
    }

    // Maximum leaf
    int max = _oml ? 0x17 : GetHighestLeaf();
    // Maximum extended leaf
    int emax = _oml ? 0x8000_0020 : GetHighestExtendedLeaf();

    if (_dbg)
    {
        uint _eax, _ebx, _ecx, _edx, _ebp, _esp, _edi, _esi;
        for (int b = 0; b <= max; ++b)
        {
            asm
            {
                mov EAX, b;
                cpuid;
                mov _eax, EAX;
                mov _ebx, EBX;
                mov _ecx, ECX;
                mov _edx, EDX;
            }
            writefln("EAX=%08XH -> EAX=%-8X EBX=%-8X ECX=%-8X EDX=%-8X",
                b, _eax, _ebx, _ecx, _edx);
        }
        for (int b = 0x8000_0000; b <= emax; ++b)
        {
            asm
            {
                mov EAX, b;
                cpuid;
                mov _eax, EAX;
                mov _ebx, EBX;
                mov _ecx, ECX;
                mov _edx, EDX;
            }
            writefln("EAX=%08XH -> EAX=%-8X EBX=%-8X ECX=%-8X EDX=%-8X",
                b, _eax, _ebx, _ecx, _edx);
        }
        asm
        {
            mov _ebp, EBP;
            mov _esp, ESP;
            mov _edi, EDI;
            mov _esi, ESI;
        }
        writefln("EBP=%-8X ESP=%-8X EDI=%-8X ESI=%-8X", _ebp, _esp, _edi, _esi);
        writeln();
    }
    else
    {
        CPU_INFO c = new CPU_INFO(true);

        writeln("Vendor: ", c.Vendor);
        writeln("Model: ", strip(c.ProcessorBrandString));
        writefln("Identification: Family %s [%X] Model %s [%X] Stepping %s [%X]",
            c.Family, c.Family, c.Model, c.Model, c.Stepping, c.Stepping);

        if (_det)
        {
            writefln(
                "BaseFamily: %s [%X], Extended: %s [%X], BaseModel: %s [%X], Extended: %s [%X]",
                c.BaseFamily, c.BaseFamily,
                c.ExtendedFamily, c.ExtendedFamily,
                c.BaseModel, c.BaseModel,
                c.ExtendedModel, c.ExtendedModel);
        }

        write("Extensions: ");
        if (c.MMX)
            write("MMX, ");
        if (c.SSE)
            write("SSE, ");
        if (c.SSE2)
            write("SSE2, ");
        if (c.SSE3)
            write("SSE3, ");
        if (c.SSSE3)
            write("SSSE3, ");
        if (c.SSE41)
            write("SSE4.1, ");
        if (c.SSE42)
            write("SSE4.2, ");
        if (c.AESNI)
            write("AESNI, ");
        if (c.AVX)
            write("AVX, ");
        if (c.AVX2)
            write("AVX2, ");
        if (c.VMX)
            write("VMX, ");
        if (c.SMX)
            write("SMX, ");
        if (c.DS_CPL)
            write("DS-CPL, ");
        if (c.FMA)
            write("FMA, ");
        if (c.XSAVE)
            write("XSAVE, ");
        if (c.OSXSAVE)
            write("OSXSAVE, ");
        if (c.F16C)
            write("F16C, ");
        writeln();

        if (_det)
        {
            write("Single instructions: [ ");
            if (c.MONITOR)
                write("MONITOR/MWAIT, ");
            if (c.PCLMULQDQ)
                write("PCLMULQDQ, ");
            if (c.CX8)
                write("CMPXCHG8B, ");
            if (c.CMPXCHG16B)
                write("CMPXCHG16B, ");
            if (c.MOVBE)
                write("MOVBE, "); // Intel Atom only!
            if (c.RDRAND)
                write("RDRAND, ");
            if (c.MSR)
                write("RDMSR/WRMSR, ");
            if (c.SEP)
                write("SYSENTER/SYSEXIT, ");
            if (c.TSC)
            {
                write("RDTSC");
                if (c.TSC_Deadline)
                    write(" (TSC-Deadline)");
                write(", ");
            }
            if (c.CMOV)
                write("CMOV, ");
            if (c.FPU && c.CMOV)
                write("FCOMI/FCMOV, ");
            if (c.CLFSH)
                writef("CLFLUSH (Lines: %s), ", c.CLFLUSHLineSize);
            if (c.POPCNT)
                write("POPCNT, ");
            if (c.FXSR)
                write("FXSAVE/FXRSTOR, ");
            writeln("]");
        }

        writefln("Hyper-Threading Technology: %s", c.HTT);
        writefln("Turbo Boost Available: %s", c.TurboBoost);
        writefln("Enhanced Intel SpeedStep technology: %s", c.EIST);

        if (_det)
        {
            writeln();
            writeln(" ----- Details -----");
            writeln();
            writefln("Highest Leaf: %02XH | Extended: %02XH", max, emax);
            write("Processor type: ");
            final switch (c.ProcessorType) // 2 bit value
            {
                case 0:
                    writeln("Original OEM Processor");
                    break;
                case 1:
                    writeln("Intel OverDrive Processor");
                    break;
                case 2:
                    writeln("Dual processor");
                    break;
                case 3:
                    writeln("Intel reserved");
                    break;
            }

            //TODO: Floating point section
            //TODO: Virtualization section
            //TODO: Memory handling section

            writefln("Brand Index: %s", c.BrandIndex);
            // MaximumNumberOfAddressableIDs / 2 (if HTT) for # cores?
            writefln("Max # of addressable IDs: %s", c.MaximumNumberOfAddressableIDs);
            writefln("APIC: %s (Initial ID: %s)", c.APIC, c.InitialAPICID);
            writefln("x2APIC: %s", c.x2APIC);
            writefln("64-bit DS Area [DTES64]: %s", c.DTES64);
            writefln("Thermal Monitor [TM]: %s", c.TM);
            writefln("Thermal Monitor 2 [TM2]: %s", c.TM2);
            writefln("L1 Context ID [CNXT-ID]: %s", c.CNXT_ID);
            writefln("xTPR Update Control [xTPR]: %s", c.xTPR);
            writefln("Perfmon and Debug Capability [PDCM]: %s", c.PDCM);
            writefln("Process-context identifiers [PCID]: %s", c.PCID);
            writefln("Direct Cache Access [DCA]: %s", c.DCA);
            writefln("Floating Point Unit [FPU]: %s", c.FPU);
            writefln("Virtual 8086 Mode Enhancements [VME]: %s", c.VME);
            writefln("Debugging Extensions [DE]: %s", c.DE);
            writefln("Page Size Extension [PAE]: %s", c.PAE);
            writefln("Machine Check Exception [MCE]: %s", c.MCE);
            writefln("Memory Type Range Registers [MTRR]: %s", c.MTRR);
            writefln("Page Global Bit [PGE]: %s", c.PGE);
            writefln("Machine Check Architecture [MCA]: %s", c.MCA);
            writefln("Page Attribute Table [PAT]: %s", c.PAT);
            writefln("36-Bit Page Size Extension [PSE-36]: %s", c.PSE_36);
            writefln("Processor Serial Number [PSN]: %s", c.PSN);
            writefln("Debug Store [DS]: %s", c.DS);
            writefln("Thermal Monitor and Software Controlled Clock Facilities [APCI]: %s", c.APCI);
            writefln("Self Snoop [SS]: %s", c.SS);
            writefln("Pending Break Enable [PBE]: %s", c.PBE);
            writefln("Supervisor Mode Execution Protection [SMEP]: %s", c.SMEP);
        }
    }
}

// ----- 00H - Basic CPUID Information -----
/// <summary>
/// Gets the highest leaf possible for this processor.
/// </summay>
public int GetHighestLeaf()
{
    int e;
    asm
    {
        mov EAX, 0;
        cpuid;
        mov e, EAX;
    }
    return e;
}

/// <summary>
/// Gets the CPU Vendor string.
/// </summay>
public string GetVendor()
{
    string s;
    int ebx, ecx, edx;
    asm
    {
        mov EAX, 0;
        cpuid;
        mov ebx, EBX;
        mov ecx, ECX;
        mov edx, EDX;
    }
    char* pebx = cast(char*)&ebx, pecx = cast(char*)&ecx, pedx = cast(char*)&edx;
    // EBX, EDX, ECX
    s ~= *pebx;
    s ~= *(pebx + 1);
    s ~= *(pebx + 2);
    s ~= *(pebx + 3);
    s ~= *pedx;
    s ~= *(pedx + 1);
    s ~= *(pedx + 2);
    s ~= *(pedx + 3);
    s ~= *pecx;
    s ~= *(pecx + 1);
    s ~= *(pecx + 2);
    s ~= *(pecx + 3);
    return s;
}

// ----- 04H - Deterministic Cache Parameters Leaf -----
// NOTES: Leaf 04H output depends on the initial value in ECX.*

/*  ECX = Cache Level
    This Cache Size in Bytes
    = (Ways + 1) * (Partitions + 1) * (Line_Size + 1) * (Sets + 1)
    = (EBX[31:22] + 1) * (EBX[21:12] + 1) * (EBX[11:0] + 1) * (ECX + 1)
*/

// ----- 80000000H - Extended Function CPUID Information -----
// EAX - Maximum Input Value for Extended Function CPUID Information.
public int GetHighestExtendedLeaf()
{
    int e;
    asm
    {
        mov EAX, 0x80000000;
        cpuid;
        mov e, EAX;
    }
    return e;
}

// ----- 80000001H - Extended Function CPUID Information -----
// EAX - Extended Processor Signature and Feature Bits.

// EBX - Reserved

// ECX
// Bit 00 - LAHF/SAHF available in 64-bit mode.

// Bit 04~01 - Reserved
// Bit 05 - LZCNT

// Bit 07~06 - Reserved
// Bit 08 - PREFETCHW

// Bit 31~09 - Reserved

// EDX

// ----- 80000002H~80000004H - Processor Brand String -----
public string GetProcessorBrandString()
{
    string s;
    for (int i = 0x80000002; i <= 0x80000004; ++i)
    {
        int eax, ebx, ecx, edx;
        asm
        {
            mov EAX, i;
            cpuid;
            mov eax, EAX;
            mov ebx, EBX;
            mov ecx, ECX;
            mov edx, EDX;
        }
        char* peax = cast(char*)&eax, pebx = cast(char*)&ebx,
              pecx = cast(char*)&ecx, pedx = cast(char*)&edx;
        // EAX, EBX, ECX, EDX
        s ~= *peax;
        s ~= *(peax + 1);
        s ~= *(peax + 2);
        s ~= *(peax + 3);
        s ~= *pebx;
        s ~= *(pebx + 1);
        s ~= *(pebx + 2);
        s ~= *(pebx + 3);
        s ~= *pecx;
        s ~= *(pecx + 1);
        s ~= *(pecx + 2);
        s ~= *(pecx + 3);
        s ~= *pedx;
        s ~= *(pedx + 1);
        s ~= *(pedx + 2);
        s ~= *(pedx + 3);
    }
    return s;
}

/***********
 * Classes *
 ***********/

/// <summary>
/// Provides a set of information about the processor.
/// </summary>
public class CPU_INFO
{
    /// Initiates a CPU_INFO without fetching CPU info.
    this(bool fetch = false)
    {
        if (fetch)
            FetchInfo();
    }

    /// Fetches the information 
    public void FetchInfo()
    {
        Vendor = GetVendor();
        ProcessorBrandString = GetProcessorBrandString();

        MaximumLeaf = GetHighestLeaf();

        int a, b, c, d;
        for (int leaf = 1; leaf <= MaximumLeaf; ++leaf)
        {
            asm
            {
                mov EAX, leaf;
                cpuid;
                mov a, EAX;
                mov b, EBX;
                mov c, ECX;
                mov d, EDX;
            }

            switch (leaf)
            {
                // case 0 already has been handled (max leaf and vendor).
                case 1: // 01H -- Basic CPUID Information
                    // EAX
                    BaseFamily     = a >>  8 &  0xF; // EAX[11:8]
                    ExtendedFamily = a >> 20 & 0xFF; // EAX[27:20]
                    BaseModel      = a >>  4 &  0xF; // EAX[7:4]
                    ExtendedModel  = a >> 16 &  0xF; // EAX[19:16]
                    switch (Vendor)
                    {
                        case "AuthenticAMD":
                        // If BaseFamily[3:0] is less than Fh, then ExtFamily is
                        // reserved and Family is equal to BaseFamily[3:0].
                        if (BaseFamily < 0xF)
                            Family = BaseFamily;
                        else
                            Family = cast(ubyte)(ExtendedFamily + BaseFamily);

                        // If BaseFamily[3:0] is less than 0Fh, then ExtModel is
                        // reserved and Model is equal to BaseModel[3:0].
                        if (BaseFamily < 0xF)
                            Model = BaseModel;
                        else
                            Model = cast(ubyte)((ExtendedModel << 4) + BaseModel);
                        break;
                        
                        case "GenuineIntel":
                        if (BaseFamily != 0) // If Family_ID ≠ 0FH
                            Family = BaseFamily; // DisplayFamily = Family_ID;
                        else // ELSE DisplayFamily = Extended_Family_ID + Family_ID;
                            Family = cast(ubyte)(ExtendedFamily + BaseFamily);

                        if (BaseFamily == 6 || BaseFamily == 0) // IF (Family_ID = 06H or Family_ID = 0FH)
                        // DisplayModel = (Extended_Model_ID « 4) + Model_ID;
                            Model = cast(ubyte)((ExtendedModel << 4) + BaseModel);
                        else // DisplayModel = Model_ID;
                            Model = BaseModel;
                        break;

                        default:
                    }

                    ProcessorType = (a >> 12) & 3; // EAX[13:12]
                    Stepping = a & 0xF; // EAX[3:0]
                    // EBX
                    BrandIndex = b & 0xFF; // EBX[7:0]
                    CLFLUSHLineSize = b >> 8 & 0xFF; // EBX[15:8]
                    MaximumNumberOfAddressableIDs = b >> 16 & 0xFF; // EBX[23:16]
                    InitialAPICID = b >> 24 & 0xFF; // EBX[31:24]
                    // ECX
                    SSE3         = c & 1;
                    PCLMULQDQ    = c >>  1 & 1;
                    DTES64       = c >>  2 & 1;
                    MONITOR      = c >>  3 & 1;
                    DS_CPL       = c >>  4 & 1;
                    VMX          = c >>  5 & 1;
                    SMX          = c >>  6 & 1;
                    EIST         = c >>  7 & 1;
                    TM2          = c >>  8 & 1;
                    SSSE3        = c >>  9 & 1;
                    CNXT_ID      = c >> 10 & 1;
                    SDBG         = c >> 11 & 1;
                    FMA          = c >> 12 & 1;
                    CMPXCHG16B   = c >> 13 & 1;
                    xTPR         = c >> 14 & 1;
                    PDCM         = c >> 15 & 1;
                    PCID         = c >> 17 & 1;
                    DCA          = c >> 18 & 1;
                    SSE41        = c >> 19 & 1;
                    SSE42        = c >> 20 & 1;
                    x2APIC       = c >> 21 & 1;
                    MOVBE        = c >> 22 & 1;
                    POPCNT       = c >> 23 & 1;
                    TSC_Deadline = c >> 24 & 1;
                    AESNI        = c >> 25 & 1;
                    XSAVE        = c >> 26 & 1;
                    OSXSAVE      = c >> 27 & 1;
                    AVX          = c >> 28 & 1;
                    F16C         = c >> 29 & 1;
                    RDRAND       = c >> 30 & 1;
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
                    DS     = d >> 21 & 1;
                    APCI   = d >> 22 & 1;
                    MMX    = d >> 23 & 1;
                    FXSR   = d >> 24 & 1;
                    SSE    = d >> 25 & 1;
                    SSE2   = d >> 26 & 1;
                    SS     = d >> 27 & 1;
                    HTT    = d >> 28 & 1;
                    TM     = d >> 29 & 1;
                    PBE    = d >> 31 & 1;
                    break;

                case 2: // 02h -- Cache and TLB Information. | AMD: Reserved

                    break;

                case 6: // 06h -- Thermal and Power Management Leaf | AMD: Reversed
                    switch (Vendor)
                    {
                        case "GenuineIntel":
                            TurboBoost = a >> 1 & 1;
                            break;

                        default:
                    }
                    break;

                    default:

                case 7:
                    AVX2 = b >> 5 & 1;
                    SMEP = b >> 7 & 1;
                    break;
            }
        }
    }

    // ---- Basic information ----
    /// Processor vendor.
    public string Vendor;
    /// Processor brand string.
    public string ProcessorBrandString;

    /// Maximum leaf supported by this processor.
    public int MaximumLeaf;
    /// Maximum extended leaf supported by this processor.
    public int MaximumExtendedLeaf;

    /// Processor family. ID and extended ID included.
    public ushort Family;
    /// Base Family ID
    public ubyte BaseFamily;
    /// Extended Family ID
    public ubyte ExtendedFamily;
    /// Processor model. ID and extended ID included.
    public ubyte Model;
    /// Base Model ID
    public ubyte BaseModel;
    /// Extended Model ID
    public ubyte ExtendedModel;
    /// Processor stepping.
    public ubyte Stepping;
    /// Processor type.**1
    public ubyte ProcessorType;

    // ---- Instruction extensions ----
    /// MMX Technology.
    public bool MMX;
    /// Streaming SIMD Extensions.
    public bool SSE;
    /// Streaming SIMD Extensions 2.
    public bool SSE2;
    /// Streaming SIMD Extensions 3.
    public bool SSE3;
    /// Supplemental Streaming SIMD Extensions 3 (SSSE3).
    public bool SSSE3;
    /// Streaming SIMD Extensions 4.1.
    public bool SSE41;
    /// Streaming SIMD Extensions 4.2.
    public bool SSE42;
    /// AESNI instruction extensions.
    public bool AESNI;
    /// AVX instruction extensions.
    public bool AVX;
    /// AVX2 instruction extensions.
    public bool AVX2;

    //TODO: Single instructions

    // ---- 01h : Basic CPUID Information ----
    // -- EBX --
    /// Brand index. Probably unsused. E.g. Intel Core i7
    public ubyte BrandIndex;
    /// The CLFLUSH line size. Multiply by 8 to get its size in bytes.
    public ubyte CLFLUSHLineSize;
    /// Maximum number of addressable IDs for logical processors in this physical package.*1
    public ubyte MaximumNumberOfAddressableIDs;
    /// Initial APIC ID for this processor.
    public ubyte InitialAPICID;
    // -- ECX --
    /// PCLMULQDQ instruction.
    public bool PCLMULQDQ; // 1
    /// 64-bit DS Area (64-bit layout). 
    public bool DTES64; // EM64T ??
    /// MONITOR/MWAIT.
    public bool MONITOR;
    /// CPL Qualified Debug Store.
    public bool DS_CPL;
    /// Virtual Machine Extensions.
    public bool VMX;
    /// Safer Mode Extensions.
    public bool SMX;
    /// Enhanced Intel SpeedStep® technology.
    public bool EIST;
    /// Thermal Monitor 2.
    public bool TM2;
    /// L1 Context ID. If true, the L1 data cache mode can be set to either adaptive or shared mode. 
    public bool CNXT_ID;
    /// Indicates the processor supports IA32_DEBUG_INTERFACE MSR for silicon debug.
    public bool SDBG;
    /// FMA extensions using YMM state.
    public bool FMA;
    /// CMPXCHG16B instruction.
    public bool CMPXCHG16B;
    /// xTPR Update Control.
    public bool xTPR;
    /// Perfmon and Debug Capability.
    public bool PDCM;
    /// Process-context identifiers.
    public bool PCID;
    /// Direct Cache Access.
    public bool DCA;
    /// x2APIC feature (Intel programmable interrupt controller).
    public bool x2APIC;
    /// MOVBE instruction.
    public bool MOVBE;
    /// POPCNT instruction.
    public bool POPCNT;
    /// Indicates if the APIC timer supports one-shot operation using a TSC deadline value.
    public bool TSC_Deadline;
    /// Indicates the support of the XSAVE/XRSTOR extended states feature, XSETBV/XGETBV instructions, and XCR0.
    public bool XSAVE;
    /// Indicates if the OS has set CR4.OSXSAVE[bit 18] to enable XSETBV/XGETBV instructions for XCR0 and XSAVE.
    public bool OSXSAVE;
    /// 16-bit floating-point conversion instructions.
    public bool F16C;
    /// RDRAND instruction.
    public bool RDRAND; // 30
    // -- EDX --
    /// Floating Point Unit On-Chip. The processor contains an x87 FPU.
    public bool FPU; // 0
    /// Virtual 8086 Mode Enhancements.
    public bool VME;
    /// Debugging Extensions.
    public bool DE;
    /// Page Size Extension.
    public bool PSE;
    /// Time Stamp Counter.
    public bool TSC;
    /// Model Specific Registers RDMSR and WRMSR Instructions. 
    public bool MSR;
    /// Physical Address Extension.
    public bool PAE;
    /// Machine Check Exception.
    public bool MCE;
    /// CMPXCHG8B Instruction.
    public bool CX8;
    /// Indicates if the processor contains an Advanced Programmable Interrupt Controller.
    public bool APIC;
    /// SYSENTER and SYSEXIT Instructions.
    public bool SEP;
    /// Memory Type Range Registers.
    public bool MTRR;
    /// Page Global Bit.
    public bool PGE;
    /// Machine Check Architecture.
    public bool MCA;
    /// Conditional Move Instructions.
    public bool CMOV;
    /// Page Attribute Table.
    public bool PAT;
    /// 36-Bit Page Size Extension.
    public bool PSE_36;
    /// Processor Serial Number. 
    public bool PSN;
    /// CLFLUSH Instruction.
    public bool CLFSH;
    /// Debug Store.
    public bool DS;
    /// Thermal Monitor and Software Controlled Clock Facilities.
    public bool APCI;
    /// FXSAVE and FXRSTOR Instructions.
    public bool FXSR;
    /// Self Snoop.
    public bool SS;
    /// Hyper-threading technology.
    public bool HTT;
    /// Thermal Monitor.
    public bool TM;
    /// Pending Break Enable.
    public bool PBE; // 31


    // ---- 07h - Thermal and Power Management Leaf ----
    // -- EBX --
    /// Supervisor Mode Execution Protection
    public bool SMEP; // 7


    // ---- 06h - Thermal and Power Management Leaf ----
    /// Turbo Boost Technology (Intel)
    public bool TurboBoost;
}