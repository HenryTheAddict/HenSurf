// HenSurf custom search engines
#include "components/search_engines/search_engines_pref_names.h"
#include "components/search_engines/template_url_prepopulate_data.h"

namespace TemplateURLPrepopulateData {

// DuckDuckGo search engine for HenSurf
const PrepopulatedEngine duckduckgo = {
  L"DuckDuckGo",
  L"duckduckgo.com",
  "https://duckduckgo.com/favicon.ico",
  "https://duckduckgo.com/?q={searchTerms}",
  nullptr,  // No suggestions URL for privacy
  nullptr,
  nullptr,
  nullptr,
  nullptr,
  nullptr,
  nullptr,
  SEARCH_ENGINE_DUCKDUCKGO,
  1,  // ID
};

}  // namespace TemplateURLPrepopulateData
