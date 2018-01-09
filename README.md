# ddcpuid, A CPUID tool

A simple/dumb CPUID tool.

## Compiling

I highly recommend the `-betterC` switch:
```
dmd -betterC -boundscheck=off -release -O ddcpuid
```

For some reason, ddcpuid will not compile under DMD 2.078.0.