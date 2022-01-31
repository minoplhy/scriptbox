@echo off
if "%1"=="runas" (
  cd %~dp0
) else (
  powershell Start -File "cmd '/K %~f0 runas'" -Verb RunAs
)
reg add HKLM\Software\WireGuard /v MultipleSimultaneousTunnels /t REG_DWORD /d 1 /f