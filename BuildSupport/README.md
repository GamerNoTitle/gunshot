# Link-only SDK declarations

Apple's public iPhoneOS SDK omits the private Preferences framework stub.
`Preferences.framework/Preferences.tbd` declares only the Objective-C classes
and inherited ivar used by our preference bundle. No Apple implementation or
binary is included. The install name targets the actual system framework at
runtime. Headers come from the pinned Theos headers submodule.
