"""Capture the real SwiftUI UI with sample data on App Store sized simulators."""
import json
import os
import pathlib
import subprocess
import time

def run(*args):
    print('Running:', ' '.join(args), flush=True)
    subprocess.run(args, check=True, timeout=480)

devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json'], text=True, timeout=60))['devices']
choices = [d for runtime, items in devices.items() if 'iOS-26' in runtime for d in items]
out = pathlib.Path('release-artifacts/screenshots')
out.mkdir(parents=True, exist_ok=True)
app = 'build/simulator/Build/Products/Debug-iphonesimulator/LanScope.app'
for family, match in [('iphone', lambda n: n.endswith(' Pro') and n.startswith('iPhone')), ('ipad', lambda n: 'iPad Pro 13-inch' in n)]:
    if family != os.environ['SCREENSHOT_FAMILY']:
        continue
    candidates = [d for d in choices if match(d['name'])]
    if not candidates:
        raise RuntimeError(f'No supported {family} simulator: {[d["name"] for d in choices]}')
    device = candidates[-1]
    udid = device['udid']
    if device['state'] != 'Booted':
        run('xcrun', 'simctl', 'boot', udid)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b')
    run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3', '--batteryState', 'charged', '--batteryLevel', '100')
    run('xcrun', 'simctl', 'install', udid, app)
    for screen, flags in [('devices', []), ('web', ['--screenshot-web']), ('settings', ['--screenshot-settings'])]:
        subprocess.run(['xcrun', 'simctl', 'terminate', udid, 'com.yoonzm.lanscope'], check=False, timeout=60)
        run('xcrun', 'simctl', 'launch', udid, 'com.yoonzm.lanscope', '--screenshots', *flags, '-AppleLanguages', '(en)', '-AppleLocale', 'en_US')
        time.sleep(10)
        run('xcrun', 'simctl', 'io', udid, 'screenshot', str(out / f'{family}-{screen}.png'))
