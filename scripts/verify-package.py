#!/usr/bin/env python3
from pathlib import Path
import plistlib, subprocess, sys, tempfile
scheme=sys.argv[1];debs=list(Path('packages').glob('*.deb'));assert debs, 'no packages'
prefix='var/jb/' if scheme=='rootless' else ''
with tempfile.TemporaryDirectory() as d:
    subprocess.run(['dpkg-deb','-x',str(debs[-1]),d],check=True)
    r=Path(d)/prefix
    for p in ['usr/libexec/gotohpd','Library/MobileSubstrate/DynamicLibraries/Gunshot.dylib','Library/PreferenceBundles/GunshotPrefs.bundle/GunshotPrefs']:
        assert (r/p).is_file(), p
    launch=plistlib.loads((r/'Library/LaunchDaemons/dev.tqmane.gunshot.plist').read_bytes())
    assert launch['UserName']=='mobile'
    assert launch['ProgramArguments']==['/'+prefix+'usr/libexec/gotohpd']
    assert 'StandardOutPath' not in launch and 'StandardErrorPath' not in launch
