#!/usr/bin/env python3
"""Run the real UIKit adapter with independently selected build SDK and runtime."""
import json
import os
import pathlib
import platform
import plistlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
os.chdir(ROOT)
app = ROOT / '.build/liquid-glass/GlassFixture.app'
results = ROOT / '.build/liquid-glass-results'
app.mkdir(parents=True, exist_ok=True)
results.mkdir(parents=True, exist_ok=True)
build_env = dict(os.environ, DEVELOPER_DIR=os.environ['BUILD_DEVELOPER_DIR'])


def run(*args, env=None, timeout=120):
    print('+', ' '.join(map(str, args)), flush=True)
    return subprocess.check_output(args, env=env, text=True, timeout=timeout).strip()


sdk = run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path', env=build_env)
run('xcrun', '--sdk', 'iphonesimulator', 'clang', '-fobjc-arc', '-Wall', '-Wextra',
    '-Werror', '-Wno-unused-parameter', '-isysroot', sdk,
    '-target', f'{platform.machine()}-apple-ios15.0-simulator',
    '-framework', 'UIKit', '-framework', 'Foundation',
    'UI/GSAppearance.m', 'tests/liquid_glass_ui.m', '-o', str(app / 'GlassFixture'),
    env=build_env)
bundle = 'dev.tqmane.gunshot.glassfixture'
info = dict(CFBundleIdentifier=bundle, CFBundleExecutable='GlassFixture',
            CFBundleName='Glass Fixture', CFBundlePackageType='APPL',
            CFBundleVersion='1', CFBundleShortVersionString='1.0',
            MinimumOSVersion='15.0', UIDeviceFamily=[1, 2], UILaunchScreen={},
            UIApplicationSceneManifest={'UIApplicationSupportsMultipleScenes': False})
if os.environ.get('COMPATIBILITY') == '1':
    info['UIDesignRequiresCompatibility'] = True
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
run('codesign', '--force', '--sign', '-', str(app))
runtimes = json.loads(run('xcrun', 'simctl', 'list', 'runtimes', '-j'))['runtimes']
version = os.environ['SIMULATOR_VERSION']
candidates = [r for r in runtimes if r.get('isAvailable') and '.iOS-' in r['identifier']
              and (r['version'] == version or r['version'].startswith(version + '.'))]
if not candidates:
    raise SystemExit(f'No available iOS {version} runtime: {runtimes}')
runtime = max(candidates, key=lambda r: tuple(map(int, r['version'].split('.'))))
print('Fixture runtime:', runtime['version'], runtime['identifier'], flush=True)
types = json.loads(run('xcrun', 'simctl', 'list', 'devicetypes', '-j'))['devicetypes']
device_name = os.environ.get('DEVICE_NAME', 'iPhone 16 Pro')
device = next(t for t in types if t['name'] == device_name)
udid = run('xcrun', 'simctl', 'create', 'Gunshot Glass CI', device['identifier'], runtime['identifier'])
try:
    run('xcrun', 'simctl', 'boot', udid)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b', timeout=180)
    run('xcrun', 'simctl', 'install', udid, str(app))
    # simctl --console stays attached until the fixture exits.
    launch_error = None
    # A regular file avoids waiting for EOF from inherited console pipe handles.
    with (results / 'console.txt').open('w') as console:
        try:
            subprocess.run(['xcrun', 'simctl', 'launch', '--console', udid, bundle],
                           stdout=console, stderr=subprocess.STDOUT, check=True, timeout=120)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            launch_error = str(error)
    print((results / 'console.txt').read_text(), flush=True)
    data = pathlib.Path(run('xcrun', 'simctl', 'get_app_container', udid, bundle, 'data')) / 'Documents'
    for path in data.iterdir():
        if path.suffix in ('.txt', '.png'):
            shutil.copy2(path, results / path.name)
    result_file = results / 'result.txt'
    result = result_file.read_text() if result_file.exists() else 'FAIL fixture did not write a result'
    print(result, flush=True)
    if launch_error:
        print(launch_error, flush=True)
    if launch_error or not result.startswith('PASS '):
        raise SystemExit(1)
finally:
    subprocess.run(['xcrun', 'simctl', 'shutdown', udid], timeout=30, check=False)
    subprocess.run(['xcrun', 'simctl', 'delete', udid], timeout=30, check=False)
