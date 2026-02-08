# sheap – Privacy (Template)

> TODO: Final review with legal/privacy requirements before publishing.

## We do not sell personal data

We do **not** sell personal data (e.g. email, UID, device identifiers).

If we ever introduce monetization based on data, it will be limited to **aggregated/anonymized** insights and will require explicit user consent where legally required.

## Data we process

### Account (Firebase Authentication)
- **Email address**
- **User ID (UID)**
- **Email verification state**

Purpose: login, account security, password reset.

### App usage / diagnostics (optional)
The app contains an **opt-in** toggle for “Analytics & Crash-Reports”.

If enabled, we may process:
- crash logs / diagnostics (to improve stability)
- basic usage events (to improve features)

TODO: Confirm the exact Firebase products enabled in production (Analytics / Crashlytics / Performance).

### Local storage (on device)
We store user settings and preferences locally on your device (e.g. onboarding profile, favorites),
plus an optional non-personal recipe cache for performance.

You can request export/deletion via the in-app privacy settings.

## Data sharing
- Firebase (Google) as infrastructure provider for authentication (and potentially other Firebase services).

## Data retention & deletion
- You can delete local app data via the in-app privacy settings.
- TODO: Add account deletion flow (Firebase user delete) if required for launch.

## Contact
TODO: Add support email + address/owner.


