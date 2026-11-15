#include "Config.h"
#include <fstream>
#include <iostream>

namespace tk {

bool Config::saveCredentials(const AccountConfig& config) {
    std::ofstream file("tk_config.dat", std::ios::binary);
    if (!file.is_open()) {
        std::cerr << "[Config] Nie można zapisać konfiguracji" << std::endl;
        return false;
    }
    
    file << config.username << "\n"
         << config.password << "\n"
         << config.domain << "\n"
         << config.serverIp << "\n"
         << config.serverPort << "\n";
    
    return true;
}

bool Config::loadCredentials(AccountConfig& config) {
    std::ifstream file("tk_config.dat", std::ios::binary);
    if (!file.is_open()) {
        std::cerr << "[Config] Nie znaleziono pliku konfiguracji" << std::endl;
        return false;
    }
    
    std::getline(file, config.username);
    std::getline(file, config.password);
    std::getline(file, config.domain);
    std::getline(file, config.serverIp);
    
    std::string portStr;
    std::getline(file, portStr);
    if (!portStr.empty()) {
        config.serverPort = std::stoi(portStr);
    }
    
    return true;
}

} // namespace tk