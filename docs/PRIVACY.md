# HenSurf Privacy Policy

## Table of Contents

- [Privacy Philosophy](#privacy-philosophy)
- [Data Collection](#data-collection)
  - [What We DON'T Collect](#what-we-dont-collect)
  - [What We Collect (Minimal)](#what-we-collect-minimal)
- [Default Privacy Settings](#default-privacy-settings)
  - [Search Engine](#search-engine)
  - [Tracking Protection](#tracking-protection)
  - [Network Privacy](#network-privacy)
  - [Storage](#storage)
- [Removed Privacy Risks](#removed-privacy-risks)
  - [Google Services Integration](#google-services-integration)
  - [AI and Machine Learning](#ai-and-machine-learning)
  - [Telemetry and Analytics](#telemetry-and-analytics)
- [Data Storage](#data-storage)
  - [Local Storage Only](#local-storage-only)
  - [Data Encryption](#data-encryption)
  - [Data Retention](#data-retention)
- [Network Communications](#network-communications)
  - [Outbound Connections](#outbound-connections)
  - [Blocked Connections](#blocked-connections)
- [User Controls](#user-controls)
  - [Privacy Settings](#privacy-settings)
  - [Data Management](#data-management)
  - [Advanced Privacy](#advanced-privacy)
- [Extensions and Add-ons](#extensions-and-add-ons)
  - [Extension Privacy](#extension-privacy)
  - [Recommended Extensions](#recommended-extensions)
- [Comparison with Other Browsers](#comparison-with-other-browsers)
- [Security Measures](#security-measures)
  - [Code Security](#code-security)
  - [Network Security](#network-security)
  - [Sandboxing](#sandboxing)
- [Transparency](#transparency)
  - [Open Source](#open-source)
  - [Regular Audits](#regular-audits)
- [Legal Compliance](#legal-compliance)
  - [GDPR Compliance](#gdpr-compliance)
  - [CCPA Compliance](#ccpa-compliance)
- [Contact and Support](#contact-and-support)
  - [Privacy Questions](#privacy-questions)
  - [Security Issues](#security-issues)
- [Updates to This Policy](#updates-to-this-policy)
  - [Change Process](#change-process)
  - [Version History](#version-history)
- [Conclusion](#conclusion)

HenSurf is designed with privacy as a core principle. This document explains our privacy practices and how we protect your data.

## Privacy Philosophy

HenSurf believes that:
- **Privacy is a fundamental right**
- **Data collection should be minimal and transparent**
- **Users should have full control over their data**
- **Local processing is preferred over cloud services**

## Data Collection

### What We DON'T Collect

❌ **Browsing History**: We don't track or store your browsing history
❌ **Search Queries**: Your searches are not logged or analyzed
❌ **Personal Information**: No collection of names, emails, or other directly identifiable personal data.
❌ **Usage Analytics (Telemetry)**: We don't collect data about how you use the browser, such as which features you use or how often you browse (this is often called "telemetry").
❌ **Location Data**: HenSurf does not track your physical location.
❌ **Behavioral Profiles**: No creation of user profiles or behavioral analysis
❌ **AI Training Data**: Your data is never used to train AI models
❌ **Cross-Site Tracking**: No tracking across websites
❌ **Advertising Data**: No data collection for advertising purposes

### What We Collect (Minimal)

✅ **Crash Reports** (Optional): Only if you explicitly enable crash reporting
- Contains technical information about crashes
- No personal data included
- Can be completely disabled in settings
- Stored locally, not transmitted unless you choose

✅ **Update Checks** (Essential): Only version information to check for updates
- No personal identifiers
- Only browser version number
- Can be disabled (but not recommended for security)

## Default Privacy Settings

HenSurf ships with privacy-focused defaults:

### Search Engine
- **Default**: DuckDuckGo (privacy-focused search)
- **No Google**: Google search integration removed
- **No Suggestions**: No search suggestions that leak queries

### Tracking Protection
- **Third-party cookies**: Blocked by default (cookies set by sites other than the one you are currently visiting, often used for tracking).
- **Cross-site tracking**: Actively prevented (techniques websites use to track your activity across different, unrelated sites).
- **Fingerprinting protection**: Enabled (helps prevent sites from creating a unique "fingerprint" of your browser based on its configuration, which can be used for tracking even without cookies).
- **Referrer policy**: Strict (limits the information sent to websites about where you came from).

### Network Privacy
- **DNS-over-HTTPS (DoH)**: Enabled with privacy-focused providers. This helps hide your DNS queries (the "phonebook" lookups for websites) from anyone listening on the network by encrypting them.
- **Safe Browsing**: Uses locally stored lists of known malicious websites (no sending of your browsing activity to Google's Safe Browsing service).
- **Preloading**: Disabled by default. Preloading can speed up browsing by guessing what you might click next and loading it in advance, but it can also send information about your browsing habits to websites you haven't explicitly visited.

### Storage
- **Local storage**: Cleared on exit (optional)
- **Cookies**: Session-only by default
- **Cache**: Automatically cleared
- **Downloads**: No cloud sync

## Removed Privacy Risks

### Google Services Integration
- ❌ Google Account sync
- ❌ Chrome sync
- ❌ Google API calls
- ❌ Google Safe Browsing
- ❌ Google spell checking
- ❌ Google location services

### AI and Machine Learning
HenSurf removes features that rely on AI and machine learning to analyze your behavior or data, such as:
- ❌ AI-powered suggestions (e.g., for search or shopping).
- ❌ Predictive text that learns from your typing.
- ❌ Smart autofill that tries to guess information beyond basic form filling.
- ❌ Behavioral analysis for targeted advertising or recommendations.
- ❌ Usage pattern learning by the browser.

### Telemetry and Analytics
As mentioned, HenSurf disables features that send data about your browser usage (telemetry) to any central server. This includes:
- ❌ Usage statistics (how often features are used).
- ❌ Performance metrics (how fast the browser is running on your device, sent to external servers).
- ❌ Feature usage tracking (which specific buttons or options you interact with).
- ❌ Error reporting (automatic submission of crash or error data, unless you explicitly enable basic, non-personal crash reports).
- ❌ A/B testing data (data used to test different versions of features on users).

## Data Storage

### Local Storage Only
- All user data stored locally on your device
- No cloud synchronization by default
- No remote backups
- User has full control over data location

### Data Encryption
- Passwords encrypted with system keychain
- Local storage encrypted at rest
- No plaintext storage of sensitive data

### Data Retention
- History: Configurable retention period
- Cookies: Session-only by default
- Cache: Automatically cleared
- Downloads: User-controlled

## Network Communications

### Outbound Connections
HenSurf only makes network connections for:
1. **Website requests** (user-initiated)
2. **Update checks** (can be disabled)
3. **DNS resolution** (via secure DNS)
4. **Extension updates** (if extensions installed)

### Blocked Connections
- ❌ Google analytics
- ❌ Telemetry servers
- ❌ Advertising networks
- ❌ Tracking services
- ❌ AI/ML services

## User Controls

### Privacy Settings
Users can control:
- Cookie policies
- JavaScript execution
- Image loading
- Location access
- Camera/microphone access
- Notification permissions

### Data Management
- Clear browsing data
- Export/import bookmarks
- Manage stored passwords
- Control download location
- Configure privacy levels

### Advanced Privacy
- Tor integration (planned)
- VPN compatibility
- Proxy support
- Custom DNS servers

## Extensions and Add-ons

### Extension Privacy
- Extensions run in isolated environments
- Permission system for data access
- No automatic extension installation
- User reviews extension permissions

### Recommended Extensions
- uBlock Origin (ad blocking)
- Privacy Badger (tracking protection)
- HTTPS Everywhere (secure connections)
- ClearURLs (remove tracking parameters)

## Comparison with Other Browsers

| Privacy Feature | HenSurf | Chrome | Safari | Firefox | Brave |
|-----------------|---------|--------|--------|---------|-------|
| No Telemetry | ✅ | ❌ | ⚠️ | ⚠️ | ⚠️ |
| No AI Data Collection | ✅ | ❌ | ❌ | ✅ | ✅ |
| No Google Services | ✅ | ❌ | ✅ | ✅ | ✅ |
| Default Ad Blocking | ⚠️ | ❌ | ⚠️ | ❌ | ✅ |
| Privacy-First Search | ✅ | ❌ | ⚠️ | ⚠️ | ✅ |
| Local Data Only | ✅ | ❌ | ⚠️ | ⚠️ | ⚠️ |
| Open Source | ✅ | ⚠️ | ❌ | ✅ | ✅ |

## Security Measures

### Code Security
- Regular security updates from Chromium upstream
- Removal of unnecessary attack surfaces
- Minimal external dependencies
- Code review for all changes

### Network Security
- **HTTPS-only mode available**: A setting to ensure you only connect to websites over an encrypted connection (HTTPS).
- **Certificate Transparency**: A system that helps detect fake or malicious website security certificates. HenSurf checks that website certificates are publicly logged, making it harder for attackers to impersonate websites.
- **HSTS enforcement (HTTP Strict Transport Security)**: A mechanism that forces browsers to only connect to websites using HTTPS, even if you type `http://` in the address bar. This helps prevent downgrade attacks.
- **Secure DNS by default**: As mentioned with DoH, your DNS lookups are encrypted.

### Sandboxing
Sandboxing is a critical security feature that isolates browser components and websites from each other and from your main computer system. This means if a website or a part of the browser is compromised, the damage is contained.
- **Process isolation**: Different parts of the browser (like tabs, extensions) run in separate processes. If one process crashes or is compromised, it's less likely to affect others.
- **Site isolation**: Each website is typically run in its own process, preventing malicious sites from accessing data from other open sites.
- **Extension sandboxing**: Extensions are run in a restricted environment with limited access to your system.
- **Plugin containment**: Plugins (if any were supported) would also run in a sandbox.

## Transparency

### Open Source
- **Full source code available**: Anyone can view, inspect, and study the source code of HenSurf to understand how it works and verify its privacy claims.
- **Build process documented**: The steps to compile HenSurf from its source code are public.
- **Reproducible builds**: This means that anyone should be able to compile the source code and get an identical, verifiable copy of the browser. This helps ensure that the distributed browser matches the public source code. (This is a goal, and may be complex to achieve perfectly for large projects like Chromium).
- **Community auditing encouraged**: We encourage developers and security researchers to examine our code and report any potential privacy or security issues.

### Regular Audits
- Privacy impact assessments
- Security code reviews
- Third-party audits (planned)
- Community feedback integration

## Legal Compliance

### GDPR Compliance
- No personal data processing
- No consent required (no data collection)
- Right to be forgotten (not applicable)
- Data portability (local data only)

### CCPA Compliance
- No sale of personal information
- No personal information collection
- No third-party sharing
- User control over all data

## Contact and Support

### Privacy Questions
For privacy-related questions:
- GitHub Issues (public)
- Email: privacy@h3nry.xyz (if available)
- Documentation: This privacy policy

### Security Issues
For security vulnerabilities:
- Private disclosure preferred
- Responsible disclosure timeline
- Credit for security researchers

## Updates to This Policy

### Change Process
- All changes documented in git history
- Major changes announced to users
- Backward compatibility maintained
- User notification for significant changes

### Version History
- v1.0: Initial privacy policy
- Future versions will be documented here

## Conclusion

HenSurf is committed to protecting your privacy through:
- **Minimal data collection**
- **Local-first architecture**
- **Transparent practices**
- **User control**
- **Open source development**

We believe privacy should be the default, not an option. HenSurf is designed to give you a fast, secure, and private browsing experience without compromising on functionality.

---

*Last updated: 2024*
*This policy applies to HenSurf Browser v1.0 and later*