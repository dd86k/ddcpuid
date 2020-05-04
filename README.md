# ddcpuid, CPUID tool

ddcpuid is a x86 processor information tool. Currently supports Intel and AMD
processors.

_Currently featuring 132 CPUID bits documented and counting!_

The ddcpuid Technical Manual is available here:
[dd86k.space](https://dd86k.space/docs/ddcpuid-manual.pdf) (PDF).

Both the manual and tool is meant to be used together to fully understand
available features on the processor.

# Compiling

It is highly recommended to use the `-betterC` switch when compiling.

DMD, GDC, and LDC compilers are supported. Best supported by DMD.

## GDC Notes

GDC support is still experimental. **Compiling above -O1 segfaults at run-time.**
(tested on GDC 8.3.0-6ubuntu1~18.04.1)

## LDC Notes

Since LDC 1.13.0 includes lld-link on Windows platforms, the project may fail
to link. Using the older linker from Microsoft will likely fail as well. No 
workarounds has been found up to this date other than using LDC 1.12.x.

**UPDATE**: This has been fixed in 1.15. Linker now includes
`legacy_stdio_definitions.lib`.

Recent versions of LDC (tested on 1.8.0 and 1.15) may "over-optimize" the hleaf
function (when compiling with -O), and while it's supposed to return the
highest cpuid leaf, it may return 0. To test such situation, use the -r switch
and see if the condition applies.

**UPDATE**: This has been fixed in commit d64fbceb68dbd9135b0c130776e9bb2c13a96237.
New function receives structure as reference to be populated. `hleaf` removed.

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