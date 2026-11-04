#!/usr/bin/env python3
"""Opt-in real Sparkle install/relaunch in scratch bundles; uses the release Keychain key.
Does not launch or replace agenticnights or edit its settings.
"""
import functools, http.server, pathlib, plistlib, shutil, subprocess, threading, time, uuid
project = pathlib.Path(__file__).resolve().parent.parent
root = project / '.build/update-smoke'
root.mkdir(parents=True, exist_ok=True)
sparkle = pathlib.Path(subprocess.check_output([str(project / 'Scripts/fetch-sparkle.sh')], text=True).strip())
subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5', '-num-threads', '2', '-module-cache-path', str(project / '.build/ModuleCache'), '-F', str(sparkle), '-framework', 'Sparkle', '-framework', 'AppKit', '-Xlinker', '-rpath', '-Xlinker', '@executable_path/../Frameworks', str(project / 'Tests/UpdateSmokeTests.swift'), '-o', str(root / 'smoke')], check=True)
public = plistlib.loads((project / 'Resources/Info.plist').read_bytes())['SUPublicEDKey']
run = root / time.strftime('run-%Y%m%d-%H%M%S'); run.mkdir()
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=str(run)))
threading.Thread(target=server.serve_forever, daemon=True).start()
port = server.server_port
for mode in ['cancel', 'corrupt', 'install']:
    work = run / mode; work.mkdir()
    feed = work / 'feed'; feed.mkdir()
    result = work / 'result.txt'
    app = work / 'UpdateSmoke.app'
    for version, target in [('1', app), ('2', feed / 'UpdateSmoke.app')]:
        (target / 'Contents/MacOS').mkdir(parents=True)
        (target / 'Contents/Frameworks').mkdir()
        shutil.copy2(root / 'smoke', target / 'Contents/MacOS/UpdateSmoke')
        shutil.copytree(sparkle / 'Sparkle.framework', target / 'Contents/Frameworks/Sparkle.framework', symlinks=True)
        info = dict(CFBundleIdentifier='com.tk.agenticnights.UpdateSmoke.'+mode+'.'+uuid.uuid4().hex, CFBundleName='UpdateSmoke', CFBundleExecutable='UpdateSmoke', CFBundlePackageType='APPL', CFBundleVersion=version, CFBundleShortVersionString=version+'.0', LSMinimumSystemVersion='13.0', LSUIElement=True, NSPrincipalClass='NSApplication', SUFeedURL=f'http://127.0.0.1:{port}/{mode}/feed/appcast.xml', SUPublicEDKey=public, SUEnableAutomaticChecks=False, SUAllowsAutomaticUpdates=False, SUVerifyUpdateBeforeExtraction=True, SmokeResult=str(result), SmokeMode=mode, NSAppTransportSecurity={'NSAllowsLocalNetworking':True})
        # Both versions must have exactly the same bundle identifier.
        if version == '1': bundle_id = info['CFBundleIdentifier']
        info['CFBundleIdentifier'] = bundle_id
        (target / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        subprocess.run(['codesign','--force','--sign','-',str(target)],check=True,capture_output=True)
    archive=feed/'UpdateSmoke.zip'
    subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(feed/'UpdateSmoke.app'),str(archive)],check=True)
    shutil.rmtree(feed/'UpdateSmoke.app')
    subprocess.run([str(sparkle/'bin/generate_appcast'),'--account','com.tk.agenticnights','--maximum-deltas','0','--download-url-prefix',f'http://127.0.0.1:{port}/{mode}/feed/',str(feed)],check=True,capture_output=True)
    if mode == 'corrupt':
        content=bytearray(archive.read_bytes()); content[100] ^= 1; archive.write_bytes(content)
    subprocess.run(['open','-n','-W',str(app)],check=True,timeout=60)
    deadline=time.monotonic()+20
    while mode == 'install' and time.monotonic()<deadline and (not result.exists() or 'PASS: replaced app launched' not in result.read_text()):
        time.sleep(.2)
    text=result.read_text() if result.exists() else 'NO RESULT'
    print(f'{mode}: log saved to {result}', flush=True)
    installed=plistlib.loads((app/'Contents/Info.plist').read_bytes())['CFBundleVersion']
    if mode == 'install': assert installed=='2' and 'PASS: replaced app launched' in text, text
    elif mode == 'cancel': assert installed=='1' and 'PASS: cancel' in text, text
    else: assert installed=='1' and 'ERROR:' in text and ('sign' in text.lower()), text
print('PASS: Sparkle cancel, corrupted-signature rejection, full install and relaunch; '+str(run),flush=True)
server.shutdown()
