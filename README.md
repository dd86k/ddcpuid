# ddcpuid, CPUID tool

ddcpuid is a x86 processor information tool. Currently supports Intel and AMD
processors.

_Currently featuring 154 CPUID bits documented and counting!_

The latest ddcpuid manual is available here:
[dd86k.space](https://dd86k.space/docs/ddcpuid-manual.pdf) (PDF).

Both the manual and tool is meant to be used together to better understand x86.

# Compiling

Since ddcpuid is a single file, you simply need to invoke the compiler:
`gdc ddcpuid.d`. Some compilers accept a module name, making
`dmd ddcpuid` possible.

It is highly recommended to use the `-betterC` switch when compiling.

Compilers supported:
- DMD (best supported)
- LDC (best optimizations, but see `LDC Issues`)
- GDC (experimental, see `GDC Issues`)

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

## GDC Issues

### Optimizations

Compiling above O0 will yield invalid results, and that's because of my
incapability to understand the complex extended GCC inline assembler
format. I very much dislike it.

## LDC Issues

### Legacy stdio Definitions

LDC versions 1.13 and 1.14 do not include `legacy_stdio_definitions.lib`,
making compilation impossible when using `-betterC`.