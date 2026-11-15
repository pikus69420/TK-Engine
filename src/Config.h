#pragma once
#include "tkengine/TKEngine.h"
#include <string>
#include <filesystem>

namespace tk {

class Config {
public:
    static std::filesystem::path getConfigPath();
    static bool saveCredentials(const AccountConfig& config);
    static bool loadCredentials(AccountConfig& config);
};

} // namespace tk