# Link-only SDK declarations

Apple's public iPhoneOS SDK omits the private Preferences framework stub.
`Preferences.framework/Preferences.tbd` declares only the Objective-C classes
and inherited ivar used by our preference bundle. No Apple implementation or
binary is included. The install name targets the actual system framework at
runtime. Headers come from the pinned Theos headers submodule.


`Shared/GSXPC.h` provides the C ABI declarations used by jailbreak-only discovery
for SDKs that omit XPC headers. It contains no implementation. Object ownership
is explicit in C, and Mach-port/audit SPI declarations follow the maintained
[WebKit XPC SPI header](https://github.com/WebKit/WebKit/blob/main/Source/WTF/wtf/spi/darwin/XPCSPI.h).
The CI discovery fixture exercises the same declarations against macOS libxpc.
