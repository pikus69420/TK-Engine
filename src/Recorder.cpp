#include "Recorder.h"
#include <iostream>

namespace tk {

bool Recorder::start(const std::string& filePath) {
    m_file.open(filePath, std::ios::binary);
    if (!m_file.is_open()) {
        std::cerr << "[Recorder] Nie można otworzyć pliku: " << filePath << std::endl;
        return false;
    }
    m_recording = true;
    m_dataSize = 0;
    writeHeader(); // Zapisz tymczasowy nagłówek WAV
    return true;
}

void Recorder::stop() {
    if (!m_recording) return;
    m_recording = false;
    updateHeader(); // Nadpisz nagłówek z prawdziwym rozmiarem danych
    m_file.close();
}

void Recorder::writeAudio(const uint8_t* data, size_t len) {
    if (!m_recording || !data || len == 0) return;
    
    // Zapisz surowe bajty audio
    m_file.write(reinterpret_cast<const char*>(data), len);
    m_dataSize += static_cast<uint32_t>(len);
}

bool Recorder::isRecording() const {
    return m_recording;
}

void Recorder::writeHeader() {
    // Standardowy nagłówek WAV (44 bajty)
    // Uwaga: Zakładamy 16-bit PCM (L16). Jeśli Twój serwer wysyła G.711 (8-bit),
    // dźwięk może być zniekształcony, ale plik będzie poprawny strukturalnie.
    const char riff[] = "RIFF";
    uint32_t fileSize = 36 + m_dataSize; // Placeholder
    const char wave[] = "WAVE";
    const char fmt[] = "fmt ";
    uint32_t fmtSize = 16;
    uint16_t audioFormat = 1; // 1 = PCM
    uint16_t numChannels = 1; // Mono
    uint32_t sampleRate = m_sampleRate;
    uint16_t bitsPerSample = 16; 
    uint16_t blockAlign = numChannels * bitsPerSample / 8;
    uint32_t byteRate = sampleRate * blockAlign;
    const char data[] = "data";
    uint32_t dataSize = m_dataSize; // Placeholder

    m_file.write(riff, 4);
    m_file.write(reinterpret_cast<const char*>(&fileSize), 4);
    m_file.write(wave, 4);
    m_file.write(fmt, 4);
    m_file.write(reinterpret_cast<const char*>(&fmtSize), 4);
    m_file.write(reinterpret_cast<const char*>(&audioFormat), 2);
    m_file.write(reinterpret_cast<const char*>(&numChannels), 2);
    m_file.write(reinterpret_cast<const char*>(&sampleRate), 4);
    m_file.write(reinterpret_cast<const char*>(&byteRate), 4);
    m_file.write(reinterpret_cast<const char*>(&blockAlign), 2);
    m_file.write(reinterpret_cast<const char*>(&bitsPerSample), 2);
    m_file.write(data, 4);
    m_file.write(reinterpret_cast<const char*>(&dataSize), 4);
}

void Recorder::updateHeader() {
    if (!m_file.is_open()) return;
    
    // Zapamiętaj obecną pozycję w pliku
    std::streampos currentPos = m_file.tellp();
    
    // Nadpisz rozmiar pliku (offset 4)
    m_file.seekp(4);
    uint32_t fileSize = 36 + m_dataSize;
    m_file.write(reinterpret_cast<const char*>(&fileSize), 4);
    
    // Nadpisz rozmiar danych (offset 40)
    m_file.seekp(40);
    m_file.write(reinterpret_cast<const char*>(&m_dataSize), 4);
    
    // Wróć na koniec pliku
    m_file.seekp(currentPos);
}

} // namespace tk