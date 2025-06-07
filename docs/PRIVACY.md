# HenSurf Privacy Policy

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
❌ **Personal Information**: No collection of names, emails, or personal data
❌ **Usage Analytics**: No telemetry or usage statistics
❌ **Location Data**: No tracking of your physical location
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
- **Third-party cookies**: Blocked by default
- **Cross-site tracking**: Prevented
- **Fingerprinting protection**: Enabled
- **Referrer policy**: Strict

### Network Privacy
- **DNS-over-HTTPS**: Enabled with privacy-focused providers
- **Safe Browsing**: Local lists only (no Google Safe Browsing)
- **Preloading**: Disabled to prevent data leakage

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
- ❌ AI-powered suggestions
- ❌ Predictive text
- ❌ Smart autofill
- ❌ Behavioral analysis
- ❌ Usage pattern learning

### Telemetry and Analytics
- ❌ Usage statistics
- ❌ Performance metrics
- ❌ Feature usage tracking
- ❌ Error reporting (unless explicitly enabled)
- ❌ A/B testing data

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
| Open Source | ✅*| ⚠️ | ❌ | ✅ | ✅ |

## Security Measures

### Code Security
- Regular security updates from Chromium upstream
- Removal of unnecessary attack surfaces
- Minimal external dependencies
- Code review for all changes

### Network Security
- HTTPS-only mode available
- Certificate transparency
- HSTS enforcement
- Secure DNS by default

### Sandboxing
- Process isolation
- Site isolation
- Extension sandboxing
- Plugin containment

## Transparency

### Open Source*
- Full source code available
- Build process documented
- Reproducible builds
- Community auditing encouraged

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