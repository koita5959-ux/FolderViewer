@echo off
echo === DesktopKit.FolderViewer ビルド＆インストーラー作成 ===

REM Step 1: dotnet publish（ソース → exe）
echo.
echo [Step 1] dotnet publish 実行中...
cd %~dp0FolderViewer
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o ..\publish\
if errorlevel 1 (
    echo.
    echo エラー: dotnet publish に失敗しました。
    pause
    exit /b 1
)

REM Step 2: Inno Setupコンパイル（exe → Setup.exe）
echo.
echo [Step 2] Inno Setup コンパイル実行中...
cd %~dp0
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss
if errorlevel 1 (
    echo.
    echo エラー: Inno Setup コンパイルに失敗しました。
    pause
    exit /b 1
)

echo.
echo ビルド完了しました。
echo   exe: publish\DesktopKit.FolderViewer.exe
echo   インストーラー: installer\FolderViewer_Setup_v1.00.exe
pause
