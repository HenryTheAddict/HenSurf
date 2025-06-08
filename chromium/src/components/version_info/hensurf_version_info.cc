#include "components/version_info/version_info.h"

namespace version_info {

std::string GetProductName() {
  return "HenSurf";
}

std::string GetProductNameAndVersionForUserAgent() {
  return "HenSurf/1.0";
}

}  // namespace version_info
