#!/usr/bin/env python3
from pathlib import Path
import plistlib, subprocess, sys, tempfile
scheme=sys.argv[1]
assert scheme in ('rootless','rootful','jailed'), 'unknown scheme'
if scheme=='jailed':
    debs=[Path('packages/jailed/gotohp-tweak-jailed.deb')]
else:
    arch='iphoneos-arm64' if scheme=='rootless' else 'iphoneos-arm'
    debs=list(Path('packages').glob('*_'+arch+'.deb'))
assert debs, 'no packages'
deb=max(debs,key=lambda p:p.stat().st_mtime)
prefix='var/jb/' if scheme=='rootless' else ''
with tempfile.TemporaryDirectory() as d:
    subprocess.run(['dpkg-deb','-x',str(deb),d],check=True)
    if scheme=='jailed':
        r=Path(d)
        binary=r/'Library/MobileSubstrate/DynamicLibraries/GunshotJailed.dylib'
        assert binary.is_file()
        assert binary.read_bytes()==Path('packages/jailed/GunshotJailed.dylib').read_bytes()
        assert sorted(str(p.relative_to(r)) for p in r.rglob('*') if p.is_file())==[
            'Library/MobileSubstrate/DynamicLibraries/GunshotJailed.dylib',
            'Library/MobileSubstrate/DynamicLibraries/GunshotJailed.plist',
            'usr/share/doc/dev.tqmane.gunshot.jailed/ThirdPartyNotices.txt']
        deps=subprocess.check_output(['dpkg-deb','-f',str(deb),'Depends'],text=True).strip()
        assert deps=='firmware (>= 15.0)', deps
        subprocess.run(['dpkg-deb','-e',str(deb),str(r/'control')],check=True)
        assert not any((r/'control'/n).exists() for n in ('postinst','prerm','preinst','postrm'))
        linked=subprocess.check_output(['otool','-L',str(binary)],text=True)
        assert '@rpath/GunshotJailed.dylib' in linked, linked
        dependencies="\n".join(linked.splitlines()[2:])
        for name in ('rocketbootstrap','libsandy','substrate','ellekit','Preferences.framework','/var/jb/'):
            assert name.lower() not in dependencies.lower(), linked
        for line in linked.splitlines()[2:]:
            assert line.strip().startswith(('/System/Library/Frameworks/','/usr/lib/')), line
        assert subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip()=='arm64'
        sys.exit(0)
    r=Path(d)/prefix
    deps=subprocess.check_output(['dpkg-deb','-f',str(deb),'Depends'],text=True)
    assert 'com.opa334.libsandy (>= 1.1.6)' in deps, deps
    profile=r/'Library/libSandy/dev.tqmane.gunshot.ipc.plist'
    assert profile.stat().st_mode & 0o777 == 0o644
    assert plistlib.loads(profile.read_bytes())=={
        'AllowedProcesses':['com.google.photos','com.apple.mobileslideshow','com.apple.Preferences'],
        'Extensions':[{'type':'mach','extension_class':'com.apple.app-sandbox.mach','mach_name':'dev.tqmane.gunshot.service'}]}
    for p in ['usr/libexec/gotohpd','Library/MobileSubstrate/DynamicLibraries/Gunshot.dylib','Library/PreferenceBundles/GunshotPrefs.bundle/GunshotPrefs']:
        assert (r/p).is_file(), p
    # The crashing legacy RocketBootstrap client must not be linked into apps.
    # Only the daemon uses RocketBootstrap to unlock its registered service.
    for p in ['Library/MobileSubstrate/DynamicLibraries/Gunshot.dylib',
              'Library/PreferenceBundles/GunshotPrefs.bundle/GunshotPrefs']:
        linked=subprocess.check_output(['otool','-L',str(r/p)],text=True)
        assert 'rocketbootstrap' not in linked.lower(), linked
        symbols=subprocess.check_output(['nm','-u',str(r/p)],text=True)
        assert '_rocketbootstrap_look_up' not in symbols, symbols
        strings=subprocess.check_output(['strings',str(r/p)],text=True)
        assert '/'+prefix+'usr/lib/libsandy.dylib' in strings.splitlines(), 'wrong sandbox library prefix'
        assert 'dev.tqmane.gunshot.ipc' in strings.splitlines(), 'sandbox profile missing from client'
    daemon_links=subprocess.check_output(['otool','-L',str(r/'usr/libexec/gotohpd')],text=True)
    assert 'rocketbootstrap' in daemon_links.lower(), daemon_links
    launch=plistlib.loads((r/'Library/LaunchDaemons/dev.tqmane.gunshot.plist').read_bytes())
    assert launch['UserName']=='mobile'
    assert launch['ProgramArguments']==['/'+prefix+'usr/libexec/gotohpd']
    assert 'StandardOutPath' not in launch and 'StandardErrorPath' not in launch

    info=plistlib.loads((r/'Library/PreferenceBundles/GunshotPrefs.bundle/Info.plist').read_bytes())
    assert info['NSPrincipalClass']=='GSRootListController'
    assert info['CFBundleExecutable']=='GunshotPrefs'
    assert not (r/'var/jb').exists(), 'package prefix applied twice'
