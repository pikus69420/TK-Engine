cmake_minimum_required(VERSION 3.16)
project(TKEngine VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(PkgConfig REQUIRED)

# 1. Znajdź libsrtp2 przez pkg-config (to działa w Fedorze)
pkg_check_modules(SRTP REQUIRED libsrtp2)

# 2. Ręcznie znajdź nagłówki (omijamy brakujące pliki .pc w Fedorze)
find_path(RE_INCLUDE_DIR NAMES re/re.h PATHS /usr/include /usr/local/include)
find_path(BARESIP_INCLUDE_DIR NAMES baresip.h PATHS /usr/include /usr/local/include)

if(NOT RE_INCLUDE_DIR)
    message(FATAL_ERROR "Nie znaleziono re/re.h. Zainstaluj: sudo dnf install libre-devel")
endif()
if(NOT BARESIP_INCLUDE_DIR)
    message(FATAL_ERROR "Nie znaleziono baresip.h. Zainstaluj: sudo dnf install baresip-devel")
endif()

# 3. Ręcznie znajdź biblioteki
find_library(RE_LIBRARY NAMES re PATHS /usr/lib64 /usr/lib /usr/local/lib64 /usr/local/lib)
find_library(BARESIP_LIBRARY NAMES baresip PATHS /usr/lib64 /usr/lib /usr/local/lib64 /usr/local/lib)

if(NOT RE_LIBRARY)
    message(FATAL_ERROR "Nie znaleziono biblioteki libre.so")
endif()
if(NOT BARESIP_LIBRARY)
    message(FATAL_ERROR "Nie znaleziono biblioteki libbaresip.so")
endif()

add_library(TKEngine SHARED
    src/TKEngine.cpp
    src/SIPManager.cpp
    src/Recorder.cpp
    src/Config.cpp
)

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

target_link_libraries(TKEngine PRIVATE
    ${BARESIP_LIBRARY}
    ${RE_LIBRARY}
    ${SRTP_LIBRARIES}
    pthread
)

if(WIN32)
    target_link_libraries(TKEngine PRIVATE ws2_32)
endif()

target_compile_definitions(TKEngine PRIVATE TKENGINE_EXPORTS)

install(TARGETS TKEngine
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
    ARCHIVE DESTINATION lib
)
install(DIRECTORY include/tkengine DESTINATION include)
