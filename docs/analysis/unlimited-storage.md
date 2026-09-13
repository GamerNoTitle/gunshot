# Native unlimited storage display (Google Photos iOS 7.92.0)

GoToHP settings → Appearance → **Show unlimited storage** is enabled by default.
The choice is stored in the host app's preferences (`GSShowUnlimitedStorage`). An
absent key means on; an explicit false is preserved across launches. Reopen the
profile menu after changing it. The control is independent of account connection,
upload settings and the queue. English and Japanese settings labels are included.

This is a **display preference**. It does not grant an account benefit, alter
Google's storage accounting, or select upload quality. Turn it off to see the
unmodified account storage card. Other app versions or incompatible private APIs
leave the native UI unchanged and show the control as unavailable.

## Evidence from the supplied IPA

Addresses below are static unslid ARM64 addresses, not runtime hook offsets.
The binaries and their hashes are indexed in [objc/manifest.json](objc/manifest.json).

| Image / location | Verified behavior |
| --- | --- |
| Main `PHSMyAccountMenuDataSource.storageCardData`, `0x1000b63b4` | Returns nil when the card is hidden; otherwise allocates a fresh `OGLAccountMenuStorageCardData`, copies quota values and attaches native action callbacks. |
| Main `0x1000b642c`–`0x1000b6568` | Reads `GMUQuota.isUnlimited` and `unlimitedReason`. Reason 1 maps to storage state 2; other unlimited reasons map to state 3. |
| Framework `OGLAccountSelectorStorageCardCell.updateWithItem:`, `0x1438908` | States 2 and 3 hide the storage progress meter and its information label. Layout, colors, action chips and icons remain native. |
| Framework `+subtitleTextWithStorageItem:`, `0x14397f0` | State 2 requests OneGoogle string ID `0x82` (unlimited subtitle). |
| Framework `+titleTextWithStorageItem:`, `0x143942c` | State 2 still follows the regular/percentage title branch in this build. Merely setting `storageState` does **not** guarantee the requested unlimited title. |
| Framework string table `0x76062d0` / `0x76062d8` | References `OneGoogleStorageCardUnlimitedTitle` / `OneGoogleStorageCardUnlimitedSubtitle`. |
| Framework `OneGoogle.bundle/{ja,en}.lproj/OneGoogle.strings` | Native title: `無制限ストレージ` / `Unlimited storage`; subtitle: `無制限` / `Unlimited`. |

The class methods above are separately inspected through metaclass metadata;
the existing compressed method indices list instance methods only.

## Implementation boundary

`UI/GSUnlimitedStorage.m` hooks only the Photos menu presentation source and the
native card's title formatter. The returned, freshly allocated display model uses
state 2 and the original OneGoogle title resource. The native formatter receives
that same resource for state-2 items, so sizing and rendering use the same text.
The native cell continues to provide layout, cloud icon, localization, theme and
accessibility. No overlay view or global `GMUQuota.isUnlimited` override is used.

Used/total storage values and native callbacks are retained. No account token,
quota response, upload policy, device profile or media metadata is changed.
Disabling the preference passes through the original source and formatter on
subsequent menu builds. An already presented card is refreshed by reopening the
menu, avoiding private reload calls during sheet transitions.

Installation requires executable `GooglePhotos`, version `7.92.0`, exact method
encodings and the native string resource. Instance type checks protect the hooked
paths. No method implementation is replaced if validation fails. The feature is
packaged for jailed, rootless and rootful builds; there is no extra dependency.

## Validation

`tests/unlimited_storage.m` exercises default-on, persistent opt-out/re-enable,
original callbacks and counters, fresh menu restoration, nil/unexpected model,
wrong host/version, missing resources and incompatible ABI. The UIKit settings
fixture exercises the actual switch while account operations are busy. CI builds
all three packages. These fixtures do not execute Google's proprietary UI;
final native layout and interactions still require device validation.

Device checks: open the profile menu with the default on; confirm the native
unlimited title and cloud card, toggle off and reopen to restore quota text,
re-enable and relaunch; repeat with dark mode, larger text and account switching.
Confirm native storage actions still open their original destinations and upload
quality/storage accounting remain unchanged.
