# ddcpuid
## A CPUID tool

This small utility will reveal everything through the `CPUID` instruction without any library or third-party help. 

If you have any questions, suggestions, requests, find any bugs, or notice incorect data, please either start an Issue or send an [email](mailto:devddstuff@gmail.com)!

## Goal

My goal is to make a tool that provides complete human readable information about the processor for users of all types: users, technicians, and programmers, without the use of external library nor the standard library.

## Usage (v0.3.0)

| Switch | Description |
| :---: | :---: |
| `-d`, `--details` | Show more details. |
| `-V`, `--verbose` | Show debugging information. |
| `-o`, `--override` | Override maximum leaves to 20h and 8000_0020h. |
| `-r`, `--raw` | Show raw CPUID information. |
| `-h`, `--help` | Show help screen and quit. |
| `-v`, `--version` | Show version screen and quit. |

## Contributing
Any help is appreciated! I recommend reading the Intel and AMD reference programming guides and verifying your information before suggesting a fix.

## Compiling

### Requirements
- `dmd` — Digital Mars D compiler

That's it! The standard Phobos and druntime.

### Compile
- Executable (x86):
```
dmd ddcpuid.d
```
- Executable (Optimized, x86):
```
dmd -O -release -inline -boundscheck=off ddcpuid.d
```
- Windows DLL (Windows, x86) (WIP):
```
dmd -version=DLL -ofddcpuid.dll -shared ddcpuid.d ddcpuid.def
```

THIS TOOL IS ONLY FOR x86 AND AMD64 (x86-64) BASED PROCESSORS.

Other architectures may become supported in the future.

[MIT License](LICENSE)