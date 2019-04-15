; Accelerad installer

; Required packages:
; nsis-3.04-strlen_8192
; EnVar_plugin https://nsis.sourceforge.io/EnVar_plug-in
; AccessControl https://nsis.sourceforge.io/AccessControl_plug-in
; ShellExecAsUser https://nsis.sourceforge.io/ShellExecAsUser_plug-in

!include "${NSISDir}\Contrib\Modern UI\System.nsh" ; for license
;!include WinMessages.nsh ; for Environment Variable update
!include logiclib.nsh ; for AcceleradRT optional files
!include sections.nsh ; for AcceleradRT optional files

!addplugindir /x86-ansi "${NSISDir}\EnVar_plugin\Plugins\x86-ansi" ; for Environmetn Variables
!addplugindir /x86-unicode "${NSISDir}\EnVar_plugin\Plugins\x86-unicode"

!addplugindir /x86-ansi "${NSISDir}\AccessControl\Plugins" ; for AccessControl
!addplugindir /x86-unicode "${NSISDir}\AccessControl\Unicode\Plugins"

!addplugindir /x86-ansi "${NSISDir}\ShellExecAsUserUnicodeUpdate\ansi" ; for ShellExecAsUser
!addplugindir /x86-unicode "${NSISDir}\ShellExecAsUserUnicodeUpdate\unicode"

;ShowInstDetails Show

Unicode True

;--------------------------------

!define ProductName "Accelerad"
!define SourceDir "D:\Accelerad"
!define BuildDir "D:\Accelerad10"

!searchparse /file "${SourceDir}\src\rt\VERSION" `` VER_MAJOR `.` VER_MINOR ` ` VER_STATUS

; The name of the installer
Name "${ProductName} ${VER_MAJOR}.${VER_MINOR} ${VER_STATUS}"

; The file to write
OutFile "${ProductName}_${VER_MAJOR}${VER_MINOR}_${VER_STATUS}_win64.exe"

; The default installation directory
InstallDir $PROGRAMFILES64\${ProductName}

; Registry key to check for directory (so if you install again, it will 
; overwrite the old one automatically)
InstallDirRegKey HKLM "Software\${ProductName}" "Install_Dir"

; Request application privileges for Windows Vista
RequestExecutionLevel admin

;--------------------------------
; Pages

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "license\Accelerad_EULA.rtf"
!insertmacro MUI_PAGE_LICENSE "license\AcceleradRT_EULA.rtf"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN  ; we have to keep this in order to show the checkbox and the "launch app now"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchWebsite ; now this function runs in the context of the running user... even if elevated for the install
!define MUI_FINISHPAGE_RUN_TEXT "Visit documentation (Recommended)"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Function LaunchWebsite ; Launching your app as the current user:
  ShellExecAsUser::ShellExecAsUser "open" 'https://nljones.github.io/Accelerad/welcome.html'
FunctionEnd

;--------------------------------
;Version Information

;LoadLanguageFile "${NSISDIR}\Contrib\Language files\English.nlf"

  VIProductVersion "${VER_MAJOR}.${VER_MINOR}.0.0"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "${ProductName}"
  ;VIAddVersionKey /LANG=${LANG_ENGLISH} "Comments" "A test comment"
  ;VIAddVersionKey /LANG=${LANG_ENGLISH} "CompanyName" "Fake company"
  ;VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalTrademarks" "Test Application is a trademark of Fake company"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright" "Copyright (c) 2019 Nathaniel Jones"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "${ProductName} ${VER_MAJOR}.${VER_MINOR} ${VER_STATUS}"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "${VER_MAJOR}.${VER_MINOR}.0.0"

;--------------------------------

; Install the Accelerad programs
Section "${ProductName} (required)"

  SectionIn RO
  
  ; Populate the main directory.
  SetOutPath $INSTDIR
  File "license\Accelerad_EULA.rtf"
  File "README.pdf"
  
  ; Populate the bin directory.
  SetOutPath $INSTDIR\bin
  File /oname=accelerad_genBSDF.pl "${SourceDir}\src\util\genBSDF.pl"
  File /oname=accelerad_rcontrib.exe "${BuildDir}\bin\Release\rcontrib.exe"
  File /oname=accelerad_rfluxmtx.exe "${BuildDir}\bin\Release\rfluxmtx.exe"
  File /oname=accelerad_rpict.exe "${BuildDir}\bin\Release\rpict.exe"
  File /oname=accelerad_rtrace.exe "${BuildDir}\bin\Release\rtrace.exe"
  File "${BuildDir}\bin\Release\cudart64_*.dll"
  File "${BuildDir}\bin\Release\optix.*.dll"
  
  ; Populate the lib directory.
  SetOutPath $INSTDIR\lib
  File /r /x "fisheye.ptx" /x "rvu.ptx" /x "material_diffuse.ptx" "${BuildDir}\lib\*.ptx"
  File "${BuildDir}\lib\rayinit.cal" ; required in case Radiance is not installed
  
  ; Write the installation path into the registry
  WriteRegStr HKLM SOFTWARE\${ProductName} "Install_Dir" "$INSTDIR"
  
  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ProductName}" "DisplayName" "${ProductName}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ProductName}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ProductName}" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ProductName}" "NoRepair" 1
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
  ;--------------------------------
  ; Set environment variables
  
  ; Set to HKLM
  EnVar::SetHKLM

  ; Check for write access to system environment variables
  EnVar::Check "NULL" "NULL"
  Pop $0
  DetailPrint "EnVar::Check write access HKLM returned=|$0|"
  IntCmp $0 0 doHKLM subHKCU subHKCU
  
  subHKCU:
    ; Set to HKCU because HKLM is not editable
    EnVar::SetHKCU

  doHKLM:
    ; Set system 'path' and 'raypath' variable
    EnVar::AddValue "PATH" "$INSTDIR\bin"
    EnVar::AddValue "RAYPATH" "$INSTDIR\lib"
    ;SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
  
  ; Set to HKCU in case a user 'raypath' overshadows the system 'raypath'
  EnVar::SetHKCU
  
  ; Check for current user 'raypath' variable
  EnVar::Check "RAYPATH" "NULL"
  Pop $0
  DetailPrint "EnVar::Check RAYPATH in HKCU returned=|$0|"
  IntCmp $0 0 setHKCU doneHKCU doneHKCU

  setHKCU:
    ; Set current user 'raypath' variable
    EnVar::AddValue "RAYPATH" "$INSTDIR\lib"
    ;SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
  
  doneHKCU:
  
SectionEnd

; Install AcceleradRT
Section "AcceleradRT" ART
 
  ; Populate the main directory.
  SetOutPath $INSTDIR
  File "license\AcceleradRT_EULA.rtf"
  
  ; Populate the bin directory.
  SetOutPath $INSTDIR\bin
  File /oname=AcceleradRT.exe "${BuildDir}\bin\Release\qwtrvu.exe"
  File "${BuildDir}\bin\Release\qt.conf" ; for AcceleradRT
  File /r /x "cudart64_*.dll" /x "optix.*.dll" "${BuildDir}\bin\Release\*.dll"
  
  ; Populate the Qt plugins directory.
  SetOutPath $INSTDIR\bin\plugins
  File /r "${BuildDir}\bin\Release\plugins\*" ; for AcceleradRT
  
  ; Populate the lib directory.
  SetOutPath $INSTDIR\lib
  File "${BuildDir}\lib\rvu.ptx"
  File "${BuildDir}\lib\material_diffuse.ptx"
  
SectionEnd

; Install the demo files
Section "Demo Files"
 
  ; Set output path to the installation directory.
  SetOutPath $INSTDIR\demo
  
  ; Put file there
  File /r /x "*.sh" "demo\*.*"
  
  ; Allow full access to this directory for the demos to run
  AccessControl::GrantOnFile "$INSTDIR\demo" "(S-1-5-32-545)" "FullAccess"
  
SectionEnd

; Optional section (can be disabled by the user)
Section "Start Menu Shortcuts"

  CreateDirectory "$SMPROGRAMS\${ProductName}"
  CreateShortcut "$SMPROGRAMS\${ProductName}\Uninstall ${ProductName}.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
  ${If} ${SectionIsSelected} ${ART}
  CreateShortcut "$SMPROGRAMS\${ProductName}\AcceleradRT.lnk" "$INSTDIR\bin\AcceleradRT.exe" "" "$INSTDIR\bin\AcceleradRT.exe" 0
  ${EndIf}
  
SectionEnd

;--------------------------------

; Uninstaller

Section "Uninstall"
  
  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ProductName}"
  DeleteRegKey HKLM SOFTWARE\${ProductName}

  ; Remove files and uninstaller
  Delete $INSTDIR\bin\plugins\imageformats\*
  Delete $INSTDIR\bin\plugins\platforms\*
  Delete $INSTDIR\bin\*
  Delete $INSTDIR\lib\*
  Delete $INSTDIR\demo\*
  Delete $INSTDIR\uninstall.exe

  ; Remove shortcuts, if any
  Delete "$SMPROGRAMS\${ProductName}\*.*"

  ; Remove directories used
  RMDir "$SMPROGRAMS\${ProductName}"
  RMDir /r "$INSTDIR"

  ; Remove environment variables
  EnVar::SetHKLM
  EnVar::DeleteValue "PATH" "$INSTDIR\bin"
  EnVar::DeleteValue "RAYPATH" "$INSTDIR\lib"
    
  EnVar::SetHKCU
  EnVar::DeleteValue "PATH" "$INSTDIR\bin"
  EnVar::DeleteValue "RAYPATH" "$INSTDIR\lib"
  ;SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
  
SectionEnd
