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

## Self-managed card path (fix after PR #13)

The device screenshot after PR #13 still showed `43% of 15 GB used`. The earlier
fixture covered only the Photos-owned source, so its passing result did not cover
the self-managed card path. Further disassembly confirms:

| Image / location | Verified behavior |
| --- | --- |
| Main `PHSMyAccountMenuDataSource.accountMenuCardData`, `0x1000b3aa4` | Adds the legacy backup and storage cards to an array. |
| Framework `OGLAggregatorCardDataSourceImpl` internal getter, `0x13713c8` | Starts with its internal provider's cards. When merging the Photos source, the type check at `0x1371500`–`0x137151c` **excludes OGLAccountMenuStorageCardData** from that source. The class reference is `0x7e1bbd8`. |
| Framework aggregator `accountMenuCardData`, `0x13715ac` | Objective-C bridge returns the final card array after the filter/merge. |
| Framework collapsible/non-collapsible menu view-model builders | Read `accountMenuCardData` through Objective-C dispatch at `0x12f5578`, `0x12f56a8`, `0x12f6c54`. |
| Framework `OGLStringResources.stringForID:`, `0x17b33a0` | Reads the resource table at `0x7605ec8`; index `0x81` references the unlimited title. Uses Google's `oneGoogleResourceBundle` resolver. The argument ABI is **int** (`@20@0:8i16`). |

The screenshot alone does not prove which runtime gate/path fired. The excluded
legacy card is a confirmed coverage gap explaining why changing only the Photos
source cannot cover this mode. The fix also removes the assumption that resources
must resolve through `bundleForClass:` at dylib initialization.

## Implementation boundary

`UI/GSUnlimitedStorage.m` now handles both the Photos source and the **final
aggregated array**, using a fresh native storage-card model for presentation.
All 18 stored properties are copied through checked, typed getters/setters before
changing state, title and subtitle. Cached originals, used/total counters, native
callbacks and every non-storage card are preserved; disabling the preference
returns the original source objects/array on the next menu build.

The native OneGoogle resource provider supplies the title. Resource loading is
retried during presentation, so an early unresolved resource cannot permanently
prevent installation. The legacy card title formatter still uses this title for
both native sizing and rendering. Layout, icons, localization, theme and
accessibility remain native. There is no overlay, feature-flag override or global
`GMUQuota.isUnlimited` override.

No account token, quota response, upload policy, device profile or media metadata
is changed. Reopen the menu after a setting change; the fix avoids private reload
calls during sheet transitions. The host version, all 18 field ABIs, both source
ABIs, resource provider ABI and legacy formatter ABI must match before any hook
is installed. Inherited methods get a local override rather than changing their
superclass implementation.

Diagnostic exports include `unlimitedStorage`: installation status, matched
paths, resource readiness and invocation/projection/failure counts only. No
account, title text, storage amounts, tokens or media data are recorded there.
This lets device results distinguish an uninstalled hook from an unused source.

## Validation

`tests/unlimited_storage.m` exercises a self-managed aggregate that never calls
the legacy source, cached-array restoration on opt-out, account changes and
server refresh, preservation of all three callbacks and scalar flags, late native
resources, nil/unexpected models, inherited-method isolation, wrong host/version
and incompatible ABI. It also checks the diagnostic field allowlist. The UIKit settings
fixture exercises the actual switch while account operations are busy. CI builds
all three packages. These fixtures do not execute Google's proprietary UI;
final native layout and interactions still require device validation.

Device checks: open the profile menu with the default on; confirm the native
unlimited title and cloud card, toggle off and reopen to restore quota text,
re-enable and relaunch; repeat with dark mode, larger text and account switching.
Confirm native storage actions still open their original destinations and upload
quality/storage accounting remain unchanged.
