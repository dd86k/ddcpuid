# ddcpuid
## A CPUID tool

This small utility will reveal everything through `CPUID` -- A CPU instruction to get information about the CPU.

It is planned to probably do a GUI version as well, there is a nice list of [libraries](https://wiki.dlang.org/Libraries_and_Frameworks) for it too.

If you have any questions, suggestions, find any bugs, or notice incorect data, please either start an Issue or send an [email](mailto:devddstuff@gmail.com)!

## Goal

My goal is to provide a tool that provides human readable information about the processor. If the user wishes to know more technical data, they may so with the `-D` (details) switch.

The `--debug` switch is provided for debugging purposes.

## Compiling
I highly recommend the Digital Mars D (dmd) compiler, since the GNU D Compiler (gdc) does not support the Intel-like syntax.

The LLVM D Compiler (ldc2) supports the Intel-like syntax, the GCC syntax, and the LLVM inline IR ([Wiki.dlang.org](https://wiki.dlang.org/LDC_inline_IR)), but requires MinGW for Windows.

This project uses the standard library (Phobos) and runtime (druntime).

THIS TOOL IS ONLY FOR x86 AND AMD64 (x86-64) PROCESSORS.

License: [MIT License](LICENSE)