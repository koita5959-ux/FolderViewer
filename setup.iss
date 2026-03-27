[Setup]
AppId=DesktopKit_FolderViewer
AppName=DesktopKit FolderViewer
AppVersion=1.00
AppPublisher=DesktopKit
DefaultDirName={localappdata}\Programs\DesktopKit\FolderViewer
DefaultGroupName=DesktopKit
DisableProgramGroupPage=yes
OutputDir=installer
OutputBaseFilename=FolderViewer_Setup_v1.00
Compression=lzma
SolidCompression=yes
UninstallDisplayName=DesktopKit FolderViewer
UninstallDisplayIcon={app}\DesktopKit.FolderViewer.exe
PrivilegesRequired=lowest
CloseApplications=no
CloseApplicationsFilter=DesktopKit.FolderViewer.exe

; カスタムページで全て制御するため、標準ページを無効化
DisableWelcomePage=yes
DisableDirPage=yes
DisableReadyPage=yes
DisableFinishedPage=yes

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Files]
Source: "publish\DesktopKit.FolderViewer.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userprograms}\DesktopKit\FolderViewer"; Filename: "{app}\DesktopKit.FolderViewer.exe"
Name: "{userdesktop}\FolderViewer"; Filename: "{app}\DesktopKit.FolderViewer.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "デスクトップにショートカットを作成"; GroupDescription: "追加オプション:"

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\DesktopKit"
Type: filesandordirs; Name: "{app}"

[Code]
const
  OPTIMAL_RUNTIME_VERSION = '8.0.16';
  RUNTIME_REG_KEY = 'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App';
  UNINSTALL_REG_KEY = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\DesktopKit_FolderViewer_is1';
  COLOR_RED = $004040FF;
  COLOR_GREEN = $00008200;
  COLOR_ORANGE = $000080FF;
  COLOR_DESC = $00808080;
  COLOR_DESC_DISABLED = $00C0C0C0;

var
  CustomPage: TWizardPage;
  LblSectionTitle: TLabel;
  LblRuntimeStatus: TLabel;
  LblAppStatus: TLabel;
  RadioInstallBoth: TNewRadioButton;
  RadioInstallApp: TNewRadioButton;
  RadioUninstall: TNewRadioButton;
  LblDescBoth: TLabel;
  LblDescApp: TLabel;
  LblDescUninstall: TLabel;
  // 検出結果: 0=未インストール, 1=最適, 2=異なるバージョン
  DetectedRuntimeStatus: Integer;
  DetectedRuntimeVersion: String;
  // 検出結果: 0=未インストール, 1=インストール済み
  DetectedAppStatus: Integer;
  DetectedAppVersion: String;
  // 選択された操作: 'both', 'app', 'uninstall'
  SelectedAction: String;

// ========== プロセス検出 ==========

function IsProcessRunning(FileName: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  if Exec(ExpandConstant('{cmd}'), '/C tasklist /FI "IMAGENAME eq ' + FileName + '" /NH 2>nul | find /I "' + FileName + '" >nul',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Result := (ResultCode = 0);
end;

function WaitForProcessExit(FileName: String): Boolean;
var
  ResultCode: Integer;
  I: Integer;
begin
  Result := False;
  for I := 1 to 5 do
  begin
    Sleep(1000);
    if not IsProcessRunning(FileName) then
    begin
      Result := True;
      Exit;
    end;
    Exec('taskkill', '/IM ' + FileName, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
  MsgBox('FolderViewer を終了できませんでした。' + #13#10 +
    'タスクマネージャーから手動で終了してください。', mbError, MB_OK);
end;

// ========== 初期化 ==========

function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  Result := True;
  SelectedAction := '';

  if IsProcessRunning('DesktopKit.FolderViewer.exe') then
  begin
    if MsgBox('FolderViewer が実行中です。終了してセットアップを続けますか？',
      mbConfirmation, MB_OKCANCEL) = IDOK then
    begin
      Exec('taskkill', '/IM DesktopKit.FolderViewer.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      if not WaitForProcessExit('DesktopKit.FolderViewer.exe') then
      begin
        Result := False;
        Exit;
      end;
    end
    else
      Result := False;
  end;
end;

// ========== 環境検出 ==========

procedure DetectEnvironment();
var
  Names: TArrayOfString;
  I: Integer;
  Value: Cardinal;
begin
  // ===== .NET Desktop Runtime 検出 =====
  DetectedRuntimeStatus := 0;
  DetectedRuntimeVersion := '';

  if RegGetValueNames(HKLM, RUNTIME_REG_KEY, Names) then
  begin
    for I := 0 to GetArrayLength(Names) - 1 do
    begin
      if RegQueryDWordValue(HKLM, RUNTIME_REG_KEY, Names[I], Value) and (Value = 1) then
      begin
        if Names[I] = OPTIMAL_RUNTIME_VERSION then
        begin
          DetectedRuntimeStatus := 1;
          DetectedRuntimeVersion := Names[I];
          Break;
        end
        else
        begin
          DetectedRuntimeStatus := 2;
          if (DetectedRuntimeVersion = '') or (CompareStr(Names[I], DetectedRuntimeVersion) > 0) then
            DetectedRuntimeVersion := Names[I];
        end;
      end;
    end;
  end;

  // ===== FolderViewer 検出 =====
  DetectedAppStatus := 0;
  DetectedAppVersion := '';

  if RegQueryStringValue(HKCU, UNINSTALL_REG_KEY, 'DisplayVersion', DetectedAppVersion) then
  begin
    if DetectedAppVersion = '' then
      DetectedAppVersion := '(不明)';
    DetectedAppStatus := 1;
  end;
end;

// ========== 検出結果をUIに反映 ==========

procedure ApplyDetectionResults();
begin
  case DetectedRuntimeStatus of
    0:
      begin
        LblRuntimeStatus.Caption := '.NET Desktop Runtime：インストールされていません';
        LblRuntimeStatus.Font.Color := COLOR_RED;
      end;
    1:
      begin
        LblRuntimeStatus.Caption := '.NET Desktop Runtime v' + DetectedRuntimeVersion + '：インストール済み';
        LblRuntimeStatus.Font.Color := COLOR_GREEN;
      end;
    2:
      begin
        LblRuntimeStatus.Caption := '.NET Desktop Runtime v' + DetectedRuntimeVersion + '：インストール済み（推奨 v' + OPTIMAL_RUNTIME_VERSION + ' と異なります）';
        LblRuntimeStatus.Font.Color := COLOR_ORANGE;
      end;
  end;

  case DetectedAppStatus of
    0:
      begin
        LblAppStatus.Caption := 'FolderViewer：インストールされていません';
        LblAppStatus.Font.Color := COLOR_RED;
      end;
    1:
      begin
        LblAppStatus.Caption := 'FolderViewer v' + DetectedAppVersion + '：インストール済み';
        LblAppStatus.Font.Color := COLOR_GREEN;
      end;
  end;

  // 選択肢の有効/無効
  RadioInstallBoth.Enabled := (DetectedRuntimeStatus <> 1);
  if RadioInstallBoth.Enabled then
    LblDescBoth.Font.Color := COLOR_DESC
  else
    LblDescBoth.Font.Color := COLOR_DESC_DISABLED;

  RadioInstallApp.Enabled := True;
  LblDescApp.Font.Color := COLOR_DESC;

  RadioUninstall.Enabled := (DetectedAppStatus = 1);
  if RadioUninstall.Enabled then
    LblDescUninstall.Font.Color := COLOR_DESC
  else
    LblDescUninstall.Font.Color := COLOR_DESC_DISABLED;

  // デフォルト選択
  RadioInstallBoth.Checked := False;
  RadioInstallApp.Checked := False;
  RadioUninstall.Checked := False;

  if RadioInstallBoth.Enabled then
    RadioInstallBoth.Checked := True
  else if RadioInstallApp.Enabled then
    RadioInstallApp.Checked := True
  else if RadioUninstall.Enabled then
    RadioUninstall.Checked := True;
end;

// ========== ウィザードUI構築 ==========

procedure InitializeWizard();
var
  PageWidth: Integer;
  Y: Integer;
  Bevel: TBevel;
begin
  DetectEnvironment();

  CustomPage := CreateCustomPage(wpWelcome,
    'DesktopKit FolderViewer セットアップ',
    'お使いの環境を確認し、操作を選択してください。');

  PageWidth := CustomPage.SurfaceWidth;
  Y := 8;

  // ========== 状態表示エリア ==========

  LblSectionTitle := TLabel.Create(WizardForm);
  LblSectionTitle.Parent := CustomPage.Surface;
  LblSectionTitle.Caption := '環境チェック結果';
  LblSectionTitle.Font.Size := 10;
  LblSectionTitle.Font.Style := [fsBold];
  LblSectionTitle.Left := 0;
  LblSectionTitle.Top := Y;
  LblSectionTitle.Width := PageWidth;
  Y := Y + 28;

  LblRuntimeStatus := TLabel.Create(WizardForm);
  LblRuntimeStatus.Parent := CustomPage.Surface;
  LblRuntimeStatus.Font.Size := 9;
  LblRuntimeStatus.Left := 12;
  LblRuntimeStatus.Top := Y;
  LblRuntimeStatus.Width := PageWidth - 12;
  Y := Y + 22;

  LblAppStatus := TLabel.Create(WizardForm);
  LblAppStatus.Parent := CustomPage.Surface;
  LblAppStatus.Font.Size := 9;
  LblAppStatus.Left := 12;
  LblAppStatus.Top := Y;
  LblAppStatus.Width := PageWidth - 12;
  Y := Y + 30;

  Bevel := TBevel.Create(WizardForm);
  Bevel.Parent := CustomPage.Surface;
  Bevel.Shape := bsTopLine;
  Bevel.Left := 0;
  Bevel.Top := Y;
  Bevel.Width := PageWidth;
  Bevel.Height := 2;
  Y := Y + 12;

  // ========== 選択肢エリア ==========

  RadioInstallBoth := TNewRadioButton.Create(WizardForm);
  RadioInstallBoth.Parent := CustomPage.Surface;
  RadioInstallBoth.Caption := '標準インストール';
  RadioInstallBoth.Font.Size := 9;
  RadioInstallBoth.Font.Style := [fsBold];
  RadioInstallBoth.Left := 0;
  RadioInstallBoth.Top := Y;
  RadioInstallBoth.Width := PageWidth;
  RadioInstallBoth.Height := 20;
  Y := Y + 20;

  LblDescBoth := TLabel.Create(WizardForm);
  LblDescBoth.Parent := CustomPage.Surface;
  LblDescBoth.Caption := '.NET Desktop Runtime と FolderViewer をインストールします。';
  LblDescBoth.Font.Size := 8;
  LblDescBoth.Left := 20;
  LblDescBoth.Top := Y;
  LblDescBoth.Width := PageWidth - 20;
  Y := Y + 28;

  RadioInstallApp := TNewRadioButton.Create(WizardForm);
  RadioInstallApp.Parent := CustomPage.Surface;
  RadioInstallApp.Caption := 'FolderViewer のみインストール';
  RadioInstallApp.Font.Size := 9;
  RadioInstallApp.Font.Style := [fsBold];
  RadioInstallApp.Left := 0;
  RadioInstallApp.Top := Y;
  RadioInstallApp.Width := PageWidth;
  RadioInstallApp.Height := 20;
  Y := Y + 20;

  LblDescApp := TLabel.Create(WizardForm);
  LblDescApp.Parent := CustomPage.Surface;
  LblDescApp.Caption := 'FolderViewer 本体のみをインストール（上書き更新）します。ランタイムは別途必要です。';
  LblDescApp.Font.Size := 8;
  LblDescApp.Left := 20;
  LblDescApp.Top := Y;
  LblDescApp.Width := PageWidth - 20;
  Y := Y + 28;

  RadioUninstall := TNewRadioButton.Create(WizardForm);
  RadioUninstall.Parent := CustomPage.Surface;
  RadioUninstall.Caption := 'アンインストール';
  RadioUninstall.Font.Size := 9;
  RadioUninstall.Font.Style := [fsBold];
  RadioUninstall.Left := 0;
  RadioUninstall.Top := Y;
  RadioUninstall.Width := PageWidth;
  RadioUninstall.Height := 20;
  Y := Y + 20;

  LblDescUninstall := TLabel.Create(WizardForm);
  LblDescUninstall.Parent := CustomPage.Surface;
  LblDescUninstall.Caption := 'FolderViewer をアンインストールします。';
  LblDescUninstall.Font.Size := 8;
  LblDescUninstall.Left := 20;
  LblDescUninstall.Top := Y;
  LblDescUninstall.Width := PageWidth - 20;

  // ========== ウィザードボタンの調整 ==========
  WizardForm.NextButton.Caption := '実行';
  WizardForm.BackButton.Visible := False;

  ApplyDetectionResults();
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = CustomPage.ID then
  begin
    WizardForm.NextButton.Caption := '実行';
    WizardForm.BackButton.Visible := False;
  end;
end;

// ========== ランタイムインストーラー実行 ==========

function InstallRuntime(): Boolean;
var
  RuntimeInstaller: String;
  ResultCode: Integer;
begin
  Result := False;

  RuntimeInstaller := ExpandConstant('{src}\windowsdesktop-runtime-' + OPTIMAL_RUNTIME_VERSION + '-win-x64.exe');

  if not FileExists(RuntimeInstaller) then
  begin
    if MsgBox('.NET Desktop Runtime がこのPCにインストールされていません。' + #13#10 +
      'Microsoftのサイトからダウンロードしてインストールしますか？' + #13#10#13#10 +
      '「はい」を押すとブラウザが開きます。ダウンロードしたファイルを実行してインストールしてください。',
      mbConfirmation, MB_YESNO) = IDYES then
    begin
      ShellExec('open',
        'https://dotnet.microsoft.com/ja-jp/download/dotnet/8.0',
        '', '', SW_SHOWNORMAL, ewNoWait, ResultCode);
      MsgBox('.NET Desktop Runtime のインストールが完了したら「OK」を押してください。',
        mbInformation, MB_OK);
      DetectEnvironment();
      ApplyDetectionResults();
      Result := True;
    end;
    Exit;
  end;

  MsgBox('.NET Desktop Runtime のインストールを開始します。' + #13#10 +
    'ランタイムのインストーラーが起動しますので、指示に従ってインストールしてください。',
    mbInformation, MB_OK);

  if Exec(RuntimeInstaller, '', '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode) then
    Result := (ResultCode = 0)
  else
    MsgBox('ランタイムインストーラーの起動に失敗しました。', mbError, MB_OK);
end;

// ========== アンインストール処理 ==========

function RunUninstall(): Boolean;
var
  UninstallString: String;
  ResultCode: Integer;
begin
  Result := False;

  if not RegQueryStringValue(HKCU, UNINSTALL_REG_KEY, 'UninstallString', UninstallString) then
  begin
    MsgBox('アンインストール情報が見つかりません。' + #13#10 +
      '手動でアンインストールする場合は、以下のフォルダを削除してください：' + #13#10 +
      ExpandConstant('{localappdata}\Programs\DesktopKit\FolderViewer'),
      mbError, MB_OK);
    Exit;
  end;

  if MsgBox('FolderViewer をアンインストールします。よろしいですか？',
    mbConfirmation, MB_OKCANCEL) = IDCANCEL then
    Exit;

  if IsProcessRunning('DesktopKit.FolderViewer.exe') then
  begin
    Exec('taskkill', '/IM DesktopKit.FolderViewer.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    if not WaitForProcessExit('DesktopKit.FolderViewer.exe') then
    begin
      Result := False;
      Exit;
    end;
  end;

  if Exec(RemoveQuotes(UninstallString), '/SILENT', '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := True;
    MsgBox('アンインストールが完了しました。', mbInformation, MB_OK);
  end
  else
    MsgBox('アンインストールに失敗しました。', mbError, MB_OK);
end;

// ========== 「実行」ボタン押下時の処理 ==========

function NextButtonClick(CurPageID: Integer): Boolean;
var
  RuntimeResult: Boolean;
begin
  Result := True;

  if CurPageID = CustomPage.ID then
  begin
    if RadioInstallBoth.Checked then
    begin
      SelectedAction := 'both';
      RuntimeResult := InstallRuntime();
      if not RuntimeResult then
      begin
        if MsgBox('ランタイムのインストールが完了しませんでした。' + #13#10 +
          'FolderViewer のインストールを続けますか？',
          mbConfirmation, MB_YESNO) = IDNO then
        begin
          Result := False;
          Exit;
        end;
      end;
      Result := True;
    end
    else if RadioInstallApp.Checked then
    begin
      SelectedAction := 'app';
      Result := True;
    end
    else if RadioUninstall.Checked then
    begin
      SelectedAction := 'uninstall';
      if RunUninstall() then
      begin
        WizardForm.Tag := 1;
        WizardForm.Close;
      end;
      Result := False;
    end;
  end;
end;

// ========== インストール完了後にアプリを起動 ==========

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    if (SelectedAction = 'both') or (SelectedAction = 'app') then
    begin
      MsgBox('FolderViewer のインストールが完了しました。' + #13#10 +
        'FolderViewer を起動します。', mbInformation, MB_OK);
      Exec(ExpandConstant('{app}\DesktopKit.FolderViewer.exe'), '', '', SW_SHOWNORMAL, ewNoWait, ResultCode);
    end;
  end;
end;

// ========== アンインストール完了後の終了確認抑制 ==========

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  if WizardForm.Tag = 1 then
    Confirm := False;
end;

// ========== アンインストール時のプロセス終了 ==========

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    if IsProcessRunning('DesktopKit.FolderViewer.exe') then
    begin
      Exec('taskkill', '/IM DesktopKit.FolderViewer.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      WaitForProcessExit('DesktopKit.FolderViewer.exe');
    end;
  end;
end;
