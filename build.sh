#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}  TK Engine - Skrypt budujący${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

detect_os() {
    OS="$(uname -s)"
    case "${OS}" in
        Linux*)     HOST_OS="linux";;
        Darwin*)    HOST_OS="mac";;
        *)          HOST_OS="unknown";;
    esac
    echo "${HOST_OS}"
}

detect_distro() {
    if command -v dnf &> /dev/null; then
        echo "fedora"
    elif command -v apt-get &> /dev/null; then
        echo "debian"
    elif command -v pacman &> /dev/null; then
        echo "arch"
    else
        echo "unknown"
    fi
}

install_deps_linux() {
    echo -e "${YELLOW}Instalowanie zależności systemowych...${NC}"
    if command -v dnf &> /dev/null; then
        sudo dnf install -y gcc gcc-c++ cmake make pkg-config libsrtp2-devel
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y build-essential cmake pkg-config libsrtp2-dev
    elif command -v pacman &> /dev/null; then
        sudo pacman -Sy --noconfirm gcc cmake make pkg-config libsrtp
    else
        echo -e "${RED}Nieznany menedżer pakietów.${NC}"
        exit 1
    fi
}

install_deps_mac() {
    echo -e "${YELLOW}Instalowanie zależności systemowych...${NC}"
    if ! command -v xcode-select &> /dev/null; then
        xcode-select --install || true
        sleep 5
    fi
    if command -v brew &> /dev/null; then
        brew install cmake pkg-config libsrtp
    else
        echo -e "${RED}Zainstaluj Homebrew: https://brew.sh${NC}"
        exit 1
    fi
}

install_mingw_linux() {
    echo -e "${YELLOW}Instalowanie toolchaina MinGW...${NC}"
    if command -v dnf &> /dev/null; then
        sudo dnf install -y mingw64-gcc mingw64-gcc-c++ mingw64-cmake mingw64-pkg-config mingw64-winpthreads-static
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y gcc-mingw-w64 g++-mingw-w64 cmake mingw-w64-tools
    else
        echo -e "${RED}Nieznany menedżer pakietów.${NC}"
        exit 1
    fi
}

get_mingw_cmake() {
    local DISTRO="$1"
    if [[ "${DISTRO}" == "fedora" ]]; then
        echo "mingw64-cmake"
    elif [[ "${DISTRO}" == "debian" ]]; then
        echo "x86_64-w64-mingw32-cmake"
    elif [[ "${DISTRO}" == "arch" ]]; then
        echo "x86_64-w64-mingw32-cmake"
    else
        if command -v mingw64-cmake &> /dev/null; then
            echo "mingw64-cmake"
        elif command -v x86_64-w64-mingw32-cmake &> /dev/null; then
            echo "x86_64-w64-mingw32-cmake"
        else
            echo "mingw64-cmake"
        fi
    fi
}

build_deps_from_source() {
    local TARGET="$1"
    local DISTRO="$2"
    local INSTALL_PREFIX
    local CMAKE_CMD
    local CMAKE_EXTRA=""

    # ZAPISZ ORYGINALNY KATALOG
    local ORIG_PWD="$(pwd)"

    if [[ "${TARGET}" == "windows" ]]; then
        INSTALL_PREFIX="/usr/x86_64-w64-mingw32/sys-root/mingw"
        CMAKE_CMD=$(get_mingw_cmake "${DISTRO}")
        CMAKE_EXTRA="-DCMAKE_SYSTEM_NAME=Windows"
    elif [[ "${TARGET}" == "mac" ]]; then
        INSTALL_PREFIX="/usr/local"
        CMAKE_CMD="cmake"
        if [[ "$(uname -m)" == "arm64" ]]; then
            CMAKE_EXTRA="-DCMAKE_OSX_ARCHITECTURES=arm64"
        fi
    else
        INSTALL_PREFIX="/usr/local"
        CMAKE_CMD="cmake"
    fi

    echo -e "${YELLOW}Budowanie libre i baresip ze źródeł (target: ${TARGET})...${NC}"
    
    local TMPDIR=$(mktemp -d)
    cd "${TMPDIR}"

       # Libsrtp2
    echo -e "${CYAN}  -> libsrtp2${NC}"
    git clone --depth 1 --branch v2.5.0 https://github.com/cisco/libsrtp.git
    cd libsrtp
    # KLUCZOWE: usuń -Werror z CMakeLists.txt (GCC 16 jest zbyt surowy)
    sed -i 's/-Werror//g' CMakeLists.txt
    mkdir -p build && cd build
    ${CMAKE_CMD} .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        ${CMAKE_EXTRA} \
        -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}" \
        -DCMAKE_C_FLAGS="-Wno-error=format"
        make -j$(nproc) srtp2
    # Zainstaluj tylko bibliotekę (bez testów)
    sudo install -m 755 libsrtp2.dll "${INSTALL_PREFIX}/bin/"
    sudo install -m 644 libsrtp2.dll.a "${INSTALL_PREFIX}/lib/"
    sudo install -m 644 libsrtp2.a "${INSTALL_PREFIX}/lib/" 2>/dev/null || true
    sudo cp -r ../include/* "${INSTALL_PREFIX}/include/"

    # Stwórz plik .pc jeśli nie istnieje
    sudo mkdir -p "${INSTALL_PREFIX}/lib/pkgconfig"
    if [[ ! -f "${INSTALL_PREFIX}/lib/pkgconfig/libsrtp2.pc" ]]; then
        sudo tee "${INSTALL_PREFIX}/lib/pkgconfig/libsrtp2.pc" << PC_EOF
prefix=${INSTALL_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libsrtp2
Description: Secure RTP (SRTP) library
Version: 2.5.0
Libs: -L\${libdir} -lsrtp2
Cflags: -I\${includedir}
PC_EOF
    fi

    cd "${TMPDIR}" && rm -rf libsrtp

    # Libre
    echo -e "${CYAN}  -> libre${NC}"
    git clone --depth 1 https://github.com/baresip/re.git
    cd re
    mkdir -p build && cd build
    ${CMAKE_CMD} .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        ${CMAKE_EXTRA} \
        -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}"
    make -j$(nproc)
    sudo make install

    # Baresip
    echo -e "${CYAN}  -> baresip${NC}"
    cd "${TMPDIR}"
    git clone --depth 1 https://github.com/baresip/baresip.git
    cd baresip
    mkdir -p build && cd build
        ${CMAKE_CMD} .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        ${CMAKE_EXTRA} \
        -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}" \
        -DENABLE_MODULE_opus=OFF \
        -DENABLE_MODULE_opus_multistream=OFF \
        -DENABLE_MODULE_snapshot=OFF \
        -DENABLE_MODULE_dshow=OFF
    make -j$(nproc)
    sudo make install

    # KLUCZOWA NAPRAWA: wróć DO USUNIĘCIA TMPDIR
    cd /
    rm -rf "${TMPDIR}"
    cd "${ORIG_PWD}"

    if [[ "$(detect_os)" == "linux" ]]; then
        sudo ldconfig
    fi
}

build_tkengine() {
    local TARGET="$1"
    local DISTRO="$2"
    local BUILD_DIR
    local CMAKE_CMD
    local CMAKE_EXTRA=""

            if [[ "${TARGET}" == "windows" ]]; then
        BUILD_DIR="build-windows"
        CMAKE_CMD=$(get_mingw_cmake "${DISTRO}")
        CMAKE_EXTRA="-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_PREFIX_PATH=/usr/x86_64-w64-mingw32/sys-root/mingw"
        export LDFLAGS="-lopus -lpng16 -lssl -lcrypto -lstrmiids -luuid -lwinmm -lws2_32 -liphlpapi -ladvapi32"
    elif [[ "${TARGET}" == "mac" ]]; then
        BUILD_DIR="build-macos"
        CMAKE_CMD="cmake"
        if [[ "$(uname -m)" == "arm64" ]]; then
            CMAKE_EXTRA="-DCMAKE_OSX_ARCHITECTURES=arm64"
        fi
    else
        BUILD_DIR="build-linux"
        CMAKE_CMD="cmake"
        CMAKE_EXTRA="-DCMAKE_BUILD_TYPE=Release"
    fi

    echo -e "${YELLOW}Budowanie TK Engine (target: ${TARGET})...${NC}"
    cd "$(dirname "$0")"
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}" && cd "${BUILD_DIR}"

    ${CMAKE_CMD} .. ${CMAKE_EXTRA} -DCMAKE_SHARED_LINKER_FLAGS="-lopus -lpng16 -lssl -lcrypto -lstrmiids -luuid -lwinmm -lws2_32 -liphlpapi -ladvapi32"
    make -j$(nproc)

    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}  SUKCES!${NC}"
    echo -e "${GREEN}==========================================${NC}"
    
    if [[ "${TARGET}" == "windows" ]]; then
        echo -e "Plik: ${CYAN}$(pwd)/libTKEngine.dll${NC}"
    elif [[ "${TARGET}" == "mac" ]]; then
        echo -e "Plik: ${CYAN}$(pwd)/libTKEngine.dylib${NC}"
    else
        echo -e "Plik: ${CYAN}$(pwd)/libTKEngine.so${NC}"
    fi
}

HOST_OS=$(detect_os)
DISTRO=$(detect_distro)
TARGET="${1:-}"

if [[ -n "${TARGET}" ]]; then
    case "${TARGET}" in
        linux|native)
            [[ "${HOST_OS}" != "linux" ]] && { echo -e "${RED}Wymaga Linuxa.${NC}"; exit 1; }
            install_deps_linux
            build_deps_from_source "native" "${DISTRO}"
            build_tkengine "native" "${DISTRO}"
            ;;
        windows)
            [[ "${HOST_OS}" != "linux" ]] && { echo -e "${RED}Wymaga Linuxa.${NC}"; exit 1; }
            install_mingw_linux
            build_deps_from_source "windows" "${DISTRO}"
            build_tkengine "windows" "${DISTRO}"
            ;;
        mac|macos)
            [[ "${HOST_OS}" != "mac" ]] && { echo -e "${RED}Wymaga macOS.${NC}"; exit 1; }
            install_deps_mac
            build_deps_from_source "mac" "${DISTRO}"
            build_tkengine "mac" "${DISTRO}"
            ;;
        *)
            echo -e "${RED}Nieznany target: ${TARGET}${NC}"
            exit 1
            ;;
    esac
    exit 0
fi

echo "Wybierz platformę docelową:"
echo ""
echo "  1) Zbuduj na Linux   (wymaga Linuxa)"
echo "  2) Zbuduj na Windows (cross-compile, wymaga Linuxa)"
echo "  3) Zbuduj na macOS   (wymaga macOS)"
echo "  0) Wyjdź"
echo ""
read -p "Twój wybór: " choice

case "${choice}" in
    1)
        [[ "${HOST_OS}" != "linux" ]] && { echo -e "${RED}Wymaga Linuxa.${NC}"; exit 1; }
        install_deps_linux
        build_deps_from_source "native" "${DISTRO}"
        build_tkengine "native" "${DISTRO}"
        ;;
    2)
        [[ "${HOST_OS}" != "linux" ]] && { echo -e "${RED}Wymaga Linuxa.${NC}"; exit 1; }
        install_mingw_linux
        build_deps_from_source "windows" "${DISTRO}"
        build_tkengine "windows" "${DISTRO}"
        ;;
    3)
        [[ "${HOST_OS}" != "mac" ]] && { echo -e "${RED}Wymaga macOS.${NC}"; exit 1; }
        install_deps_mac
        build_deps_from_source "mac" "${DISTRO}"
        build_tkengine "mac" "${DISTRO}"
        ;;
    0)
        echo "Wyjście."
        exit 0
        ;;
    *)
        echo -e "${RED}Nieprawidłowy wybór.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Gotowe!${NC}"
