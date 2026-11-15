#pragma once
#include <string>
#include <functional>
#include <memory>
#include <thread>
#include <atomic>
#include <cstdint>

#include "tkengine/TKEngine.h"

extern "C" {
#include <re/re.h>      // ← NAJPIERW libre (typy bazowe)
#include <baresip.h>    // ← POTEM baresip (API wysokiego poziomu)
}

namespace tk {

class SIPManager {
public:
    SIPManager();
    ~SIPManager();

    bool initialize(const std::string& username, const std::string& password, const std::string& domain);
    bool registerAccount();
    void unregisterAccount();
    bool makeCall(const std::string& destination);
    void acceptCall(const std::string& callId);
    void rejectCall(const std::string& callId);
    void hangupCall(const std::string& callId);
    void sendDTMF(const std::string& callId, char digit);
    void startProcessing();
    void stopProcessing();

    std::function<void(const CallInfo&)> onCallState;
    std::function<void(const std::string& callId, const std::string& remoteUri)> onIncoming;
    std::function<void(const std::string& callId, char digit)> onDTMF;
    std::function<void(bool success, const std::string& message)> onRegistration;
    std::function<void(const std::string& error)> onError;
    std::function<void(const uint8_t* data, size_t len)> onAudioReceived;

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace tk