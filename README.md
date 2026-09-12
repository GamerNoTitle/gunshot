# GoToHP for iOS — Gunshot

[English](README.md) · [日本語](README.ja.md)

A Google Photos uploader for jailbroken, sideloaded and LiveContainer apps, reusing the Go upload core from [xob0t/gotohp](https://github.com/xob0t/gotohp). Jailbreak packages use a separate `gotohpd` service. The jailed package runs the core inside the host app.

This is a development build. CI validates builds and fixtures; compatibility and server behavior still require device testing. The audited Google Photos version is **7.92.0**, whose IPA requires **iOS 18.0**. Older iOS versions need an appropriate Google Photos version, and version-specific integration will not activate on unsupported versions.

## Install and use

### Sideloading / LiveContainer

Download the `gotohp-tweak-jailed` artifact from GitHub Actions. It contains the jailed `.deb`, standalone `GunshotJailed.dylib` and third-party notices. The Go core and translations are embedded; Theos is only needed on the build machine. Follow the [jailed installation guide](docs/jailed.md) for injection and LiveContainer setup.

Open **Google Photos profile menu → GoToHP settings**. The jailed integration connects the currently signed-in Google Photos account through the app's existing SSO authorizer.

Choose **Uploads → Choose photos and videos** for the GoToHP picker. To route Google Photos backup actions, enable **Route manual and automatic backups through GoToHP** and confirm the destination once. Subsequent native backup actions enqueue without opening the GoToHP screen. Automatic backup also requires backup to be enabled in Google Photos. **Keep the app in the foreground on jailed devices**; this package cannot provide a persistent daemon after the app terminates.

See [backup routing](docs/analysis/backup-routing.md) and [replacement coverage](docs/full-upload-replacement.md) for supported paths and limitations. Full coverage of every private upload path is not guaranteed.

### Jailbreak

Install the `gotohp-tweak-rootless` or `gotohp-tweak-rootful` `.deb` using your package manager. RocketBootstrap, PreferenceLoader and your jailbreak's substrate-compatible injection system are required.

Open **Settings → GoToHP → Open GoToHP settings** to manage accounts, quality, network restrictions and the queue. The independent daemon uses an imported upstream credential; see [upstream sign-in](https://github.com/xob0t/gotohp#sign-in). Keep the app open until media preparation and transfer to the daemon finish. Queued uploads then continue independently of the app.

Google Photos exposes settings in its profile menu. Apple Photos has a GoToHP button. Compatible share sheets expose **Upload with GoToHP** for PhotoKit assets or local file URLs. Unsupported share providers require selecting media in the GoToHP picker.

## Quality and queue

| Setting | Upstream device profile / requested behavior |
| --- | --- |
| Original | First-generation Pixel XL (Pixel 1), original quality without storage usage |
| Storage saver | Pixel 2, storage saver |
| Account storage | Pixel 8, original quality using normal quota |

Account and quality are saved when each item is queued. Changing settings does not alter existing jobs. Actual Google storage accounting and original-data availability must be checked separately; a successful API response alone does not prove quota treatment.

Original PhotoKit resources are exported without re-encoding. Live Photos use the original still and paired video. The queue supports progress, retry, cancellation and restart recovery. Retries restart the file transfer; Google upload-session byte-offset resume is not implemented. An interrupted commit with an unknown outcome requires manual review/retry, and may produce duplicates. Cancellation does not delete assets already committed to Google Photos.

## Languages

English and Japanese are included. **GoToHP settings → Appearance → Language** offers System default, Japanese and English. Unsupported device languages fall back to English. No separate translation bundle needs to be injected. See [localization](docs/localization.md) to contribute translations.

## Build

Use macOS, Xcode command line tools, Go 1.26.0, Theos, `ldid` and `dpkg`:

```sh
git clone --recurse-submodules https://github.com/tqmane/gunshot.git
cd gunshot
export THEOS="$HOME/theos"
bash scripts/package.sh jailed
# Other targets:
bash scripts/package.sh rootless
bash scripts/package.sh rootful
```

The daemon/Go archive and jailed package use arm64. The jailbreak tweak and Preferences support arm64 and arm64e. The Go runtime stays out of the injected jailbreak tweak process.

CI runs Go race tests, upstream regression tests, C ABI tests, localization checks, native routing fixtures, UIKit settings tests and all three package builds. Successful `v*` tags publish packages, the jailed dylib and notices as release assets.

```sh
python3 scripts/localization.py --check
python3 scripts/prepare-core.py
go test -race -tags cli ./...
go test -tags cli app/backend
go vet -tags cli ./...
```

## Architecture and credentials

The jailbreak service uses RocketBootstrap/Mach IPC, validates the sender's kernel audit token and signature, and accepts bounded media chunks rather than arbitrary filesystem paths. Its mobile data directory is mode 0700; queue and credential files are mode 0600. Imported daemon credentials use private JSON storage; Keychain storage is not implemented.

The jailed native account stores the email and account identifier and delegates token retrieval/refresh to Google Photos SSO. Credentials and raw upstream responses are not logged or shown again. Diagnostic exports exclude tokens and media contents.

See the [architecture](docs/architecture.md), [Google Photos analysis index](docs/analysis/index.md) and [device validation checklist](docs/device-validation.md). Detailed analysis documents are currently in Japanese. The IPA is not included in the repository or packages.

## Upstream updates

```sh
bash scripts/sync-upstream.sh
# Or pin an audited commit:
bash scripts/sync-upstream.sh <commit>
```

The script updates the submodule and `GotohpCore/UPSTREAM_REVISION`. `prepare-core.py` projects the pinned backend into `.build/upstream`; the upstream source is not edited directly. Keep the upstream license and generated third-party notices with distributions.
