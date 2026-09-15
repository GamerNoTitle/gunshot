# Google Photos bottom bar (7.92.0)

`Appearance > Google Photos · Liquid Glass` is opt-in (default off), iOS 26+ and
Photos 7.92.0+. It styles the existing floating tab pill and search button, not
all application UI. No new package, build target or separate CI workflow.

Static evidence from the supplied decrypted IPA (not redistributed):

- Main SHA-256: `0395330b2170256ec4ca240afad8672d0e0ab19e03acc10e74e04bce8b73858d`.
- Framework SHA-256: `be2629c366b134ae63a80023a77165b30866e890a398a17eb423af80526983d6`.
- `PHSTabBarController` creates `PHSSegmentedControl` at `0x10005a868` and
  `M3CButton` at `0x10005c46c`, inside `floatingBottomTabBar` (a UIStackView).
- The pill's native hierarchy is control > PHSShadowView > content UIView
  (UIAccessibilityTraitTabBar) > selection balloon/segments. Swift ivar offsets
  are not used. Only background/opaque/elevation state is changed and restored.
- `M3CButton.setGlassType:` at `0x1ba86bc` updates its existing material view;
  `M3CMaterialGlassEffectView.updateGlassEffect` at `0x1bace58` maps type 2 to
  public `UIGlassEffectStyleRegular` (0), type 1 to clear (1).
- The IPA sets `UIDesignRequiresCompatibility = true`. Scoped `isGlassEnabled`
  and `isGlass` overrides apply only to the marked search button/material view.
  Global M3CLiquidGlass availability and the host Info.plist remain unchanged.

Existing settings UIKit smoke covers opt-in/out, legacy OS/version rejection,
unchanged actions/selection, resize/theme restoration, multiple controllers,
and unknown-layout no-op. Static metadata and fixtures are not a real-device
Google Photos rendering test; future versions still require device validation.
