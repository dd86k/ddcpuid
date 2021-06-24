# ddcpuid, CPUID tool

ddcpuid is a x86 processor information tool. Currently supports Intel and AMD
processors.

- Can be used as a stand-alone tool or as a library.
- BetterC compatible.
- DUB compatible.
- The library does not rely on any runtime (C, D) nor the OS.
- Surpasses CPU-Z, [Intel's Go CPUID](https://github.com/intel-go/cpuid/) module, and Druntime's `core.cpuid` module.
- _Currently featuring 240 CPUID bits documented and counting!_

Want to better understand x86? There's the
[ddcpuid Technical Manual](https://dd86k.space/docs/ddcpuid-manual.pdf) (PDF)!

# Compiling

The best way to compile ddcpuid is using DUB.

Compilers supported:
- DMD >= 2.068.0 (best supported)
  - For earlier versions (tested on dmd 2.067.1), see how to perform a [manual compilation](#manually).
- LDC >= 1.0.0 (best optimizations, but see [LDC Issues](#ldc-issues))
  - For 0.17.1, see how to perform a [manual compilation](#manually).
- GDC >= 9.0.0 (extremely experimental, see [GDC Issues](#gdc-issues))

## DUB

Using dub(1) is rather straightforward.

To learn how to use DUB, visit [this page](https://dub.pm/commandline.html).

## Makefile

The Makefile relies on GNU Make (gmake/gnumake).

Available variables:
- `DC`: D compiler, defaults to `dmd`
- `PREFIX`: installation path prefix, defaults to `/usr/local`

Available actions:
- debug (default)
- release
- install
- uninstall

Examples:
- `make`: Produce a debug build
- `make release DC=ldc`: Produce a release build with LDC

## Manually

Since ddcpuid only consists of two source files, both being in the `src`
folder, it's still pretty easy to perform a compilation by hand.

Here's an example that works on any compiler:
```
dmd src/ddcpuid.d src/main.d -ofddcpuid
ldc2 src/ddcpuid.d src/main.d -ofddcpuid
gdc src/ddcpuid.d src/main.d -oddcpuid
```

You get the idea.

## GDC Issues

### Optimizations

**UPDATE**: ddcpuid 0.18.0 is now fully compatible with GDC. No longer an issue!

Compiling above O0 will yield invalid results, and that's because of my
incapability to understand the complex extended GCC inline assembler
format. Especially since D has no `volatile` type qualifier.

Tests:
- 8.4.0: Early runtime crash with -O1 and higher optimization levels.
- 9.3.0: Runtime crash + incorrect information with -O1 and higher optimization levels.
- 10.2.0: Same as 9.3.

## LDC Issues

### Legacy stdio Definitions

On Windows, LDC versions 1.13 and 1.14 do not include
`legacy_stdio_definitions.lib`, making it impossible to compile the project
using `-betterC`.
