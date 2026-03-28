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

REM Step 3: 配布ZIP作成（Setup.exe + ランタイムを1つのZIPにまとめる）
echo.
echo [Step 3] 配布ZIP作成中...
cd %~dp0
powershell -NoProfile -Command "Compress-Archive -Path 'installer\FolderViewer_Setup_v1.01.exe','windowsdesktop-runtime-8.0.24-win-x64.exe' -DestinationPath 'FolderViewer1.01_installer.zip' -Force"
if errorlevel 1 (
    echo.
    echo エラー: 配布ZIPの作成に失敗しました。
    pause
    exit /b 1
)

echo.
echo ビルド完了しました。
echo   exe: publish\DesktopKit.FolderViewer.exe
echo   インストーラー: installer\FolderViewer_Setup_v1.01.exe
echo   配布ZIP: FolderViewer1.01_installer.zip
pause
