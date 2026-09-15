# Google Photos bottom bar glass

Enable `GoToHP > Appearance > Google Photos · Liquid Glass` on iOS 26+.
The option defaults to off. Google Photos 7.92.0 is the audited host; later
versions must pass the same method contracts and live view-hierarchy checks.
Both targets are validated before either is changed. Exported diagnostics include
`bottomBarGlass` with availability, attached-bar count and a skip reason.
`attached` reports view installation, not a verified rendering result.

The visible left navigation is a real UIKit `UITabBar`, with its standard iOS 26
appearance left intact. Gunshot deliberately does not draw a replacement
`UIGlassEffect` capsule, clear the tab bar background, or hide UIKit's internal
background views. UIKit therefore owns the outer floating glass, the selected-tab
lens and the pressed/held interaction/refraction instead of approximating those
states with plain buttons.

Google Photos' original `PHSSegmentedControl` stays in its original `UIStackView`
as the navigation backend, but is made visually/accessibility-inactive while the
UIKit bar mirrors its selection. Selecting a `UITabBarItem` writes the same
`selectedSegmentIndex`. On-device 7.92.0 builds do not all agree with the static
analysis about whether that setter emits `UIControlEventValueChanged`, so
`GSPhotosTabBarEventBridge.m` observes the setter call and emits the event only
when the host did not. A changed tab therefore produces exactly one navigation
event on either behavior; tapping the already-selected tab produces none.

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
- Static analysis suggested that `setSelectedSegmentIndex:` emits control event
  `0x1000` (`UIControlEventValueChanged`) after a changed selection. Device
  validation found builds where only the index changed, which is why the runtime
  bridge measures the actual behavior instead of relying on either assumption.

The existing UIKit smoke keeps `UIDesignRequiresCompatibility=true`, pre-seeds the
same launch-time rollout override before `UIApplicationMain`, and then uses real
iOS 26 `UITabBar`/glass button APIs with fake Photos classes. It is not an
injected Google Photos device test. Device validation must cover opt-in/out, tab
selection, Search, light/dark appearance, rotation, press-and-hold interaction
and returning from a backgrounded app. No additional build target or workflow is
required.

Apple API references:
- https://developer.apple.com/videos/play/wwdc2025/284/
- https://developer.apple.com/documentation/uikit/uitabbar
- https://developer.apple.com/documentation/uikit/uibuttonconfiguration/glassbuttonconfiguration
