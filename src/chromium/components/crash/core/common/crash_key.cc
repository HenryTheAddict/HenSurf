// HenSurf - Disable crash reporting
#include "components/crash/core/common/crash_key.h"

namespace crash_keys {
void SetCrashKeyValue(const std::string& key, const std::string& value) {}
void ClearCrashKey(const std::string& key) {}
void SetCrashKeyToInt(const std::string& key, int value) {}
}  // namespace crash_keys
