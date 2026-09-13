# Google Photos 7.20.2 compatibility audit

The supplied **Google Photos 7.20.2**, build **7.20.738660793**, and **7.92.0** are IPA-audited reference versions. Adapters are now selected per feature from the actual classes, selectors and exact Objective-C signatures, without a version-number gate. Authentication, completion callbacks, storage UI and quality UI can independently use different API generations. Device validation is still required; binary audits and mocked contracts do not establish successful authentication or uploads against Google's servers.

## Input and OS requirements

The supplied IPA contains `GooglePhotos` and `Frameworks/ModuleFramework.framework/ModuleFramework`, both decrypted (`cryptid = 0`), thin arm64 images. Their `LC_BUILD_VERSION` declares **iOS 16.1**, SDK 17.5. Although the top-level Info.plist says `MinimumOSVersion = 10.0`, that does **not** make this binary usable on iOS 10–15. The tweak's own deployment target is separate from the host application's minimum OS.

The main image yielded 6,780 classes / 64,988 instance methods; ModuleFramework yielded 15,623 / 86,308. [The scoped contract manifest](objc/7.20.2-contracts.json) records SHA-256 hashes and the selectors, encodings, and static addresses relevant to this adapter. It is not a full decompilation. The IPA and executable bytes are not distributed in this repository.

## Audited differences

| Integration | 7.20.2 | 7.92.0 |
| --- | --- | --- |
| Native account | `PHSAccountManagerImpl.ssoService` → `SSOService.authorizationForIdentity:scopes:` | `photosSSOService` → `fetcherAuthorizerForAccountID:scopes:` |
| Authorization callback | `authorizeRequest:completionHandler:` (`v32@0:8@16@?24`) | Same ABI |
| Asset completion | `didCompleteWithSuccess:resultantMediaItem:errorCode:` (`v36@0:8B16@20q28`) | `…error:` with object argument (`v36@0:8B16@20@28`) |
| Live Photo completion | `didCompleteWithError:resultantMediaItem:` | Same ABI |
| Unlimited card | Model `storageState`, native UIKit cell title; **no model `title` getter** | Model `storageState` + `title`, including Swift/Bento reads |
| Unlimited localized resource | `OneGoogleStorageCardUnlimitedTitle`, ID **0x79** | Same key, ID **0x81** |
| Backup detail display | `modelForBackedupStatus` → inherited content-model factory | `getBackupStatusModelData` → `PHSOneUpInfoPanelBackupStatusData` |
| Native library refresh | `PHSUserItemsSynchronizer.fetchData` / `fetchDataSoft` | Same ABI |
| Settings/menu and manual action | Existing audited custom-section/action and `backupLocalAssets:` signatures | Same ABI |

### Authentication

`SSOService.authorizationForIdentity:scopes:` at ModuleFramework `0x14a804` uses the identity's user ID and sorted scopes for its authorization cache and constructs `SSOAuthorizationImpl` with `initWithSSOIdentity:scopes:logger:`. The adapter passes the currently viewed account's valid `_ssoIdentity` and `photos.native` scope. Native SSO retains ownership of refresh and Keychain access. Account matching before/after completion, the background-thread wait, timeout, and token redaction remain in place.

**Sign in before injecting.** First open Google Photos without the tweak and complete Google login; then install the tweak or update to the injected IPA while preserving the same app data and signing identity. Injection can cause Google to reject login. An app downgrade may also fail to read newer app data; this change does not provide a database migration or guarantee that a 7.92.0 session survives a downgrade.

### Backup handoff and completion

The same explicit action and native request families provide manual/automatic handoff. In jailed mode the native request waits for the Go queue and then runs its original fingerprint/server lookup. Success is only observed from native reconciliation; the adapter does not manufacture a successful native media item or write native backup flags.

The legacy base completion at `0x10c3318` constructs `NSError` in `com.google.photos.upload.error.asset` via `0x10ca478` on failure, forwarding the integer error code. The BOOL success argument controls success independently of that integer. Hook blocks and calls therefore use **NSInteger**, not an Objective-C object, for this version. Live Photo keeps its separate object-error callback. Diagnostics also use the correct signature and report the actual host version.

7.20.2 has no audited 7.92.0 Swift `ScottyUploadServiceImpl` class. Its optional probes may be unmatched. The shared `GMUUploadRequest.startFetcher` and `GMUUploadMediaRequest.startCNDEUpload` payload guards remain active. Edited Live Photo data is handed to a native data-upload request in `startEditedBytesUploadWithData:isPhotoUpload:`; this audit does not establish complete locked-folder/edited-media coverage. See [coverage boundaries](../full-upload-replacement.md). As before, complete native request interception is a jailed feature; jailbreak builds retain the existing explicit-action/daemon behavior.

### Native unlimited display

`PHSMyAccountMenuDataSource.storageCardData` at main `0x10036adc4` assigns native state **2** for unlimited reason 1. `OGLStringResources.stringForID:` at ModuleFramework `0x12d10c` indexes the resource table at `0x6f285b0`; index **0x79** resolves to `OneGoogleStorageCardUnlimitedTitle`. The native UIKit cell already has the relevant layout/state path.

Both adapters now resolve `OGLBundle.oneGoogleResourceBundle` (class method `@16@0:8`; legacy address `0x12d18c`, modern reference address `0x17bedc4`) and load the key `OneGoogleStorageCardUnlimitedTitle` from the `OneGoogle` table, without calling `stringForID:`. This avoids using a stale numeric index on a later release. The legacy adapter requires the cell's exact ABI, changes the display getter, and supplies the native localized title. It never adds the absent model `title` getter. On/off remains available, default on. Missing resources retain the native display. Encoding suppresses display overrides so saved quota/state values stay native. This changes only the card, not the account's actual quota or upload policy.

### Original-quality label and refresh

At main `0x10082c084`, `modelForBackedupStatus` builds the title, quality subtitle, native icon, and action through `contentViewModelWithTitle:subtitle:subtitleContainsHTML:image:`. The adapter overrides this inherited factory **on the details subclass only**, scoped to that controller's backup-status call, with scope restored even on exceptions. It preserves the original factory, title, image, and native action setup.

Only `isBackedUp`, `hasOriginalBytes == Yes (1)`, non-partial backup, and storage policy Standard (1) permit the quality subtitle correction. Unknown/No/Maybe and partial backups retain the native label. The app's normal account-bound synchronizer performs refresh; neither quota counters nor the media database are edited.

## Validation

The macOS CI runs both 7.92.0 and 7.20.2 contracts. Legacy fixtures omit the new SSO factory, new asset-completion selector, new detail-model class, storage title getter, and Swift upload service. They exercise native account switching, silent manual/automatic routing, reconciliation failure without native payload fallback, integer completion preservation, quality evidence checks, account-bound refresh, settings actions, and native unlimited on/off/archive behavior. CI also builds rootless, rootful, and jailed packages and runs the existing UIKit settings smoke test.

Real-device checks still needed on 7.20.2: login-first installation, native account refresh, settings/menu tap, unlimited display on/off after reopening the menu, original JPEG/HEIC/video/Live Photo upload, manual and automatic handoff, completion refresh without relaunch, cancellation/network loss, and upgrade/downgrade behavior. Jailed uploads require the app to remain active; this is not a background-execution entitlement change.

## Automatic API detection

The host executable must be GooglePhotos. Version metadata only informs the `auditedHostVersion` diagnostic field; missing, unfamiliar, older and future version strings do not disable compatible APIs. A matching modern API is preferred; a matching legacy API can be used independently by each feature. Missing or incompatible signatures disable the affected path rather than guessing an argument type. Shared menu and routing hooks retain their own ABI checks.

CI runs both API shapes, mixed completion classes and malformed signatures, and reruns modern and legacy contracts under unrelated version metadata. These are simulated API contracts, not device verification of uninspected app releases. Private API behavior can still change without a signature change.

## Jailbreak daemon lookup

The 2026-09-13 17:55 crash reports `EXC_GUARD / SEND_INVALID_REPLY` in RocketBootstrap called by `GSRequest`. Choicy isolation did not eliminate this path. The client now uses a locally owned reply port marked `MPO_REPLY_PORT` on iOS 16+ for the broker lookup and daemon RPC. It first tries direct and redirected launchd lookup, then the existing RocketBootstrap broker with bounded waits and validated descriptors. Client binaries no longer link RocketBootstrap; the daemon still uses it to unlock the service. The broker's access policy and daemon audit-token authorization are preserved. Gunshot does not install global Mach hooks or change process guard settings. The scoped libSandy access adapter described below is used when the app sandbox denies lookup.

The transport is based on the published [RocketBootstrap lookup protocol](https://github.com/rpetrich/RocketBootstrap/blob/master/rocketbootstrap_internal.h). Apple's [reply-port validation](https://github.com/apple-oss-distributions/xnu/blob/xnu-8792.61.2/osfmk/ipc/ipc_right.c) requires a reply-designated port for destinations enforcing reply semantics. The log identifies the failing path, but does not expose the broker's kernel port flags; this remains a device-validation target. A macOS test performs actual Mach exchanges against a reply-enforcing endpoint and checks success, denied/malformed responses, timeout and port cleanup.

If Google Photos crashes, use Choicy to enable only Gunshot for Google Photos.

### Connected process versus reachable service

A subsequent device report shows `gotohpd` running in `user/501`, with its Mach service active and no prior exit. This excludes a missing executable or an exited daemon at the time of that report, but does not prove that initialization has completed or that the app/broker can resolve and use the endpoint. A user-domain service listing alone does not establish a namespace mismatch.

The client now acquires the calling task's current bootstrap port for each lookup and releases that right, rather than relying on the process-global cached bootstrap port. On failure, the settings status includes the failing stage and hexadecimal return code. Export diagnostics includes an `ipc` snapshot with per-request lookup results, broker response classification and transport reachability. It contains no request/response payloads, credentials, account names or raw Mach port numbers. A valid empty broker response is distinguished from a malformed reply, timeout or missing broker. This adds the evidence needed to diagnose the remaining device connection failure; it does not claim that the device failure is resolved.

The daemon's Mach receive loop also previously occupied the main thread indefinitely after `rocketbootstrap_unlock`. RocketBootstrap [registers a Darwin notification observer and schedules run-loop work](https://github.com/rpetrich/RocketBootstrap/blob/master/Tweak.x) to restore unlocked names when its broker restarts. The daemon now serves requests serially on a dedicated queue while keeping its main CFRunLoop active. A native test verifies that a Darwin notification reaches the main thread while the service worker is blocked. This repairs a registration-recovery defect; the supplied launchctl listing cannot establish whether a broker restart caused this particular failure. Request audit-token authorization and the wire protocol are unchanged.


### Confirmed sandbox lookup denial

The next exported diagnostic reports `lookup.bootstrap = 0` and **1100 (`0x44c`) for direct, redirected and broker lookup**. Apple's [bootstrap definitions](https://github.com/apple-oss-distributions/launchd/blob/main/liblaunch/bootstrap.h) identify this as `BOOTSTRAP_NOT_PRIVILEGED`, not `BOOTSTRAP_UNKNOWN_SERVICE` (1102). The broker request has not been sent at that point. Together with the running service listing, this identifies a client lookup authorization failure; changing reply-port flags or restarting a healthy daemon does not grant access.

On direct lookup denial, the jailbreak client now calls `libSandy_applyProfile("dev.tqmane.gunshot.ipc")` and retries its own service. The [libSandy profile mechanism](https://github.com/opa334/libSandy#sandbox-profiles-implemented-in-libsandy-explained) restricts grants by process signing identifier. The root-owned profile is included in both jailbreak packages and allows only `com.google.photos`, `com.apple.mobileslideshow` and `com.apple.Preferences` to request the `com.apple.app-sandbox.mach` extension for the upload and discovery services (`dev.tqmane.gunshot.service` and `dev.tqmane.gunshot.discovery`). It grants no filesystem access, wildcard identities or access to other services. Daemon audit-token/signing-ID/path authorization remains mandatory after lookup.

libSandy 1.1.6 or later is a declared jailbreak package dependency, loaded from the Theos install prefix; it is not copied into or required by jailed packages. Its [iOS 16 adapter](https://github.com/opa334/libSandy/blob/main/libSandy.c) redirects only profile-authorized lookup names (plus its own provider) if the host sandbox cannot consume Mach extensions. Gunshot retains the library for the process lifetime and does not cache failed application attempts. If direct lookup already works, this path is not invoked.

Diagnostics include `sandbox.profile` (-1: library missing/load failed; -2: API missing; 1: provider unavailable; 2: profile restricted; 0: profile returned extensions) and, after successful application, `lookup.authorized`. A successful profile call alone never marks IPC reachable: lookup and daemon RPC must still succeed. When profile application fails and the fallback lookups are also denied, settings reports the profile failure instead of hiding it behind a generic broker error. These codes contain no extension tokens or account data.

Native fixtures cover denied lookup followed by profile application and a real Mach RPC, denied lookup despite successful profile application, dependency/provider/restriction failures, retry recovery and reply-right cleanup. Package checks validate the exact profile, permissions, dependency and library path for each jailbreak scheme; jailed packages remain independent. These tests do not exercise the physical device's sandbox or sandyd service, so device confirmation remains required.


### Profile success followed by denied raw lookup

The next diagnostic has `sandbox.profile = 0`, but `lookup.authorized`, `lookup.redirected` and `lookup.broker` still return 1100. This confirms that libSandy is loaded and has returned extensions; it does **not** confirm that the raw bootstrap lookup is authorized. Reinstalling the same dependency cannot address this result. The [libSandy client](https://github.com/opa334/libSandy/blob/main/libSandy.m) reports success when it receives tokens and, when necessary, enables an [adapter for XPC lookup requests](https://github.com/opa334/libSandy/blob/main/libSandy.c). Gunshot's raw bootstrap retry did not establish a working route on this device.

The jailbreak daemon now publishes a small XPC discovery service alongside its existing Mach upload service. After successful profile application and an unsuccessful raw lookup, the client connects using `xpc_connection_create_mach_service` with no bootstrap preflight. This lets libxpc perform the lookup through the API family handled by libSandy. The discovery service returns a copy of the daemon's Mach send right to authorized callers; upload/account operations continue through the existing bounded JSON/Mach transport. The discovery endpoint accepts a protocol version, not an arbitrary service name, filesystem path, account token or upload request.

Discovery checks the peer's kernel audit token with the same UID, signing-ID and executable-path authorization as upload RPC. The returned port does not bypass the original per-request authorization. The libSandy profile contains only these two GoToHP services and the same three allowed signing IDs. Service, queue and send-right lifetime follow the daemon; the client bounds discovery to five seconds and safely discards late replies. The `discovery.*` diagnostic stages distinguish connection failure, rejection, invalid response/port and timeout before the normal request stages.

The native test runs a real anonymous XPC listener (test-only) and checks port transfer, peer audit identity, denied/invalid requests, timeout, late replies and send-right cleanup. An IPC fixture reproduces this report's exact sequence (profile success → raw lookup denied → discovery → Mach RPC). Package checks require both launchd services and both narrowly scoped profile entries. These tests cover protocol and lifetime behavior; they cannot confirm the jailbreak's on-device libSandy lookup adapter. Device validation remains necessary.
