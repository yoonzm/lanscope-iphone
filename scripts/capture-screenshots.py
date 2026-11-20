"""Capture the real SwiftUI UI with sample data on App Store sized simulators."""
import json
import pathlib
import subprocess
import time

def run(*args):
    return subprocess.check_output(args, text=True).strip()

devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
choices = [d for runtime, items in devices.items() if 'iOS-26' in runtime for d in items]
out = pathlib.Path('release-artifacts/screenshots')
out.mkdir(parents=True, exist_ok=True)
app = 'build/simulator/Build/Products/Debug-iphonesimulator/LanScope.app'
for family, match in [('iphone', lambda n: 'Pro Max' in n), ('ipad', lambda n: 'iPad Pro 13-inch' in n)]:
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
        subprocess.run(['xcrun', 'simctl', 'terminate', udid, 'com.yoonzm.lanscope'], check=False)
        run('xcrun', 'simctl', 'launch', udid, 'com.yoonzm.lanscope', '--screenshots', *flags, '-AppleLanguages', '(en)', '-AppleLocale', 'en_US')
        time.sleep(4)
        run('xcrun', 'simctl', 'io', udid, 'screenshot', str(out / f'{family}-{screen}.png'))
    run('xcrun', 'simctl', 'shutdown', udid)
