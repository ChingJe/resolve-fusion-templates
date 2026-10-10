@echo off
rem Installs, updates or removes the Fusion templates in this folder for DaVinci Resolve.
rem Double-click to get a menu, or run:  install.bat install | remove | status  [nopause]
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

set "SRC=%~dp0templates"
set "RESOLVE=%APPDATA%\Blackmagic Design\DaVinci Resolve"
set "DEST=%RESOLVE%\Support\Fusion\Templates\Edit"
set "MODE=%~1"
set "NOPAUSE=%~2"
set /a NEW=0, UPDATED=0, SAME=0, FAILED=0, REMOVED=0, TOTAL=0, INSTALLED=0

echo.
echo  ==============================================
echo    resolve-fusion-templates 安裝程式
echo  ==============================================
echo.

rem ---- 檢查一：範本檔在不在 ----
if not exist "%SRC%\Titles\*.setting" if not exist "%SRC%\Effects\*.setting" if not exist "%SRC%\Transitions\*.setting" goto :no_source

rem ---- 檢查二：這台電腦有沒有 Resolve 的設定資料夾 ----
if not exist "%RESOLVE%\" goto :no_resolve

rem ---- 檢查三：Resolve 是不是開著 ----
set "RUNNING=0"
tasklist /FI "IMAGENAME eq Resolve.exe" 2>nul | "%SystemRoot%\System32\find.exe" /I "Resolve.exe" >nul && set "RUNNING=1"

echo  範本來源：%SRC%
echo  安裝位置：%DEST%
echo.
call :count
echo  這個資料夾裡有 %TOTAL% 個範本，其中 %INSTALLED% 個已經裝在 Resolve 裡。
echo.

if /I "%MODE%"=="install" goto :install
if /I "%MODE%"=="remove" goto :remove
if /I "%MODE%"=="status" goto :status
if not "%MODE%"=="" goto :bad_mode

echo  要做什麼？
echo    1  安裝或更新全部範本
echo    2  移除這些範本
echo    3  只看目前裝了哪些
echo    4  離開
echo.
choice /C 1234 /N /M "  請按 1、2、3 或 4："
if errorlevel 4 goto :end
if errorlevel 3 goto :status
if errorlevel 2 goto :remove_confirm
goto :install

rem ------------------------------------------------------------------
:install
echo.
echo  開始安裝……
echo.
for %%T in (Titles Effects Transitions) do call :install_folder %%T
echo.
echo  ----------------------------------------------
echo   新安裝 %NEW% 個，更新 %UPDATED% 個，原本就是最新的 %SAME% 個。
if not "%FAILED%"=="0" goto :install_failed
echo  ----------------------------------------------
echo.
set /a CHANGED=NEW+UPDATED
if "%CHANGED%"=="0" goto :nothing_changed
if "%RUNNING%"=="1" goto :need_restart
echo  完成。下次開啟 Resolve 就會看到。
goto :where

:nothing_changed
echo  全部都已經是最新的，沒有需要改的。
goto :where

:need_restart
echo  完成。但是 Resolve 現在開著，它只在啟動時讀取範本，
echo  請先存檔，把 Resolve 整個關掉再重新開啟，才會看到新的或更新過的範本。
goto :where

:install_failed
echo   有 %FAILED% 個沒有成功，請往上看是哪幾個。
echo  ----------------------------------------------
echo.
echo  常見原因：檔案被防毒軟體擋住，或那個資料夾沒有寫入權限。
goto :end

:where
echo.
echo  在 Edit 頁面左上角開啟 Effects 特效庫，範本在這三個地方：
echo    標題    Toolbox ^> Titles ^> Fusion Titles
echo    特效    Toolbox ^> Effects ^> Fusion Effects
echo    轉場    Toolbox ^> Video Transitions ^> Fusion Transitions
echo.
echo  每個範本的用法和參數說明在 docs\templates 資料夾。
goto :end

rem ------------------------------------------------------------------
:remove_confirm
echo.
echo  會從 Resolve 的範本資料夾刪除和這裡同名的 %INSTALLED% 個範本檔。
echo  你自己放的其他範本不會動到，這個資料夾裡的原始檔也不會動到。
echo  已經用了這些範本的專案，移除後那些片段會顯示成遺失。
echo.
choice /C YN /N /M "  確定要移除嗎？請按 Y 或 N："
if errorlevel 2 goto :end

:remove
echo.
for %%T in (Titles Effects Transitions) do call :remove_folder %%T
echo.
echo  ----------------------------------------------
echo   移除了 %REMOVED% 個。
echo  ----------------------------------------------
if "%RUNNING%"=="1" echo  Resolve 現在開著，重新啟動之後它們才會從特效庫消失。
goto :end

rem ------------------------------------------------------------------
:status
echo.
for %%T in (Titles Effects Transitions) do call :status_folder %%T
echo.
echo  「需要更新」表示這裡的版本和 Resolve 裡的不一樣，重新安裝就會換成這裡的。
goto :end

rem ------------------------------------------------------------------
:no_source
echo  [找不到範本檔]
echo.
echo  這支程式要和 templates 資料夾放在一起才能用，
echo  templates 底下要有 Titles、Effects、Transitions 三個子資料夾。
echo.
echo  如果你是從壓縮檔裡直接點兩下執行的，請先把整個壓縮檔解開，
echo  再執行解開後資料夾裡的 install.bat。
goto :end

:no_resolve
echo  [找不到 DaVinci Resolve 的設定資料夾]
echo.
echo  應該要有這個資料夾：
echo    %RESOLVE%
echo.
echo  可能的原因：
echo    1. 這台電腦還沒有安裝 DaVinci Resolve。
echo    2. 安裝了，但是這個 Windows 帳號還沒有開過。請先開啟 Resolve 一次再回來執行。
echo.
echo  為了避免把檔案放到錯的地方，這次什麼都沒有改。
goto :end

:bad_mode
echo  [不認得的參數] %MODE%
echo.
echo  可以用的參數：install、remove、status。不加參數會顯示選單。
goto :end

rem ------------------------------------------------------------------
rem  副程式
rem ------------------------------------------------------------------
:count
for %%T in (Titles Effects Transitions) do for %%F in ("%SRC%\%%T\*.setting") do call :count_one "%%T" "%%~nxF"
exit /b

:count_one
set /a TOTAL+=1
if exist "%DEST%\%~1\%~2" set /a INSTALLED+=1
exit /b

:install_folder
if not exist "%SRC%\%1\*.setting" exit /b
if not exist "%DEST%\%1\" mkdir "%DEST%\%1" 2>nul
if not exist "%DEST%\%1\" (
  echo   [失敗] 建立不了資料夾 %DEST%\%1
  set /a FAILED+=1
  exit /b
)
for %%F in ("%SRC%\%1\*.setting") do call :install_one "%1" "%%~fF" "%%~nxF" "%%~nF"
exit /b

:install_one
set "LABEL=新安裝"
if exist "%DEST%\%~1\%~3" set "LABEL=更新"
if exist "%DEST%\%~1\%~3" fc /b "%~2" "%DEST%\%~1\%~3" >nul 2>&1 && set "LABEL=已是最新"
if "%LABEL%"=="已是最新" (
  set /a SAME+=1
  echo   [已是最新] %~1\%~4
  exit /b
)
copy /Y "%~2" "%DEST%\%~1\%~3" >nul 2>&1
fc /b "%~2" "%DEST%\%~1\%~3" >nul 2>&1
if errorlevel 1 (
  set /a FAILED+=1
  echo   [失敗]     %~1\%~4
  exit /b
)
if "%LABEL%"=="更新" (set /a UPDATED+=1) else (set /a NEW+=1)
echo   [%LABEL%]   %~1\%~4
exit /b

:remove_folder
for %%F in ("%SRC%\%1\*.setting") do call :remove_one "%1" "%%~nxF" "%%~nF"
exit /b

:remove_one
if not exist "%DEST%\%~1\%~2" exit /b
del /Q "%DEST%\%~1\%~2" >nul 2>&1
if exist "%DEST%\%~1\%~2" (
  echo   [刪不掉]   %~1\%~3
  exit /b
)
set /a REMOVED+=1
echo   [已移除]   %~1\%~3
exit /b

:status_folder
for %%F in ("%SRC%\%1\*.setting") do call :status_one "%1" "%%~fF" "%%~nxF" "%%~nF"
exit /b

:status_one
if not exist "%DEST%\%~1\%~3" (
  echo   [沒安裝]   %~1\%~4
  exit /b
)
fc /b "%~2" "%DEST%\%~1\%~3" >nul 2>&1
if errorlevel 1 (echo   [需要更新] %~1\%~4) else (echo   [已是最新] %~1\%~4)
exit /b

rem ------------------------------------------------------------------
:end
echo.
if /I not "%NOPAUSE%"=="nopause" pause
endlocal
