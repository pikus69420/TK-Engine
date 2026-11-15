# Szuka bibliotek reSIProcate
# Ustawia: RESIPROCATE_FOUND, RESIPROCATE_INCLUDE_DIRS, RESIPROCATE_LIBRARIES

find_path(RESIPROCATE_INCLUDE_DIR
    NAMES resip/stack/Stack.hxx
    PATHS
        /usr/include
        /usr/local/include
        $ENV{RESIPROCATE_ROOT}/include
        ${RESIPROCATE_ROOT}/include
)

# reSIProcate składa się z kilku bibliotek
find_library(RESIP_LIB
    NAMES resip
    PATHS /usr/lib /usr/lib64 /usr/local/lib /usr/local/lib64
)

find_library(RUTIL_LIB
    NAMES rutil
    PATHS /usr/lib /usr/lib64 /usr/local/lib /usr/local/lib64
)

find_library(DUM_LIB
    NAMES dum
    PATHS /usr/lib /usr/lib64 /usr/local/lib /usr/local/lib64
)

find_library(RESIPARES_LIB
    NAMES resipares
    PATHS /usr/lib /usr/lib64 /usr/local/lib /usr/local/lib64
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(RESIPROCATE
    REQUIRED_VARS RESIPROCATE_INCLUDE_DIR RESIP_LIB RUTIL_LIB DUM_LIB
)

if(RESIPROCATE_FOUND)
    set(RESIPROCATE_INCLUDE_DIRS ${RESIPROCATE_INCLUDE_DIR})
    set(RESIPROCATE_LIBRARIES ${RESIP_LIB} ${RUTIL_LIB} ${DUM_LIB})
    # Opcjonalnie dodaj resipares jeśli znaleziono
    if(RESIPARES_LIB)
        list(APPEND RESIPROCATE_LIBRARIES ${RESIPARES_LIB})
    endif()
endif()

mark_as_advanced(RESIPROCATE_INCLUDE_DIR RESIP_LIB RUTIL_LIB DUM_LIB RESIPARES_LIB)
