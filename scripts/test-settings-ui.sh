#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app=.build/settings-smoke/GoToHPSettingsFixture.app
mkdir -p "$app" .build/settings-ui-results
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
architecture=$(uname -m)
xcrun --sdk iphonesimulator clang -fobjc-arc -isysroot "$sdk" \
 -target "${architecture}-apple-ios15.0-simulator" \
 -framework UIKit -framework Foundation -framework Photos -framework PhotosUI \
 UI/GSPanel.m tests/settings_ui.m -o "$app/GoToHPSettingsFixture"
python3 - <<'PY'
import pathlib,plistlib
info={"CFBundleIdentifier":"dev.tqmane.gunshot.settingsfixture","CFBundleExecutable":"GoToHPSettingsFixture","CFBundleName":"GoToHP Settings Fixture","CFBundlePackageType":"APPL","CFBundleVersion":"1","CFBundleShortVersionString":"1.0","MinimumOSVersion":"15.0","UIDeviceFamily":[1],"UILaunchScreen":{},"UIApplicationSceneManifest":{"UIApplicationSupportsMultipleScenes":False}}
pathlib.Path('.build/settings-smoke/GoToHPSettingsFixture.app/Info.plist').write_bytes(plistlib.dumps(info))
PY
codesign --force --sign - "$app"
python3 - <<'PY'
import json,subprocess,pathlib,shutil
run=lambda *args:subprocess.check_output(args,text=True).strip()
devices=json.loads(run('xcrun','simctl','list','devices','available','-j'))['devices']
choices=[d for runtime,group in devices.items() if '.iOS-' in runtime for d in group if d.get('isAvailable') and d['name'].startswith('iPhone')]
if not choices:raise SystemExit('No available iPhone simulator runtime')
device=next((d for d in choices if d['state']=='Booted'),choices[0]);udid=device['udid']
if device['state']!='Booted':subprocess.run(['xcrun','simctl','boot',udid],check=True,timeout=90)
subprocess.run(['xcrun','simctl','bootstatus',udid,'-b'],check=True,timeout=180)
app='.build/settings-smoke/GoToHPSettingsFixture.app';bundle='dev.tqmane.gunshot.settingsfixture'
subprocess.run(['xcrun','simctl','install',udid,app],check=True,timeout=60)
subprocess.run(['xcrun','simctl','launch','--console',udid,bundle],check=True,timeout=90)
container=pathlib.Path(run('xcrun','simctl','get_app_container',udid,bundle,'data'))/'Documents'
result=(container/'result.txt').read_text()
for p in container.iterdir():
 if p.suffix in ['.txt','.png']:shutil.copy2(p,pathlib.Path('.build/settings-ui-results')/p.name)
print(result)
if not result.startswith('PASS '):raise SystemExit(1)
PY
