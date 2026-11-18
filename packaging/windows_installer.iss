; CCSAAS Windows Installer - single setup exe
; Compile: "C:\Users\chenk\AppData\Local\Programs\Inno Setup 6\ISCC.exe" packaging\windows_installer.iss

#define MyAppName "CCSAAS"
#define MyAppVersion "3.0.0"
#define MyAppPublisher "CCSA - Dibrugarh University"
#define MyAppExeName "ccsa_smart_attendance.exe"
#define AppRoot "C:\Users\chenk\ccsa_attendance_app"

[Setup]
AppId={{8E4B2C1A-77D3-4F5E-9A60-CCSAASDU2025}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\CCSAAS
DefaultGroupName={#MyAppName}
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir={#AppRoot}\build\distro
OutputBaseFilename=CCSAAS-Setup-v{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
SetupIconFile={#AppRoot}\windows\runner\resources\app_icon.ico
Uninstallable=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#AppRoot}\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
