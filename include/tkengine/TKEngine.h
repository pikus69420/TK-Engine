#pragma once
#include <string>
#include <functional>
#include <memory>

// Makro eksportu dla Windows/Linux
#ifdef _WIN32
    #ifdef TKENGINE_EXPORTS
        #define TKENGINE_API __declspec(dllexport)
    #else
        #define TKENGINE_API __declspec(dllimport)
    #endif
#else
    #define TKENGINE_API __attribute__((visibility("default")))
#endif

namespace tk {

enum class CallState {
    Ringing,
    Calling,
    Connected,
    Terminated
};

struct TKENGINE_API CallInfo {
    std::string callId;
    std::string remoteUri;
    CallState state;
};

struct TKENGINE_API AccountConfig {
    std::string username;
    std::string password;
    std::string domain;
    std::string serverIp = "15.235.62.162";
    int serverPort = 5060;
};

class TKENGINE_API TKEngine {
public:
    TKEngine();
    ~TKEngine();

    // Inicjalizacja i rejestracja
    bool initialize(const AccountConfig& config);
    bool registerAccount();
    void unregisterAccount();

    // Zarządzanie połączeniami
    bool makeCall(const std::string& destination);
    void acceptCall(const std::string& callId);
    void rejectCall(const std::string& callId);
    void hangupCall(const std::string& callId);
    void sendDTMF(const std::string& callId, char digit);

    // Nagrywanie (uproszczone: globalne dla aktywnego połączenia)
    void startRecording(const std::string& filePath);
    void stopRecording();

    // Pętla przetwarzania
    void startProcessing();
    void stopProcessing();

    // Callbacki
    std::function<void(const CallInfo&)> onCallState;
    std::function<void(const std::string& callId, const std::string& remoteUri)> onIncoming;
    std::function<void(const std::string& callId, char digit)> onDTMF;
    std::function<void(bool success, const std::string& message)> onRegistration;
    std::function<void(const std::string& error)> onError;

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace tk