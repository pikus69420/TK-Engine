# build.ps1 - 1:1 odpowiednik build.sh, tylko Windows natywny (MSYS2 MINGW64)
param(
    [ValidateSet("windows")]
    [string]$Target = "windows",
    [string]$MsysRoot = "C:\msys64"
)

$ErrorActionPreference = "Stop"

# Kolory (odpowiednik RED/GREEN/YELLOW/CYAN/NC z build.sh)
$RED='`e[31m'; $GREEN='`e[32m'; $YELLOW='`e[33m'; $CYAN='`e[36m'; $NC='`e[0m'
Write-Host "$CYAN==========================================$NC"
Write-Host "$CYAN  TK Engine - Skrypt budujący (Windows)$NC"
Write-Host "$CYAN==========================================$NC"
Write-Host ""

$Nproc = $env:NUMBER_OF_PROCESSORS
$MingwPrefix = Join-Path $MsysRoot "mingw64"
$BashExe = Join-Path $MsysRoot "usr\bin\bash.exe"

# === 1:1 z build.sh: install_mingw_linux() ===
function Install-Toolchain {
    Write-Host "$YELLOW Instalowanie toolchaina MSYS2...$NC"
    if (-not (Test-Path $BashExe)) {
        Write-Host "$RED MSYS2 nie znaleziony w $MsysRoot.$NC"
        Write-Host "$RED Pobierz i zainstaluj: https://www.msys2.org$NC"
        exit 1
    }
    # pacman wymaga środowiska bash -> wywołujemy przez bash.exe (to jedyny moment)
    & $BashExe -lc "pacman -Sy --noconfirm --needed " +
        "mingw-w64-x86_64-cmake mingw-w64-x86_64-gcc mingw-w64-x86_64-make " +
        "mingw-w64-x86_64-pkgconf mingw-w64-x86_64-openssl " +
        "mingw-w64-x86_64-opus mingw-w64-x86_64-libpng"
    if ($LASTEXITCODE -ne 0) { Write-Host "$RED pacman nieudany$NC"; exit 1 }
}

# === 1:1 z build.sh: build_deps_from_source() (gałąź windows) ===
function Build-DepsFromSource {
    Write-Host "$YELLOW Budowanie libre i baresip ze zrodel (target: windows)...$NC"
    $TmpDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("tkdeps_" + [guid]::NewGuid().ToString("N").Substring(0,8)))
    Push-Location $TmpDir

    # --- Libsrtp2 (v2.5.0, sed -Werror, make srtp2, reczny install, plik .pc) ---
    Write-Host "$CYAN  -> libsrtp2$NC"
    git clone --depth 1 --branch v2.5.0 https://github.com/cisco/libsrtp.git
    Push-Location libsrtp
    # KLUCZOWE: usuń -Werror (odpowiednik sed -i 's/-Werror//g' CMakeLists.txt)
    (Get-Content CMakeLists.txt) -replace '-Werror','' | Set-Content CMakeLists.txt
    New-Item -ItemType Directory -Path build | Out-Null; Push-Location build
    & "$MingwPrefix\bin\cmake.exe" .. -G "MinGW Makefiles" `
        "-DCMAKE_INSTALL_PREFIX=$MingwPrefix" `
        "-DCMAKE_PREFIX_PATH=$MingwPrefix" `
        "-DCMAKE_C_FLAGS=-Wno-error=format"
    & "$MingwPrefix\bin\mingw32-make.exe" -j$Nproc srtp2
    # Zainstaluj tylko biblioteke (bez testow) - odpowiednik sudo install / cp
    New-Item -ItemType Directory -Force -Path "$MingwPrefix\bin","$MingwPrefix\lib","$MingwPrefix\include","$MingwPrefix\lib\pkgconfig" | Out-Null
    Copy-Item libsrtp2.dll "$MingwPrefix\bin\" -Force
    Copy-Item libsrtp2.dll.a "$MingwPrefix\lib\" -Force
    if (Test-Path libsrtp2.a) { Copy-Item libsrtp2.a "$MingwPrefix\lib\" -Force }
    Copy-Item -Recurse -Force ..\include\* "$MingwPrefix\include\"
    # Stworz plik .pc jesli nie istnieje (odpowiednik sudo tee << PC_EOF)
    $pcPath = "$MingwPrefix\lib\pkgconfig\libsrtp2.pc"
    if (-not (Test-Path $pcPath)) {
        $pc = @"
prefix=$MingwPrefix
exec_prefix=`${prefix}
libdir=`${exec_prefix}/lib
includedir=`${prefix}/include

Name: libsrtp2
Description: Secure RTP (SRTP) library
Version: 2.5.0
Libs: -L`${libdir} -lsrtp2
Cflags: -I`${includedir}
"@
        Set-Content -Path $pcPath -Value $pc -Encoding ASCII
    }
    Pop-Location; Pop-Location; Remove-Item -Recurse -Force libsrtp

    # --- Libre ---
    Write-Host "$CYAN  -> libre$NC"
    git clone --depth 1 https://github.com/baresip/re.git
    Push-Location re; New-Item -ItemType Directory -Path build | Out-Null; Push-Location build
    & "$MingwPrefix\bin\cmake.exe" .. -G "MinGW Makefiles" `
        "-DCMAKE_INSTALL_PREFIX=$MingwPrefix" "-DCMAKE_PREFIX_PATH=$MingwPrefix"
    & "$MingwPrefix\bin\mingw32-make.exe" -j$Nproc
    & "$MingwPrefix\bin\mingw32-make.exe" install
    Pop-Location; Pop-Location; Remove-Item -Recurse -Force re

    # --- Baresip (wylaczone moduly jak w build.sh) ---
    Write-Host "$CYAN  -> baresip$NC"
    git clone --depth 1 https://github.com/baresip/baresip.git
    Push-Location baresip; New-Item -ItemType Directory -Path build | Out-Null; Push-Location build
    & "$MingwPrefix\bin\cmake.exe" .. -G "MinGW Makefiles" `
        "-DCMAKE_INSTALL_PREFIX=$MingwPrefix" "-DCMAKE_PREFIX_PATH=$MingwPrefix" `
        "-DENABLE_MODULE_opus=OFF" "-DENABLE_MODULE_opus_multistream=OFF" `
        "-DENABLE_MODULE_snapshot=OFF" "-DENABLE_MODULE_dshow=OFF"
    & "$MingwPrefix\bin\mingw32-make.exe" -j$Nproc
    & "$MingwPrefix\bin\mingw32-make.exe" install
    Pop-Location; Pop-Location; Remove-Item -Recurse -Force baresip

    Pop-Location; Remove-Item -Recurse -Force $TmpDir
}

# === 1:1 z build.sh: build_tkengine() (gałąź windows) ===
function Build-TKEngine {
    Write-Host "$YELLOW Budowanie TK Engine (target: windows)...$NC"
    $ProjectRoot = $PSScriptRoot
    $BuildDir = Join-Path $ProjectRoot "build-windows"
    if (Test-Path $BuildDir) { Remove-Item -Recurse -Force $BuildDir }
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
    Push-Location $BuildDir
    # Nadpisz sciezke sysroot dla CMakeLists.txt (native Windows)
    $env:TKENGINE_SYSROOT = $MingwPrefix
    & "$MingwPrefix\bin\cmake.exe" .. -G "MinGW Makefiles" `
        "-DCMAKE_PREFIX_PATH=$MingwPrefix" `
        "-DCMAKE_SHARED_LINKER_FLAGS=-lopus -lpng16 -lssl -lcrypto -lstrmiids -luuid -lwinmm -lws2_32 -liphlpapi -ladvapi32"
    & "$MingwPrefix\bin\mingw32-make.exe" -j$Nproc
    Pop-Location
    Write-Host ""
    Write-Host "$GREEN==========================================$NC"
    Write-Host "$GREEN  SUKCES!$NC"
    Write-Host "$GREEN==========================================$NC"
    Write-Host "Plik: $CYAN$BuildDir\libTKEngine.dll$NC"
}

# === Główna logika (odpowiednik menu/CLI z build.sh, tylko windows) ===
Install-Toolchain
Build-DepsFromSource
Build-TKEngine
Write-Host ""
Write-Host "$GREEN Gotowe!$NC"