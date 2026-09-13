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

## Rendering boundary and settings jitter (second device report)

The next screenshot still showed the regular meter. The accompanying 9.7-second
recording shows the Appearance section repeatedly moving within the viewport;
it does not establish that the row is removed from the data source. `GSPanel`
unconditionally called `reloadData` after every two-second poll, invalidating its
self-sizing row estimates even when all response values were unchanged.

The settings fix compares snapshots/status before reloading, skips polls or
completions during dragging/tracking/deceleration, and preserves the first
visible row plus its pixel offset when a changed snapshot requires a reload.
Repeated identical error messages also avoid reloading. The UIKit fixture waits
through multiple real timer polls and then changes a response value, asserting
that the switch remains visible and its position is preserved.

Further binary analysis identifies a more direct display boundary:

| Image / address | Verified behavior |
| --- | --- |
| Framework `OGLGM2AccountSelectorViewController.cardSectionsWithData:`, `0x140f234` | Filters card data, then calls `+cardItemFromCardData:` for each displayed card at `0x140f2fc`. Both collapsible and non-collapsible controllers use this path. |
| Framework `OGLGM2AccountSelectorViewModelItemUtils +cardItemFromCardData:`, `0x1411620` | Checks `dataMode`, uses an `isKindOfClass:` check for native storage data, creates a native storage item and copies `storageState` unchanged at `0x14116a0`–`0x14116ac`, followed by counters, subtitle and callbacks. |

The previous exact `object_getClass` checks would reject a native data object
wrapped by a KVO subclass. This is reproducible in the Foundation fixture with a
real `NSKVONotifying_OGLAccountMenuStorageCardData` instance. No runtime diagnostic
JSON accompanied the screenshot, so the device's actual class and skipped path
are **not yet confirmed**.

## Current implementation boundary

The old Photos-source and Swift-aggregator hooks have been replaced with the
native **card-data-to-view-item converter** hook. It operates on the display
input regardless of which provider supplied it. Compatible subclasses are
accepted after checking all 18 getter/setter ABIs on their actual runtime class.
A fresh native model preserves counters, flags, callbacks and cached originals;
only its display state, title and subtitle change. Other card types pass through.

`OGLStringResources` supplies the native unlimited title. The native card's shared
title formatter receives that string for state 2, keeping sizing and rendering
consistent. A passive `updateWithItem:` observer records the state reaching the
native storage cell; it does not change the item or layout. The original converter
and cell implementation always run. No data-source, quota, upload or feature-flag
hook is installed by this display option.

Diagnostic exports identify `implementation: native-card-renderer-v3` and include
converter, projection, title and cell counts; mapped/rendered storage states;
resource readiness; and at most 16 runtime class names per category. These are
class names, not object descriptions: no account, title text, storage amount,
token or media value is recorded. This distinguishes source-path assumptions from
what actually reached the renderer on the user's device.

## Validation and remaining device check

`tests/unlimited_storage.m` runs with neither of the former source classes present.
It exercises the renderer converter, real KVO subclass, cached-source restoration,
callback/scalar preservation, late resources, unrelated/nil data, inherited-method
isolation, passive cell observation and ABI rejection. CI also runs the actual
UIKit stationary-polling fixture and builds all three package schemes.

Fixtures do not run Google's proprietary UI. On device, reopen the profile menu
after toggling, check original/unlimited presentation and native actions, then
export diagnostics if it remains unchanged. The new counters and observed classes
are required to establish the remaining runtime cause rather than infer it from
the screenshot alone.
