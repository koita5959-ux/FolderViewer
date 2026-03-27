@echo off
chcp 65001 >nul
echo ===== DesktopKit FolderViewer インストーラー作成 =====
echo.

REM --- publish ---
echo [1/2] dotnet publish 実行中...
cd /d "%~dp0FolderViewer"
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o "%~dp0publish"
if errorlevel 1 (
    echo [エラー] publish に失敗しました。
    pause
    exit /b 1
)
echo       publish 完了
echo.

REM --- Inno Setup コンパイル ---
echo [2/2] Inno Setup コンパイル中...
cd /d "%~dp0"

set "ISCC="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"

if "%ISCC%"=="" (
    echo [エラー] Inno Setup 6 が見つかりません。
    echo         https://jrsoftware.org/isdl.php からインストールしてください。
    pause
    exit /b 1
)

"%ISCC%" setup.iss
if errorlevel 1 (
    echo [エラー] インストーラー作成に失敗しました。
    pause
    exit /b 1
)

echo.
echo ===== 完了 =====
echo 出力: installer\FolderViewer_Setup_v1.00.exe
echo.
pause
