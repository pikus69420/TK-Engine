cmake_minimum_required(VERSION 3.16)
project(TKEngine VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(PkgConfig REQUIRED)

# Znajdź libsrtp2 przez pkg-config
pkg_check_modules(SRTP REQUIRED libsrtp2)

# Ścieżki dla Windows (mingw sysroot) i Linux
if(WIN32)
    if(DEFINED ENV{TKENGINE_SYSROOT})
        set(SYSROOT "$ENV{TKENGINE_SYSROOT}")
    else()
        set(SYSROOT "/usr/x86_64-w64-mingw32/sys-root/mingw")
    endif()
    set(LIB_EXT ".a")
else()
    set(SYSROOT "")
    set(LIB_EXT ".so")
endif()

# Znajdź nagłówki
find_path(RE_INCLUDE_DIR NAMES re/re.h
    PATHS ${SYSROOT}/include /usr/include /usr/local/include)
find_path(BARESIP_INCLUDE_DIR NAMES baresip.h
    PATHS ${SYSROOT}/include /usr/include /usr/local/include)

if(NOT RE_INCLUDE_DIR)
    message(FATAL_ERROR "Nie znaleziono re/re.h")
endif()
if(NOT BARESIP_INCLUDE_DIR)
    message(FATAL_ERROR "Nie znaleziono baresip.h")
endif()

# Znajdź biblioteki
find_library(RE_LIBRARY NAMES re
    PATHS ${SYSROOT}/lib /usr/lib64 /usr/lib /usr/local/lib64 /usr/local/lib)
find_library(BARESIP_LIBRARY NAMES baresip
    PATHS ${SYSROOT}/lib /usr/lib64 /usr/lib /usr/local/lib64 /usr/local/lib)

if(NOT RE_LIBRARY)
    message(FATAL_ERROR "Nie znaleziono biblioteki libre")
endif()
if(NOT BARESIP_LIBRARY)
    message(FATAL_ERROR "Nie znaleziono biblioteki libbaresip")
endif()

add_library(TKEngine SHARED
    src/TKEngine.cpp
    src/SIPManager.cpp
    src/Recorder.cpp
    src/Config.cpp
)

if(WIN32)
    set_target_properties(TKEngine PROPERTIES
        PREFIX ""
        OUTPUT_NAME "TK-Engine"
    )
endif()

target_include_directories(TKEngine
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${RE_INCLUDE_DIR}
        ${BARESIP_INCLUDE_DIR}
        ${SRTP_INCLUDE_DIRS}
)

# Biblioteki wspólne
set(COMMON_LIBS
    ${BARESIP_LIBRARY}
    ${RE_LIBRARY}
    ${SRTP_LIBRARIES}
)

# Zależności baresip (opus, png, openssl)
if(WIN32)
    set(DEPS_LIBS
        opus png16 ssl crypto
        strmiids uuid winmm ws2_32 iphlpapi advapi32
    )
else()
    set(DEPS_LIBS
        opus png ssl crypto
        pthread
    )
endif()

target_link_libraries(TKEngine PRIVATE
    ${COMMON_LIBS}
    ${DEPS_LIBS}
)

target_compile_definitions(TKEngine PRIVATE TKENGINE_EXPORTS)

install(TARGETS TKEngine
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
    ARCHIVE DESTINATION lib
)
install(DIRECTORY include/tkengine DESTINATION include)
