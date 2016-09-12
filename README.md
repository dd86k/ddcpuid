# ddcpuid
## A CPUID tool

This small utility will reveal everything through `CPUID` -- A CPU instruction to get information about the CPU.

It is planned to probably do a GUI version as well, there is a nice list of [libraries](https://wiki.dlang.org/Libraries_and_Frameworks) for it too.

If you have any questions, suggestions, requests, find any bugs, or notice incorect data, please either start an Issue or send an [email](mailto:devddstuff@gmail.com)!

The output and the project will change often!

## Goal

My goal is to make a tool that provides complete human readable information about the processor for users of all types: users, technicians, and programmers.

## Usage

By default, it will show basic information.

| Switch | Description |
| :---: | :---: |
| `-D`, `--details` | Show more technician-related details. |
| `--debug` | Show debugging information. |
| `-O`, `--override` | Override maximum leaves to 20h and 8000_0020h. |
| `-h`, `--help` | Show help screen and quit. |
| `-v`, `--version` | Show version screen and quit. |

## Contributing
Any help is appreciated! I recommend reading the Intel and AMD programming guides and verify your information before suggesting a fix.

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