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
        case "-h":
        case "--help":
            writeln(" ddcpuid [<Options>]");
            writeln();
            writeln(" --details, -D    Gets more details.");
            writeln(" --override, -O   Overrides the maximum leaf to 17H.");
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
    int emax = _oml ? 0x8000_0008 : GetHighestExtendedLeaf();

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
            writefln("EAX=%08XH -> EAX=%-8X EBX=%-8X ECX=%-8X EDX=%-8X", b,
                _eax, _ebx, _ecx, _edx);
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
            writefln("EAX=%08XH -> EAX=%-8X EBX=%-8X ECX=%-8X EDX=%-8X", b,
                _eax, _ebx, _ecx, _edx);
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
        CPU_INFO c = GetCpuInfo();

        writeln("Vendor: ", c.Vendor);
        writeln("Model: ", strip(c.ProcessorBrandString));
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

        if (_det)
        {
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
            if (c.MSR)
                write("MSR, ");
            writeln();
            write("Single instructions: [ ");
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
            if (c.TSC)
                writef("RDTSC (Deadline: %s), ", c.TSC_Deadline);
            if (c.CMOV)
                write("CMOV, ");
            if (c.CLFSH)
                writef("CLFLUSH, ");
            if (c.POPCNT)
                write("POPCNT, ");
            write("]");
        }
        writeln();
        writefln("Turbo Boost Available: %s", SupportsTurboBoost());

        if (_det)
        {
            writeln();
            writeln(" ----- Details -----");
            writeln();
            writefln("Highest Leaf: %02XH | Extended: %02XH", max, emax);
            writeln();
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

            writefln("Family %s Model %s Stepping %s", c.Family, c.Model, c.Stepping);
            writefln("Brand Index: %s", c.BrandIndex);
            writefln("Max # of addressable IDs: %s", c.MaximumNumberOfAddressableIDs);
            writefln("APIC: %s (Initial ID: %s)", c.APIC, c.InitialAPICID);
            writefln("x2APIC: %s", c.x2APIC);
            writefln("DTES64: %s", c.DTES64);
            writefln("MONITOR: %s", c.MONITOR);
            writefln("VMX: %s", c.VMX);
            writefln("SMX: %s", c.SMX);
            writefln("EIST: %s", c.EIST);
            writefln("TM: %s", c.TM);
            writefln("TM2: %s", c.TM2);
            writefln("CNXT-ID: %s", c.CNXT_ID);
            writefln("xTPR Update Control: %s", c.xTPR);
            writefln("PDCM: %s", c.PDCM);
            writefln("PCID: %s", c.PCID);
            writefln("DCA: %s", c.DCA);
            writefln("FPU: %s", c.FPU);
            writefln("VME: %s", c.VME);
            writefln("DE: %s", c.DE);
            writefln("PAE: %s", c.PAE);
            writefln("MCE: %s", c.MCE);
            writefln("SEP: %s", c.SEP);
            writefln("MTRR: %s", c.MTRR);
            writefln("PGE: %s", c.PGE);
            writefln("MCA: %s", c.MCA);
            writefln("PAT: %s", c.PAT);
            writefln("PSE-36: %s", c.PSE_36);
            writefln("PSN: %s", c.PSN);
            writefln("DS: %s", c.DS);
            writefln("APCI: %s", c.APCI);
            writefln("FXSR: %s", c.FXSR);
            writefln("SS: %s", c.SS);
            writefln("HTT: %s", c.HTT);
            writefln("PBE: %s", c.PBE);
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

// ----- 02H - Basic CPUID Information -----
// EAX, EBX, ECX, EDX - Cache and TLB Information.
//TODO: 02H

// ----- 03H - Basic CPUID Information -----
// EAX and EBX are reserved.

// NOTES: (From the Intel document)
// Processor serial number (PSN) is not supported in the Pentium 4 processor or later.
// On all models, use the PSN flag (returned using CPUID) to check for PSN support
// before accessing the feature.

// ----- 04H - Deterministic Cache Parameters Leaf -----
// NOTES: Leaf 04H output depends on the initial value in ECX.*

/*  ECX = Cache Level
    This Cache Size in Bytes
    = (Ways + 1) * (Partitions + 1) * (Line_Size + 1) * (Sets + 1)
    = (EBX[31:22] + 1) * (EBX[21:12] + 1) * (EBX[11:0] + 1) * (ECX + 1)
*/

// ----- 05H - MONITOR/MWAIT Leaf -----

// ----- 06H - Thermal and Power Management Leaf -----
// EAX
// Bit 00 - 

// Bit 01 - Intel Turbo Boost Technology Available
public bool SupportsTurboBoost()
{
    int e;
    asm
    {
        mov EAX, 6;
        cpuid;
        mov e, EAX;
    }
    return e >> 1 & 1;
}

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

// ---- Misc ----

public CPU_INFO GetCpuInfo()
{
    CPU_INFO i = new CPU_INFO;

    i.Intel = new IntelFeatures;
    i.Amd = new AmdFeatures;

    i.Vendor = GetVendor();
    i.ProcessorBrandString = GetProcessorBrandString();

    i.MaximumLeaf = GetHighestLeaf();

    int a, b, c, d;
    for (int leaf = 1; leaf <= i.MaximumLeaf; ++leaf)
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

        final switch (leaf)
        {
        case 1: // 01H - Basic CPUID Information
            // EAX
            // Full  = Extended ID      | ID
            //         EAX[27:20]       | EAX[11:8]
            i.Family = (a >> 16 & 0xF0) | (a >> 8 & 0xF);
            //         EAX[19:16]       | EAX[7:4]
            i.Model = (a >> 12 & 0xF0) | (a >> 4 & 0xF);
            i.ProcessorType = (a >> 12) & 3; // EAX[13:12]
            i.Stepping = a & 0xF; // EAX[3:0]
            // EBX
            i.BrandIndex = b & 0xFF; // EBX[7:0]
            i.CLFLUSHLineSize = b >> 8 & 0xFF; // EBX[15:8]
            i.MaximumNumberOfAddressableIDs = b >> 16 & 0xFF; // EBX[23:16]
            i.InitialAPICID = b >> 24 & 0xFF; // EBX[31:24]
            // ECX
            i.SSE3         = c & 1;
            i.PCLMULQDQ    = c >> 1 & 1;
            i.DTES64       = c >> 2 & 1;
            i.MONITOR      = c >> 3 & 1;
            i.DS_CPL       = c >> 4 & 1;
            i.VMX          = c >> 5 & 1;
            i.SMX          = c >> 6 & 1;
            i.EIST         = c >> 7 & 1;
            i.TM2          = c >> 8 & 1;
            i.SSSE3        = c >> 9 & 1;
            i.CNXT_ID      = c >> 10 & 1;
            i.SDBG         = c >> 11 & 1;
            i.FMA          = c >> 12 & 1;
            i.CMPXCHG16B   = c >> 13 & 1;
            i.xTPR         = c >> 14 & 1;
            i.PDCM         = c >> 15 & 1;
            i.PCID         = c >> 17 & 1;
            i.DCA          = c >> 18 & 1;
            i.SSE41        = c >> 19 & 1;
            i.SSE42        = c >> 20 & 1;
            i.x2APIC       = c >> 21 & 1;
            i.MOVBE        = c >> 22 & 1;
            i.POPCNT       = c >> 23 & 1;
            i.TSC_Deadline = c >> 24 & 1;
            i.AESNI        = c >> 25 & 1;
            i.XSAVE        = c >> 26 & 1;
            i.OSXSAVE      = c >> 27 & 1;
            i.AVX          = c >> 28 & 1;
            i.F16C         = c >> 29 & 1;
            i.RDRAND       = c >> 30 & 1;
            // EDX
            i.FPU    = d & 1;
            i.VME    = d >>  1 & 1;
            i.DE     = d >>  2 & 1;
            i.PSE    = d >>  3 & 1;
            i.TSC    = d >>  4 & 1;
            i.MSR    = d >>  5 & 1;
            i.PAE    = d >>  6 & 1;
            i.MCE    = d >>  7 & 1;
            i.CX8    = d >>  8 & 1;
            i.APIC   = d >>  9 & 1;
            i.SEP    = d >> 11 & 1;
            i.MTRR   = d >> 12 & 1;
            i.PGE    = d >> 13 & 1;
            i.MCA    = d >> 14 & 1;
            i.CMOV   = d >> 15 & 1;
            i.PAT    = d >> 16 & 1;
            i.PSE_36 = d >> 17 & 1;
            i.PSN    = d >> 18 & 1;
            i.CLFSH  = d >> 19 & 1;
            i.DS     = d >> 21 & 1;
            i.APCI   = d >> 22 & 1;
            i.MMX    = d >> 23 & 1;
            i.FXSR   = d >> 24 & 1;
            i.SSE    = d >> 25 & 1;
            i.SSE2   = d >> 26 & 1;
            i.SS     = d >> 27 & 1;
            i.HTT    = d >> 28 & 1;
            i.TM     = d >> 29 & 1;
            i.PBE    = d >> 31 & 1;
            break;
        }
    }

    // Vendor specific features.
    /*switch (i.Vendor)
    {
        case "GenuineIntel":

        break;

        case "AuthenticAMD":

        break;

        default:
    }*/

    return i;
}

/// <summary>
/// Provides a set of information about the processor.
/// </summary>
public class CPU_INFO
{
    // Basic information
    public string Vendor;
    public string ProcessorBrandString;

    public int MaximumLeaf;
    public int MaximumExtendedLeaf;

    public ubyte Family; // ID and extended ID
    public ubyte Model; // ID and extended ID
    public ubyte ProcessorType;
    public ubyte Stepping;

    // Instruction extensions
    public bool MMX;
    public bool SSE;
    public bool SSE2;
    public bool SSE3;
    public bool SSSE3;
    public bool SSE41;
    public bool SSE42;
    public bool AESNI;
    public bool AVX;
    public bool AVX2;

    // Single instructions -- todo

    //TODO: Document every member (///)

    // -- 01h --
    // EBX
    public ubyte BrandIndex;
    public ubyte CLFLUSHLineSize;
    public ubyte MaximumNumberOfAddressableIDs;
    public ubyte InitialAPICID;
    // ECX
    public bool PCLMULQDQ; // 0
    public bool DTES64;
    public bool MONITOR;
    public bool DS_CPL;
    public bool VMX;
    public bool SMX;
    public bool EIST;
    public bool TM2;
    public bool CNXT_ID;
    public bool SDBG;
    public bool FMA;
    public bool CMPXCHG16B;
    public bool xTPR;
    public bool PDCM;
    public bool PCID;
    public bool DCA;
    public bool x2APIC;
    public bool MOVBE;
    public bool POPCNT;
    public bool TSC_Deadline;
    public bool XSAVE;
    public bool OSXSAVE;
    public bool F16C;
    public bool RDRAND; // 30
    // EDX
    public bool FPU;
    public bool VME;
    public bool DE;
    public bool PSE;
    public bool TSC;
    public bool MSR;
    public bool PAE;
    public bool MCE;
    public bool CX8;
    public bool APIC;
    public bool SEP;
    public bool MTRR;
    public bool PGE;
    public bool MCA;
    public bool CMOV;
    public bool PAT;
    public bool PSE_36;
    public bool PSN;
    public bool CLFSH;
    public bool DS;
    public bool APCI;
    public bool FXSR;
    public bool SS;
    public bool HTT;
    public bool TM;
    public bool PBE;

    public IntelFeatures Intel;
    public AmdFeatures Amd;
}

// Intel specific features
public class IntelFeatures
{
    public bool TurboBoostTechnology;
}

// AMD specific features
public class AmdFeatures
{

}
