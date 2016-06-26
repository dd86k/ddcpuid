import std.stdio;

void main()
{
    int max = GetHighestLeaf();

    int _eax, _ebx, _ecx, _edx, _ebp, _esp, _edi, _esi;
    for (int b = 0; b < max; ++b)
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
        writefln("----- FI=%XH -----", b);
        writefln("EAX=%-8X EBX=%-8X ECX=%-8X EDX=%-8X", _eax, _ebx, _ecx, _edx);
        writefln("EBP=%-8X ESP=%-8X EDI=%-8X ESI=%-8X", _ebp, _esp, _edi, _esi);
    }

    CPU_INFO_INTEL i;
    // doing "new CPU_INFO_INTEL();" will create a pointer, still usable btw
    i.SupportsTurboBoostTechnology = SupportsTurboBoost();

    writeln();
    writefln("Turbo Boost Available: %s", i.SupportsTurboBoostTechnology);
}

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

public CPU_INFO_INTEL GetInfo()
{
    CPU_INFO_INTEL i;

    //TODO: GetInfo() -> Batch info

    return i;
}

public struct CPU_INFO_INTEL
{
    public bool SupportsTurboBoostTechnology;
}
