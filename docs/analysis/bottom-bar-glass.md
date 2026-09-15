# Google Photos bottom bar glass

Enable `GoToHP > Appearance > Google Photos · Liquid Glass` on iOS 26+.
The option defaults to off. Google Photos 7.92.0 is the audited host; later
versions must pass the same method contracts and live view-hierarchy checks.
Both targets are validated before either is changed. Exported diagnostics include
`bottomBarGlass` with availability, attached-bar count and a skip reason.
`attached` reports view installation, not a verified rendering result.

The visible left navigation is a self-owned capsule: one `UIVisualEffectView`
(`UIGlassEffect`, capsule) sized from the tab top to the Search button's bottom
edge, with three plain `UIButton`s (Photos/Collections/Create) on top. No
`UITabBar` is used, so exactly one glass background exists by construction and
there is no Apple-owned background to hide. Google Photos' original
`PHSSegmentedControl` stays in its original `UIStackView` as the navigation
backend, but is made visually/accessibility-inactive while the pill mirrors its
selection. Tapping a pill button writes the same `selectedSegmentIndex`; the
audited 7.92.0 setter emits `UIControlEventValueChanged` itself, so Gunshot
must not emit a second event.

The visible search control is a separate sibling `UIButton` built from
`UIButtonConfiguration.glassButtonConfiguration`. It is not an arranged child
of the left `UITabBar` and forwards `TouchUpInside` to the untouched Google
`M3CButton`. The original segmented and search controls remain in Google's
stack, so disabling the feature only removes the two proxy controls and restores
their saved alpha/interactivity/accessibility state; native targets, gestures,
colors, shadows and Material state are never rewritten by the renderer.

Google Photos ships with
`UIDesignRequiresCompatibility=true`, which suppresses real Liquid Glass for the
whole process. When this option is enabled, Gunshot writes
`com.apple.SwiftUI.IgnoreSolariumOptOut=true` before `UIApplicationMain` on the
next launch so UIKit uses the iOS 26 design while keeping the host Info.plist
unchanged. Changing the option therefore requires one Google Photos restart.

7.92.0 static evidence (hashes and method ABIs: `objc/manifest.json` and indexes):

- `PHSTabBarController.createFloatingSearchButton` at `0x10005c46c` calls
  `phs_brandIconTonalRound`, assigns the search image/accessibility label, and
  registers a `TouchUpInside` target.
- `PHSSegmentedControl.numberOfSegments` is `q16@0:8`,
  `selectedSegmentIndex` is `q16@0:8`, and `setSelectedSegmentIndex:` is
  `v24@0:8q16` in the supplied 7.92.0 image.
- The 7.92.0 `setSelectedSegmentIndex:` implementation sends control event
  `0x1000` (`UIControlEventValueChanged`) after a changed selection.

The existing UIKit smoke keeps `UIDesignRequiresCompatibility=true`, pre-seeds the
same launch-time rollout override before `UIApplicationMain`, and then uses real
glass APIs with fake Photos classes. It is not an injected Google Photos device test. Device
validation must cover opt-in/out, tab selection, search, light/dark appearance,
rotation and returning from a backgrounded app. No additional build target or
workflow is required.

Apple API references:
- https://developer.apple.com/videos/play/wwdc2025/284/
- https://developer.apple.com/documentation/uikit/uibuttonconfiguration/glassbuttonconfiguration
