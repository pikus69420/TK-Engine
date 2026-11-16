<img title="" src="https://files.catbox.moe/gcg9pm.png" alt="tk_logo (1).png" width="153" />

# TK Engine

Wrapper dla baresip i libre który umożliwia łatwą integrację z Telekomunikacją Kaliską.

![Static Badge](https://img.shields.io/badge/Telekomunikacja_Kaliska-yellow) ![Static Badge](https://img.shields.io/badge/Licencja-Apache_2.0-blue?color=orange) ![Static Badge](https://img.shields.io/badge/J%C4%99zyk_programowania-C%2B%2B-blue) ![Static Badge](https://img.shields.io/badge/Platformy-Windows_Linux_MacOS-green)

---

## Podstawowe funkcje

- Wbudowane nagrywanie (WAV/OPUS)

- Integracja z serwerem SIP Telekomunikacji Kaliskiej

- Możliwość wbudowania pliku DLL/so bez pisania całego kodu SIP

---

## Kompilowanie TK Engine

**Na Linux/MacOS**

Uruchom skrypt:

```bash
chmod +x build.sh
./build.sh
```

Kompilowanie na MacOS działa tylko na systemie MacOS (apple będące apple) i nie zostało sprawdzone przezemnie.

**Na Windows (kompilowanie tylko na Windowsa)**

Uruchom Powershell jako administrator i wykonaj te komendy będąc w folderze z skryptem:

```powershell
Unblock-File -Path.\build.ps1
./build.ps1
```

Nie gwarantuję stabilności i działania.

## Przykład wykorzystania wrappera

```cpp
#include <iostream>
#include <string>

// Ładowanie bibliotek systemowych na samej górze
#ifdef _WIN32
    #include <windows.h>
#else
    #include <dlfcn.h>
    #include <unistd.h>
#endif

// Definicja typów i funkcji
typedef void* (*CreateEngineFunc)();
typedef void (*DestroyEngineFunc)(void*);
typedef bool (*InitFunc)(void*, const char*, const char*);
typedef bool (*RegisterFunc)(void*);
typedef void (*CallFunc)(void*, const char*);
typedef void (*HangupFunc)(void*);
typedef void (*StartProcFunc)(void*);
typedef void (*StopProcFunc)(void*);

int main() {
    void* engine = nullptr;

    // Wskaźniki na funkcje z DLL/SO
    CreateEngineFunc create = nullptr;
    DestroyEngineFunc destroy = nullptr;
    InitFunc init = nullptr;
    RegisterFunc reg = nullptr;
    CallFunc call = nullptr;
    HangupFunc hangup = nullptr;
    StartProcFunc startProc = nullptr;
    StopProcFunc stopProc = nullptr;

    // Ładowanie bibliotek
#ifdef _WIN32
    HMODULE hLib = LoadLibraryA("TK-Engine.dll");
    if (!hLib) {
        std::cerr << "[Blad] Nie mozna zaladowac TK-Engine.dll! Kod: " << GetLastError() << std::endl;
        return 1;
    }
    create    = (CreateEngineFunc)GetProcAddress(hLib, "CreateTKEngine");
    destroy   = (DestroyEngineFunc)GetProcAddress(hLib, "DestroyTKEngine");
    init      = (InitFunc)GetProcAddress(hLib, "TKEngine_Initialize");
    reg       = (RegisterFunc)GetProcAddress(hLib, "TKEngine_Register");
    call      = (CallFunc)GetProcAddress(hLib, "TKEngine_MakeCall");
    hangup    = (HangupFunc)GetProcAddress(hLib, "TKEngine_Hangup");
    startProc = (StartProcFunc)GetProcAddress(hLib, "TKEngine_StartProcessing");
    stopProc  = (StopProcFunc)GetProcAddress(hLib, "TKEngine_StopProcessing");
#else
    void* hLib = dlopen("./libTK-Engine.so", RTLD_LAZY);
    if (!hLib) {
        std::cerr << "[Blad] Nie mozna zaladowac libTK-Engine.so! " << dlerror() << std::endl;
        return 1;
    }
    create    = (CreateEngineFunc)dlsym(hLib, "CreateTKEngine");
    destroy   = (DestroyEngineFunc)dlsym(hLib, "DestroyTKEngine");
    init      = (InitFunc)dlsym(hLib, "TKEngine_Initialize");
    reg       = (RegisterFunc)dlsym(hLib, "TKEngine_Register");
    call      = (CallFunc)dlsym(hLib, "TKEngine_MakeCall");
    hangup    = (HangupFunc)dlsym(hLib, "TKEngine_Hangup");
    startProc = (StartProcFunc)dlsym(hLib, "TKEngine_StartProcessing");
    stopProc  = (StopProcFunc)dlsym(hLib, "TKEngine_StopProcessing");
#endif

    // Sprawdzenie, czy wszystkie funkcje istnieją w bibliotece
    if (!create || !destroy || !init || !reg || !call || !startProc || !stopProc) {
        std::cerr << "[Blad] Nie znaleziono wymaganych funkcji w bibliotece!" << std::endl;
        return 1;
    }

    // Użycie
    std::cout << "[1] Tworzenie instancji wrappera..." << std::endl;
    engine = create();

    std::cout << "[2] Inicjalizacja (login: moj_login, haslo: moje_haslo)..." << std::endl;
    if (!init(engine, "moj_login", "moje_haslo")) {
        std::cerr << "[Blad] Inicjalizacja SIP nie powiodla sie." << std::endl;
        destroy(engine);
        return 1;
    }

    std::cout << "[3] Uruchamianie watku SIP (re_main)..." << std::endl;
    startProc(engine);

    std::cout << "[4] Rejestracja na serwerze Telekomunikacji Kaliskiej..." << std::endl;
    if (reg(engine)) {
        std::cout << " -> Zarejestrowano pomyslnie!" << std::endl;
    } else {
        std::cout << " -> Blad rejestracji (sprawdz logi)." << std::endl;
    }

#ifdef _WIN32
    Sleep(2000);
#else
    sleep(2);
#endif

    std::cout << "[5] Wybieranie numeru '100'..." << std::endl;
    call(engine, "100");

#ifdef _WIN32
    Sleep(5000);
#else
    sleep(5);
#endif

    std::cout << "[6] Rozlaczanie..." << std::endl;
    hangup(engine);

    // Sprzątanie
    std::cout << "[7] Zatrzymywanie wrappera i zwalnianie pamieci..." << std::endl;
    stopProc(engine);
    destroy(engine);

#ifdef _WIN32
    FreeLibrary(hLib);
#else
    dlclose(hLib);
#endif

    std::cout << "Koniec programu." << std::endl;
    return 0;
}
```

## Licencje

| Nazwa pakietu | Autor                      | Licencja                                |
| ------------- | -------------------------- | --------------------------------------- |
| baresip       | Alfred E. Heggestad i inni | BSD 3-Clause "New" or "Revised" License |
| libre         | Alfred E. Heggestad i inni | BSD 3-Clause "New" or "Revised" License |
| libsrtp2      | Cisco Systems, Inc.        | BSD-style                               |
