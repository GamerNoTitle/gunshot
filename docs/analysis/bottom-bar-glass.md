# Google Photos bottom bar glass

Enable `GoToHP > Appearance > Google Photos · Liquid Glass` on iOS 26+.
The option defaults to off. Google Photos 7.92.0 is the audited host; later
versions must pass the same method contracts and live view-hierarchy checks.
Both targets are validated before either is changed. Exported diagnostics include
`bottomBarGlass` with availability, attached-bar count and a skip reason.
`attached` reports view installation, not a verified rendering result.

The visible left navigation is now owned by a real UIKit `UITabBarController`
rather than a standalone `UITabBar`. This distinction matters on iOS 26: the
controller is the system component that configures the floating Liquid Glass tab
presentation. A standalone `UITabBar` can show the lens interaction while still
using the much thinner compact bar geometry seen in the broken device build.
Gunshot keeps the controller in `UITabBarControllerModeTabBar`, embeds its view
as a child of Google Photos' `PHSTabBarController`, and lets UIKit own the outer
floating platter, selected-tab lens and pressed/held refraction. After the
controller performs its system layout, the controller-owned `UITabBar` is sized
to the Google Photos floating-tab viewport so its visible pill reaches the same
bottom edge as the Search button without drawing a second glass layer.

Google Photos' original `PHSSegmentedControl` stays in its original `UIStackView`
as the navigation backend, but is made visually/accessibility-inactive while the
UIKit controller mirrors its selection. `GSPhotosGlassPair` is a
`UITabBarControllerDelegate`; selecting a tab writes the corresponding
`selectedSegmentIndex`. On-device 7.92.0 builds do not all agree with the static
analysis about whether that setter emits `UIControlEventValueChanged`, so
`GSPhotosTabBarEventBridge.m` observes the setter call and emits the event only
when the host did not. A changed tab therefore produces exactly one navigation
event on either behavior; tapping the already-selected tab produces none.

The visible search control is a separate sibling `UIButton` built from
`UIButtonConfiguration.glassButtonConfiguration` and forwards `TouchUpInside`
to the untouched Google `M3CButton`. The original segmented and search controls
remain in Google's stack, so disabling the feature removes the child tab
controller and Search proxy and restores their saved
alpha/interactivity/accessibility state; native targets, gestures, colors,
shadows and Material state are never rewritten by the renderer.

Google Photos ships with `UIDesignRequiresCompatibility=true`, which suppresses
real Liquid Glass for the whole process. When this option is enabled, Gunshot
writes `com.apple.SwiftUI.IgnoreSolariumOptOut=true` before `UIApplicationMain`
on the next launch so UIKit uses the iOS 26 design while keeping the host
Info.plist unchanged. Changing the option therefore requires one Google Photos
restart.

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

The existing UIKit smoke keeps `UIDesignRequiresCompatibility=true`, pre-seeds
the same launch-time rollout override before `UIApplicationMain`, and then uses
a real child `UITabBarController` plus the iOS 26 glass button API with fake
Photos classes. It is not an injected Google Photos device test. Device
validation must cover opt-in/out, tab selection, Search, light/dark appearance,
rotation, press-and-hold interaction and returning from a backgrounded app. No
additional build target or workflow is required.

Apple API references:
- https://developer.apple.com/videos/play/wwdc2025/284/
- https://developer.apple.com/documentation/uikit/uitabbarcontroller
- https://developer.apple.com/documentation/uikit/uibuttonconfiguration/glassbuttonconfiguration
