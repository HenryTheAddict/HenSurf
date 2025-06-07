# HenSurf Browser Architecture

HenSurf is a privacy-focused, lightweight browser based on Chromium with AI features and bloatware removed.

## Overview

HenSurf takes the open-source Chromium browser and applies targeted modifications to:
- Remove AI-powered features
- Disable Google services integration
- Enhance privacy by default
- Eliminate promotional content and bloatware
- Provide a clean, fast browsing experience

## Key Modifications

### 1. AI Feature Removal

**Removed Components:**
- Autofill Assistant (AI-powered form filling)
- Smart suggestions and predictions
- Machine learning-based features
- Google Now integration
- Voice search and hotwording
- Supervised user features

**Implementation:**
- Build flags disable AI components at compile time
- Patches remove AI-related UI elements
- ML libraries and dependencies excluded from build

### 2. Google Services Removal

**Disabled Services:**
- Google API integration
- Account sync and signin
- Cloud policy management
- Safe browsing (Google-based)
- Spell checking (Google-based)
- Crash reporting to Google
- Usage statistics and metrics

**Implementation:**
- API keys removed/disabled
- Network requests to Google services blocked
- Authentication flows disabled
- Local alternatives implemented where possible

### 3. Privacy Enhancements

**Default Settings:**
- DuckDuckGo as default search engine
- Enhanced tracking protection enabled
- Third-party cookies blocked
- DNS-over-HTTPS with privacy-focused providers
- No telemetry or usage data collection

**Technical Implementation:**
- Modified prepopulated search engines
- Updated default privacy preferences
- Removed tracking and analytics code

### 4. Bloatware Removal

**Removed Features:**
- Promotional tabs and content
- Welcome/onboarding flows
- App suggestions and recommendations
- Chrome Web Store promotions
- Google services advertisements

**Implementation:**
- UI components removed via patches
- Promotional content files deleted
- Marketing-related code disabled

## Build System

### Configuration

HenSurf uses a custom GN build configuration (`config/hensurf.gn`) that:
- Disables unwanted features via build flags
- Optimizes for privacy and performance
- Removes Google-specific components
- Enables only essential features

### Patch System

The patch system (`patches/`) contains:
- Source code modifications
- UI element removals
- Default setting changes
- Branding updates

### Build Process

1. **Dependency Installation** (`install-deps.sh`)
   - Installs required build tools
   - Sets up depot_tools
   - Verifies system requirements

2. **Source Fetch** (`fetch-chromium.sh`)
   - Downloads Chromium source code
   - Applies initial setup
   - Prepares build environment

3. **Patch Application** (`apply-patches.sh`)
   - Applies HenSurf customizations
   - Updates branding and configuration
   - Removes unwanted components

4. **Build Execution** (`build.sh`)
   - Compiles HenSurf browser
   - Creates application bundle
   - Generates installer

## Security Considerations

### Removed Attack Vectors
- No Google API communication
- No cloud sync vulnerabilities
- Reduced network surface area
- No AI model exploitation risks

### Enhanced Security
- Local-only features where possible
- Minimal external dependencies
- Privacy-focused defaults
- Regular security updates from Chromium upstream

## Performance Benefits

### Reduced Resource Usage
- No AI processing overhead
- Fewer background services
- Smaller memory footprint
- Faster startup times

### Network Efficiency
- No telemetry uploads
- Reduced external requests
- Local search suggestions
- Minimal tracking protection overhead

## Maintenance Strategy

### Upstream Tracking
- Regular Chromium security updates
- Selective feature adoption
- Patch compatibility maintenance

### Testing
- Automated build verification
- Privacy feature testing
- Performance benchmarking
- Security audit procedures

## Future Enhancements

### Planned Features
- Built-in ad blocker
- Enhanced privacy dashboard
- Local bookmark sync
- Custom extension store

### Research Areas
- Alternative search integration
- Decentralized sync solutions
- Advanced privacy features
- Performance optimizations

## Comparison with Other Browsers

| Feature | HenSurf | Chrome | Brave | Firefox |
|---------|---------|--------|-------|----------|
| AI Features | ❌ | ✅ | ❌ | ❌ |
| Google Services | ❌ | ✅ | ❌ | ❌ |
| Built-in Ads | ❌ | ❌ | ✅ | ❌ |
| Telemetry | ❌ | ✅ | ⚠️ | ⚠️ |
| Privacy Default | ✅ | ❌ | ✅ | ✅ |
| Performance | ✅ | ✅ | ✅ | ⚠️ |
| Open Source | ✅ | ⚠️ | ✅ | ✅ |

## Contributing

See the main README.md for contribution guidelines and development setup instructions.