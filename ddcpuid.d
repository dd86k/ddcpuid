import std.stdio;

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
    s ~= cast(char)(ebx & 0xFF);
    s ~= cast(char)((ebx >>  8) & 0xFF);
    s ~= cast(char)((ebx >> 16) & 0xFF);
    s ~= cast(char)((ebx >> 24) & 0xFF);
    s ~= cast(char)(ecx & 0xFF);
    s ~= cast(char)((ecx >>  8) & 0xFF);
    s ~= cast(char)((ecx >> 16) & 0xFF);
    s ~= cast(char)((ecx >> 24) & 0xFF);
    s ~= cast(char)(edx & 0xFF);
    s ~= cast(char)((edx >>  8) & 0xFF);
    s ~= cast(char)((edx >> 16) & 0xFF);
    s ~= cast(char)((edx >> 24) & 0xFF);
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
// EBX[15:08], 8 bits - CLFLUSH line size (Value ∗ 8 = cache line size in bytes; used also by CLFLUSHOPT).
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
// EBX[23:16], 8 bits - Maximum number of addressable IDs for logical processors in this physical package.
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
    return e & 1;
}
// EDX - Feature flags







// 06H - Thermal and Power Management Leaf

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
    return (e & 2) == 2;
}

// ---- Misc ----

// Eventually, the information will be gathered in a batch, instead of
// going to every method invidually.

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
