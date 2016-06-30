# ddcpuid
## A CPUID tool

This small utility will reveal everything through `CPUID` -- A CPU instruction to get information about the CPU.

It is planned to probably do a GUI version as well, there is a nice list of [libraries](https://wiki.dlang.org/Libraries_and_Frameworks) for it too.

Progress:
- Intel: ~25%
- AMD: --

If you have any questions, don't hesitate to ask.

## Notes
This is Intel centered for now, AMD specific features will come one day.

This project uses the standard library (Phobos) and runtime (druntime).

## Compiling
I highly recommend the Digital Mars D (dmd) compiler, since the GNU D Compiler (gdc) does not support the Intel-like syntax.

LLVM D Compiler (ldc) supports the Intel-like, the GCC syntax, and the LLVM inline IR ([LDC](https://wiki.dlang.org/LDC_inline_IR)), but you need MinGW for Windows if you want to run it on Windows.

THIS TOOL IS ONLY FOR x86 AND AMD64 (x86-64) ARCHITECTURES.

License: [MIT License](LICENSE)