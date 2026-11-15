#pragma once

#ifdef _WIN32
    #ifdef TKENGINE_EXPORTS
        #define TKENGINE_API __declspec(dllexport)
    #else
        #define TKENGINE_API __declspec(dllimport)
    #endif
#else
    #define TKENGINE_API __attribute__((visibility("default")))
#endif