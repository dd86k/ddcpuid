import std.stdio;
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

void main(string[] args)
{
    bool _dbg = false; // Debug
    bool _det = false; // Detailed output

    foreach(s; args)
    {
        switch(s)
        {
            case "--debug":
                _dbg = true;
                break;

            case "--detailed":
                _det = true;
                break;

            default: break;
        }
    }

    int max = GetHighestLeaf();

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
                mov _ebp, EBP;
                mov _esp, ESP;
                mov _edi, EDI;
                mov _esi, ESI;
            }
            writefln("----- EAX=%XH -----", b);
            writefln("EAX=%-8X EBX=%-8X ECX=%-8X EDX=%-8X", _eax, _ebx, _ecx, _edx);
            writefln("EBP=%-8X ESP=%-8X EDI=%-8X ESI=%-8X", _ebp, _esp, _edi, _esi);
        }
    }

    // Obviously at some point, only the batch
    // will be performed, which will improve performance

    writeln();
    writefln("Vendor: %s", GetVendor());
    writefln("Turbo Boost Available: %s", SupportsTurboBoost());
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
/// <remarks>
/// Intel=GenuintelineI
/// AMD=
/// </remarks>
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
    // EBX, EDX, ECX
    s ~= cast(char)(ebx & 0xFF);
    s ~= cast(char)((ebx >>  8) & 0xFF);
    s ~= cast(char)((ebx >> 16) & 0xFF);
    s ~= cast(char)(ebx >> 24);
    s ~= cast(char)(edx & 0xFF);
    s ~= cast(char)((edx >>  8) & 0xFF);
    s ~= cast(char)((edx >> 16) & 0xFF);
    s ~= cast(char)(edx >> 24);
    s ~= cast(char)(ecx & 0xFF);
    s ~= cast(char)((ecx >>  8) & 0xFF);
    s ~= cast(char)((ecx >> 16) & 0xFF);
    s ~= cast(char)(ecx >> 24);
    return s;
}

// ----- 01H - Basic CPUID Information -----
// EAX - Type, Family, Model, and Stepping ID 
public int GetExtendedFamilyID() // EAX[27:20] - 8 bits
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EAX;
    }
    return (e >> 20) & 0xFF;
}
public int GetExtendedModelID() // EAX[19:16] - 4 bits
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EAX;
    }
    return (e >> 16) & 0xF;
}
public int GetProcessorType() // EAX[13:12] - 2 bits
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EAX;
    }
    return (e >> 12) & 3;
}
public int GetFamilyID() // EAX[11:8] - 4 bits
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EAX;
    }
    return (e >> 8) & 0xF;
}
public int GetModel() // EAX[7:4] - 4 bits 
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EAX;
    }
    return (e >> 4) & 0xF;
}
public int GetSteppingID() // EAX[3:0] - 4 bits
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EAX;
    }
    return e & 0xF;
}

// EBX - Brand Index, CLFLUSH, Max addressable IDs, Initial APIC ID
// EBX[07:00] - Brand Index.
public int GetBrandIndex()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EBX;
    }
    return e & 0xFF;
}
// EBX[15:08], 8 bits - CLFLUSH line size
// (Value ∗ 8 = cache line size in bytes; used also by CLFLUSHOPT).
public int GetClflushLineSize()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EBX;
    }
    return (e >> 8) & 0xFF;
}
// EBX[23:16], 8 bits - Maximum number of addressable IDs for
// logical processors in this physical package.
public int GetMaxNumAddressableIDs()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EBX;
    }
    return (e >> 16) & 0xFF;
}
// EBX[31:24], 8 bits - Initial APIC ID.
public int GetInitialAPICID()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EBX;
    }
    return (e >> 24) & 0xFF;
}

// ECX - Feature flags
// Bit 00 - SSE3
public bool SupportsSSE3()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e & 1;
}
// Bit 01 - PCLMULQDQ
public bool SupportsPCLMULQDQ()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 1 & 1;
}
// Bit 02 - DTES64
public bool SupportsDTES64()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 2 & 1;
}
// Bit 03 - MONITOR
public bool SupportsMONITOR()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 3 & 1;
}
// Bit 04 - DS-CPL
public bool SupportsDS_CPL()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 4 & 1;
}
// Bit 05 - VMX
public bool SupportsVMX()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 5 & 1;
}
// Bit 06 - SMX
public bool SupportsSMX()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 6 & 1;
}
// Bit 07 - EIST
public bool SupportsEIST()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 7 & 1;
}
// Bit 08 - TM2
public bool SupportsTM2()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 8 & 1;
}
// Bit 09 - SSSE3
public bool SupportsSSSE3()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 9 & 1;
}
// Bit 10 - CNXT-ID
public bool SupportsCNXT_ID()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 10 & 1;
}
// Bit 11 - SDBG
public bool SupportsSDBG()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 11 & 1;
}
// Bit 12 - FMA
public bool SupportsFMA()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 12 & 1;
}
// Bit 13 - CMPXCHG16B
public bool SupportsCMPXCHG16B()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 13 & 1;
}
// Bit 14 - xTPR Update Control
public bool SupportsxTPRUpdateControl()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 14 & 1;
}
// Bit 15 - PDCM
public bool SupportsPDCM()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 15 & 1;
}
// Bit 16 - Reserved
// Bit 17 - PCID
public bool SupportsPCID()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 17 & 1;
}
// Bit 18 - DCA
public bool SupportsDCA()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 18 & 1;
}
// Bit 19 - SSE4.1
public bool SupportsSSE41()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 19 & 1;
}
// Bit 20 - SSE4.2
public bool SupportsSSE42()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 20 & 1;
}
// Bit 21 - x2APIC
public bool Supportsx2APIC()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 21 & 1;
}
// Bit 22 - MOVBE
public bool SupportsMOVBE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 22 & 1;
}
// Bit 23 - POPCNT
public bool SupportsPOPCNT()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 23 & 1;
}
// Bit 24 - TSC-Deadline
public bool SupportsTSC_Deadline()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 24 & 1;
}
// Bit 25 - AESNI
public bool SupportsAESNI()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 25 & 1;
}
// Bit 26 - XSAVE
public bool SupportsXSAVE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 26 & 1;
}
// Bit 27 - OSXSAVE
public bool SupportsOSXSAVE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 27 & 1;
}
// Bit 28 - AVX
public bool SupportsAVX()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 28 & 1;
}
// Bit 29 - F16C
public bool SupportsF16C()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 29 & 1;
}
// Bit 30 - RDRAND
public bool SupportsRDRAND()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, ECX;
    }
    return e >> 30 & 1;
}
// Bit 31 is not used, always returns 0.

// EDX - Feature flags
// Bit 00 - FPU
public bool SupportsFPU()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e & 1;
}
// Bit 01 - VME
public bool SupportsVME()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 1 & 1;
}
// Bit 02 - DE
public bool SupportsDE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 2 & 1;
}
// Bit 03 - PSE
public bool SupportsPSE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 3 & 1;
}
// Bit 04 - TSC
public bool SupportsTSC()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 4 & 1;
}
// Bit 05 - MSR
public bool SupportsMSR()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 5 & 1;
}
// Bit 06 - PAE
public bool SupportsPAE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 6 & 1;
}
// Bit 07 - MCE
public bool SupportsMCE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 7 & 1;
}
// Bit 08 - CX8
public bool SupportsCX8()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 8 & 1;
}
// Bit 09 - APIC
public bool SupportsAPIC()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 9 & 1;
}
// Bit 10 - Reserved
// Bit 11 - SEP
public bool SupportsSEP()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 11 & 1;
}
// Bit 12 - MTRR
public bool SupportsMTRR()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 12 & 1;
}
// Bit 13 - PGE
public bool SupportsPGE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 13 & 1;
}
// Bit 14 - MCA
public bool SupportsMCA()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 14 & 1;
}
// Bit 15 - CMOV
public bool SupportsCMOV()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 15 & 1;
}
// Bit 16 - PAT
public bool SupportsPAT()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 16 & 1;
}
// Bit 17 - PSE-36
public bool SupportsPSE_36()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 17 & 1;
}
// Bit 18 - PSN
public bool SupportsPSN()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 18 & 1;
}
// Bit 19 - CLFSH
public bool SupportsCLFSH()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 19 & 1;
}
// Bit 20 - Reserved
// Bit 21 - DS
public bool SupportsDS()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 21 & 1;
}
// Bit 22 - ACPI
public bool SupportsACPI()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 22 & 1;
}
// Bit 23 - MMX
public bool SupportsMMX()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 23 & 1;
}
// Bit 24 - FXSR
public bool SupportsFXSR()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 24 & 1;
}
// Bit 25 - SSE
public bool SupportsSSE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 25 & 1;
}
// Bit 26 - SSE2
public bool SupportsSSE2()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 26 & 1;
}
// Bit 27 - SS
public bool SupportsSS()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 27 & 1;
}
// Bit 28 - HTT
public bool SupportsHTT()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 28 & 1;
}
// Bit 29 - TM
public bool SupportsTM()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 29 & 1;
}
// Bit 30 - Reserved
// Bit 31 - PBE
public bool SupportsPBE()
{
    int e;
    asm
    {
        mov EAX, 1;
        cpuid;
        mov e, EDX;
    }
    return e >> 31 & 1;
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

// ---- Misc ----

public CPU_INFO_INTEL GetIntelInfo()
{
    CPU_INFO_INTEL i;

    //TODO: GetIntelInfo() -> Batch info

    return i;
}

public class CPU_INFO_INTEL
{
    public bool SupportsTurboBoostTechnology;
    public string Vendor;
}

public CPU_INFO_INTEL GetAmdInfo()
{
    CPU_INFO_INTEL i;

    //TODO: GetAmdInfo() -> Batch info

    return i;
}

public class CPU_INFO_AMD
{

}
