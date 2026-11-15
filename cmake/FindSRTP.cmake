find_path(SRTP_INCLUDE_DIR
    NAMES srtp2/srtp.h
    PATHS
        /usr/include
        /usr/local/include
        $ENV{SRTP_ROOT}/include
)

find_library(SRTP_LIBRARY
    NAMES srtp2
    PATHS
        /usr/lib
        /usr/local/lib
        $ENV{SRTP_ROOT}/lib
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SRTP
    REQUIRED_VARS SRTP_LIBRARY SRTP_INCLUDE_DIR
)

if(SRTP_FOUND)
    set(SRTP_LIBRARIES ${SRTP_LIBRARY})
    set(SRTP_INCLUDE_DIRS ${SRTP_INCLUDE_DIR})
endif()

mark_as_advanced(SRTP_INCLUDE_DIR SRTP_LIBRARY)
