@echo off
rem Builds the MemTestPlus core one seed after another, each with the whole PC.
rem Keeps the builds that meet timing as Builds\memtestplus_seedN_+SETUP.rbf, throws the rest away.
rem Press any key to stop after the current build.
rem Optional: build_seeds.bat FIRST [LAST]   e.g. build_seeds.bat 20 to start at seed 20

setlocal
cd /d "%~dp0"
for %%I in ("%~dp0.") do set "SRC=%%~fI"
set "WORK=%~dp0seed_work"
set "OUT=%~dp0Builds"
set "IMAGE=theypsilon/quartus-lite-c5:17.0.2"
set "SEED=1"
set "LAST=0"
if not "%~1"=="" set "SEED=%~1"
if not "%~2"=="" set "LAST=%~2"

if not exist "%SRC%\memtestplus.qpf" (
	echo Project not found next to this bat.
	pause
	exit /b 1
)
if not exist "%OUT%" mkdir "%OUT%"
docker rm -f mtp_seed >nul 2>&1
powershell -NoProfile -Command "try{while([Console]::KeyAvailable){[void][Console]::ReadKey($true)}}catch{}"
echo MemTestPlus seed builds started %DATE% %TIME%>> "%OUT%\seed_results.txt"
echo Building from seed %SEED%. Press any key to stop after the current build.
echo.

:loop
if exist "%WORK%" rmdir /s /q "%WORK%"
mkdir "%WORK%"
echo [%TIME:~0,8%] seed %SEED% building ...
docker run -d --name mtp_seed -v "%SRC%:/src:ro" -v "%WORK%:/out" %IMAGE% bash -c "cp -r /src /build && cd /build && rm -rf .git releases sim Builds build seed_work tools ui && (grep -q '^set_global_assignment -name SEED ' memtestplus.qsf && sed -i 's/^set_global_assignment -name SEED .*/set_global_assignment -name SEED %SEED%\r/' memtestplus.qsf || printf 'set_global_assignment -name SEED %SEED%\r\n' >> memtestplus.qsf); timeout 3600 quartus_sh --flow compile memtestplus.qpf > build.log 2>&1; quartus_sta -t paths.tcl > paths.log 2>&1; s=$(grep 'Worst-case setup slack is' build.log | awk '{print $NF}' | sort -g | head -1); h=$(grep 'Worst-case hold slack is' build.log | awk '{print $NF}' | sort -g | head -1); r=FAIL; grep -q 'Full Compilation was successful' build.log && ! grep -q 'Timing requirements not met' build.log && r=PASS; echo $r $s $h > /out/result.txt; cp -f output_files/memtestplus.rbf /out/ 2>/dev/null; cp -f build.log paths.log /out/ 2>/dev/null; cp -f output_files/*.rpt output_files/*.summary /out/ 2>/dev/null" >nul
if errorlevel 1 (
	echo Docker didn't start the build. Is Docker Desktop running?
	goto done
)
docker wait mtp_seed >nul
docker rm mtp_seed >nul 2>&1
call :check %SEED%
if "%SEED%"=="%LAST%" goto done
set /a SEED+=1
powershell -NoProfile -Command "try{if([Console]::KeyAvailable){exit 1}}catch{}; exit 0"
if errorlevel 1 goto done
goto loop

:done
if exist "%WORK%" rmdir /s /q "%WORK%"
echo.
echo Stopped. Kept builds are in Builds, results in Builds\seed_results.txt
pause
exit /b 0

:check
copy /y "%WORK%\build.log" "%OUT%\last_build.log" >nul 2>&1
copy /y "%WORK%\memtestplus.sta.rpt" "%OUT%\last_timing.rpt" >nul 2>&1
copy /y "%WORK%\paths.txt" "%OUT%\last_paths.txt" >nul 2>&1
set "R=FAIL"
set "S=?"
set "H=?"
if exist "%WORK%\result.txt" for /f "usebackq tokens=1-3" %%a in ("%WORK%\result.txt") do (
	set "R=%%a"
	set "S=%%b"
	set "H=%%c"
)
if "%R%"=="PASS" (
	copy /y "%WORK%\memtestplus.rbf" "%OUT%\memtestplus_seed%1_+%S%.rbf" >nul
	echo            seed %1: kept   memtestplus_seed%1_+%S%.rbf  ^(setup +%S% ns, hold +%H% ns^)
	echo seed %1: kept   memtestplus_seed%1_+%S%.rbf  setup +%S% ns, hold +%H% ns>> "%OUT%\seed_results.txt"
) else (
	echo            seed %1: thrown away ^(setup %S% ns, hold %H% ns^)
	echo seed %1: thrown away  setup %S% ns, hold %H% ns>> "%OUT%\seed_results.txt"
)
exit /b 0
