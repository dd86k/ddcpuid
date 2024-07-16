@ECHO OFF

REM Should cover recent version
dmd -unittest -main src\ddcpuid.d src\main.d -of=test.exe
test.exe
ECHO Test exited with code %ERRORLEVEL%
DEL test.exe