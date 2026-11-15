#include "tkengine/TKEngine.h"
#include "SIPManager.h"
#include "Recorder.h"
#include <iostream>

namespace tk {

struct TKEngine::Impl {
    std::unique_ptr<SIPManager> sip;
    std::unique_ptr<Recorder> recorder;
    AccountConfig account;
};

TKEngine::TKEngine() : m_impl(std::make_unique<Impl>()) {}

TKEngine::~TKEngine() = default;

bool TKEngine::initialize(const AccountConfig& config) {
    m_impl->account = config;

    m_impl->sip = std::make_unique<SIPManager>();
    m_impl->recorder = std::make_unique<Recorder>();

    // Połącz SIP z Recorderem przez callback audio
    m_impl->sip->onAudioReceived = [this](const uint8_t* data, size_t len) {
        m_impl->recorder->writeAudio(data, len);
    };

    // Przekazujemy callbacki z SIPManagera na zewnątrz TKEngine
    m_impl->sip->onCallState = [this](const CallInfo& info) {
        if (this->onCallState) this->onCallState(info);
    };
    m_impl->sip->onIncoming = [this](const std::string& callId, const std::string& remoteUri) {
        if (this->onIncoming) this->onIncoming(callId, remoteUri);
    };
    m_impl->sip->onDTMF = [this](const std::string& callId, char digit) {
        if (this->onDTMF) this->onDTMF(callId, digit);
    };
    m_impl->sip->onRegistration = [this](bool success, const std::string& msg) {
        if (this->onRegistration) this->onRegistration(success, msg);
    };
    m_impl->sip->onError = [this](const std::string& err) {
        if (this->onError) this->onError(err);
    };

    if (!m_impl->sip->initialize(config.username, config.password, config.domain)) {
        std::cerr << "[TKEngine] Failed to initialize SIP" << std::endl;
        return false;
    }

    return true;
}

bool TKEngine::registerAccount() {
    return m_impl->sip->registerAccount();
}

void TKEngine::unregisterAccount() {
    m_impl->sip->unregisterAccount();
}

bool TKEngine::makeCall(const std::string& destination) {
    return m_impl->sip->makeCall(destination);
}

void TKEngine::acceptCall(const std::string& callId) {
    m_impl->sip->acceptCall(callId);
}

void TKEngine::rejectCall(const std::string& callId) {
    m_impl->sip->rejectCall(callId);
}

void TKEngine::hangupCall(const std::string& callId) {
    m_impl->sip->hangupCall(callId);
}

void TKEngine::sendDTMF(const std::string& callId, char digit) {
    m_impl->sip->sendDTMF(callId, digit);
}

void TKEngine::startRecording(const std::string& filePath) {
    m_impl->recorder->start(filePath);
}

void TKEngine::stopRecording() {
    m_impl->recorder->stop();
}

void TKEngine::startProcessing() {
    m_impl->sip->startProcessing();
}

void TKEngine::stopProcessing() {
    m_impl->sip->stopProcessing();
}

} // namespace tk