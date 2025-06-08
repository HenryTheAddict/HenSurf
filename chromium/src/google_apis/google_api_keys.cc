// HenSurf - Disable Google API keys
#include "google_apis/google_api_keys.h"

namespace google_apis {

std::string GetAPIKey() { return std::string(); }
std::string GetOAuth2ClientID(OAuth2Client client) { return std::string(); }
std::string GetOAuth2ClientSecret(OAuth2Client client) { return std::string(); }
bool HasAPIKeyConfigured() { return false; }
bool HasOAuthConfigured() { return false; }

}  // namespace google_apis
