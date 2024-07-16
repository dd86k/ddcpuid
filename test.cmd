@ECHO OFF

REM Should cover recent version
dmd -unittest -main src\ddcpuid.d src\main.d -of=test.exe
test.exe
DEL test.exe