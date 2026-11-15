#include "SIPManager.h"
#include "tkengine/TKEngine.h"
#include <iostream>

namespace tk {

struct SIPManager::Impl {
    struct sip  *sip  = nullptr;
    struct ua   *ua   = nullptr;
    struct call *call = nullptr;
    
    std::string username;
    std::string password;
    std::string domain;
    
    std::thread pollThread;
    std::atomic<bool> running{false};
};

// --- Callbacki C ---

static void reg_response_handler(int err, const struct sip_msg *msg, void *arg)
{
    auto* self = static_cast<SIPManager*>(arg);
    if (err) {
        if (self->onRegistration) self->onRegistration(false, std::string("Błąd: ") + strerror(err));
        return;
    }
    if (msg && msg->scode == 200) {
        if (self->onRegistration) self->onRegistration(true, "Zarejestrowano");
    } else if (msg) {
        if (self->onRegistration) self->onRegistration(false, "Odrzucono: " + std::to_string(msg->scode));
    }
}

static void dtmf_handler(struct call *call, char key, void *arg)
{
    auto* self = static_cast<SIPManager*>(arg);
    if (self->onDTMF) self->onDTMF(call_id(call), key);
}

static void call_event_handler(struct call *call, enum call_event ev, const char *prm, void *arg)
{
    auto* self = static_cast<SIPManager*>(arg);
    switch (ev) {
    case CALL_EVENT_INCOMING: {
        CallInfo info;
        info.callId = call_id(call);
        info.remoteUri = call_peeruri(call);
        info.state = CallState::Ringing;
        if (self->onCallState) self->onCallState(info);
        if (self->onIncoming)  self->onIncoming(info.callId, info.remoteUri);
        
        // Ustaw handler DTMF dla tego konkretnego połączenia
        call_set_handlers(call, nullptr, dtmf_handler, self);
        break;
    }
    case CALL_EVENT_ESTABLISHED: {
        CallInfo info;
        info.callId = call_id(call);
        info.state = CallState::Connected;
        if (self->onCallState) self->onCallState(info);
        break;
    }
    case CALL_EVENT_CLOSED: {
        CallInfo info;
        info.callId = call_id(call);
        info.state = CallState::Terminated;
        if (self->onCallState) self->onCallState(info);
        break;
    }
    default:
        break;
    }
}

// Nowy handler zdarzeń dla baresip 4.x (bevent API)
static void ua_event_handler(enum bevent_ev ev, struct bevent *event, void *arg)
{
    auto* self = static_cast<SIPManager*>(arg);
    struct call *call = bevent_get_call(event); // Pobierz obiekt call z eventu
    
    if (!call) return;

    if (ev == BEVENT_CALL_INCOMING) {
        call_event_handler(call, CALL_EVENT_INCOMING, nullptr, self);
    } else if (ev == BEVENT_CALL_ESTABLISHED) {
        call_event_handler(call, CALL_EVENT_ESTABLISHED, nullptr, self);
    } else if (ev == BEVENT_CALL_CLOSED) {
        call_event_handler(call, CALL_EVENT_CLOSED, nullptr, self);
    }
}

// --- Implementacja klasy ---

SIPManager::SIPManager() : m_impl(std::make_unique<Impl>()) {}

SIPManager::~SIPManager() {
    stopProcessing();
}

bool SIPManager::initialize(const std::string& username, const std::string& password, const std::string& domain)
{
    m_impl->username = username;
    m_impl->password = password;
    m_impl->domain   = domain;

    // 1. Inicjalizacja stosu SIP
    int err = sip_alloc(&m_impl->sip, nullptr, 32, 32, 32, "TK Engine", nullptr, nullptr);
    if (err) { if (onError) onError("sip_alloc: " + std::to_string(err)); return false; }

    // 2. Dodaj transport UDP
    err = sip_transp_add(m_impl->sip, SIP_TRANSP_UDP, nullptr, 0, 5060);
    if (err) { if (onError) onError("sip_transp_add: " + std::to_string(err)); return false; }

    // 3. Utwórz User Agent (hasło w URI)
    std::string aor = "sip:" + username + "@" + domain + ";auth_pass=" + password;
    err = ua_alloc(&m_impl->ua, aor.c_str());
    if (err) { if (onError) onError("ua_alloc: " + std::to_string(err)); return false; }

    // 4. Zarejestruj globalny handler zdarzeń (nowe API baresip 4.x)
    bevent_register(ua_event_handler, this);

    return true;
}

bool SIPManager::registerAccount()
{
    if (!m_impl->ua) return false;
    return ua_register(m_impl->ua) == 0;
}

void SIPManager::unregisterAccount()
{
    if (m_impl->ua) ua_unregister(m_impl->ua);
}

bool SIPManager::makeCall(const std::string& destination)
{
    if (!m_impl->ua) return false;
    std::string uri = "sip:" + destination + "@" + m_impl->domain;
    
    int err = ua_connect(m_impl->ua, &m_impl->call, nullptr, uri.c_str(), VIDMODE_OFF);
    if (err) { if (onError) onError("ua_connect: " + std::to_string(err)); return false; }

    CallInfo info;
    info.callId = call_id(m_impl->call);
    info.remoteUri = uri;
    info.state = CallState::Calling;
    if (onCallState) onCallState(info);
    return true;
}

void SIPManager::acceptCall(const std::string&)
{
    if (m_impl->call) call_answer(m_impl->call, 200, VIDMODE_OFF);
}

void SIPManager::rejectCall(const std::string&)
{
    if (m_impl->call) { call_hangup(m_impl->call, 486, "Busy"); m_impl->call = nullptr; }
}

void SIPManager::hangupCall(const std::string&)
{
    if (m_impl->call) { call_hangup(m_impl->call, 0, nullptr); m_impl->call = nullptr; }
}

void SIPManager::sendDTMF(const std::string&, char digit)
{
    if (m_impl->call) call_send_digit(m_impl->call, digit);
}

void SIPManager::startProcessing()
{
    m_impl->running = true;
    m_impl->pollThread = std::thread([this]() {
        // re_main blokuje, dopóki nie zostanie wywołane re_cancel() z innego wątku
        re_main(nullptr);
    });
}

void SIPManager::stopProcessing()
{
    if (m_impl->running) {
        m_impl->running = false;
        re_cancel(); // To przerwie re_main w wątku pollThread
        if (m_impl->pollThread.joinable()) m_impl->pollThread.join();
    }

    if (m_impl->call) { call_hangup(m_impl->call, 0, nullptr); m_impl->call = nullptr; }
    if (m_impl->ua) { ua_unregister(m_impl->ua); mem_deref(m_impl->ua); m_impl->ua = nullptr; }
    if (m_impl->sip) { mem_deref(m_impl->sip); m_impl->sip = nullptr; }
}

} // namespace tk