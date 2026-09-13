# iOS 16.7.9 launch crash: Lynx / Cephei / RocketBootstrap

## What the supplied report establishes

The supplied `GooglePhotos-2026-09-13-174126.ips` describes Google Photos **7.20.2**, build **7.20.738660793**, on **iPhone10,1 / iOS 16.7.9**. This is a jailbreak/rootless installation: the loaded GoToHP image is `Gunshot.dylib`, not `GunshotJailed.dylib`. The full report is not committed because it contains device/application identifiers and private paths.

The terminating exception is **EXC_GUARD**, subtype **GUARD_TYPE_MACH_PORT**, violation **SEND_INVALID_REPLY**, with SIGKILL. Reading the main-thread frames from caller toward the trap:

| Image | Image-relative offset / symbol |
| --- | --- |
| ElleKit `libinjector.dylib` | `injection_init`, loading a tweak through `dlopen` |
| dyld | `findAndRunAllInitializers` |
| `Lynx.dylib` | `0x8c30` |
| `Cephei` | `0xb4fc`, `0xb194`, `0xab18`, `0x9908`, `0xaf14`, `0xbf54`, `0xbd4c`, `0xc294` |
| `librocketbootstrap.dylib` | `0x5b5c` |
| `libsystem_kernel.dylib` | `mach_msg` → `mach_msg_overwrite` → `mach_msg2_internal` → `mach_msg2_trap` |

`Gunshot.dylib` is loaded, but has **no frame in the terminating call chain**. The report identifies a failure during Lynx initialization via Cephei/RocketBootstrap, not an unrecognized Google Photos selector or a GoToHP upload callback. That does not prove GoToHP's presence cannot affect dependency loading: jailbreak GoToHP currently links RocketBootstrap for its daemon IPC. The precise external-library defect and which package build resolves it cannot be established from this one report.

## Device isolation

1. Keep GoToHP installed, but exclude **Lynx only from Google Photos** using the installed per-app tweak filter. Fully terminate and reopen Google Photos. This is the narrowest first check because the terminating initializer belongs to Lynx.
2. If it still fails, test Google Photos with **only Gunshot enabled**, then re-enable other tweaks individually. `GesturesXVUI` is loaded in the report, but is not on the terminating stack; do not conclude that it caused this crash merely because it is loaded.
3. Check the installed **RocketBootstrap and Cephei versions and package sources** for compatibility with the actual rootless jailbreak and iOS 16. Do not blindly install an old rootful “fix” into rootless. GoToHP's jailbreak IPC still requires a functioning RocketBootstrap; removing that dependency alone is not a working fix.
4. If the GoToHP-only configuration still crashes, capture its new IPS and include package versions/sources. That distinguishes a GoToHP/IPC failure from this earlier Lynx initialization failure.

The [palera1n issue discussing RocketBootstrap availability and iOS 15+ compatibility](https://github.com/palera1n/palera1n/issues/638) is supporting ecosystem context, not proof of the exact installed package defect here. The call-chain attribution above comes from the supplied IPS itself.

## Scope of the code change

The compatibility update permits 7.92.0+ through the modern adapter, retains the fixed 7.20.2 adapter, and removes numeric native-string-table lookups in favor of Google's resource key. These changes address version gating and a concrete forward-compatibility hazard. They do **not** patch Lynx, disable Mach port guards, intercept system `mach_msg`, or claim that this external initialization crash has been fixed on the device. An EXC_GUARD termination cannot be recovered with an Objective-C exception handler.
