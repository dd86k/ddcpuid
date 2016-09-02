# ddcpuid
## A CPUID tool

This small utility will reveal everything through `CPUID` -- A CPU instruction to get information about the CPU.

It is planned to probably do a GUI version as well, there is a nice list of [libraries](https://wiki.dlang.org/Libraries_and_Frameworks) for it too.

If you have any questions, suggestions, requests, find any bugs, or notice incorect data, please either start an Issue or send an [email](mailto:devddstuff@gmail.com)!

The output and the project will change often!

## Goal

My goal is to make a tool that provides complete human readable information about the processor for users of all types: Simple user, technician, and programmers.

## Usage

By default, it will show basic information.

`-D`, `--details` -- Details, this switches will show more, technical, information.

`--debug` -- Debug, shows debugging information in a chart.

`-O`, `--override` -- Overrides the maximum leaf to `20h` and `8000_0020h`.

`--help` -- Shows the help screen and quits.

`--version` -- Shows the version screen and quits.

## Contributing
Any help is appreciated! I recommend reading the Intel and AMD programming guides and verify your information before suggesting a fix.

## Compiling
I highly recommend the Digital Mars D (dmd) compiler, since the GNU D Compiler (gdc) does not support the Intel-like Assembly syntax.

The LLVM D Compiler (ldc2) supports the Intel-like syntax, the GCC syntax, and the LLVM inline IR ([Wiki.dlang.org](https://wiki.dlang.org/LDC_inline_IR)), but requires MinGW for Windows.

This project uses the standard library (Phobos) and runtime (druntime).

The executable:
```
dmd ddcpuid.d
```

The Windows DLL: (WIP)
```
dmd -version=DLL -ofddcpuid.dll -shared ddcpuid.d ddcpuid.def
```

I still need to make external references to the CPU_INFO class (in source and definition file).

THIS TOOL IS ONLY FOR x86 AND AMD64 (x86-64) PROCESSORS.

License: [MIT License](LICENSE)