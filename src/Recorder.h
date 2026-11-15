#pragma once
#include <string>
#include <fstream>
#include <cstdint>

namespace tk {

class Recorder {
public:
    bool start(const std::string& filePath);
    void stop();
    void writeAudio(const uint8_t* data, size_t len);
    bool isRecording() const;

private:
    std::ofstream m_file;
    bool m_recording = false;
    uint32_t m_dataSize = 0;
    int m_sampleRate = 8000; // Domyślnie 8kHz (standard VoIP)
    
    void writeHeader();
    void updateHeader();
};

} // namespace tk