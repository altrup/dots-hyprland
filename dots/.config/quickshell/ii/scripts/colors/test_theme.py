import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


SOURCE = Path(__file__).resolve().parents[2]

with tempfile.TemporaryDirectory(prefix='pure_black-theme-') as directory:
    root = Path(directory)
    (root / 'Placeholder.qml').write_text('import QtQuick\nQtObject {}\n')
    files = (
        'modules/common/Config.qml', 'modules/common/Appearance.qml',
        'modules/common/functions/ColorUtils.qml',
        'modules/common/models/quickToggles/QuickToggleModel.qml',
        'modules/common/models/quickToggles/DarkModeToggle.qml',
        'modules/ii/sidebarRight/quickToggles/androidStyle/AndroidDarkModeToggle.qml',
        'services/MaterialThemeLoader.qml',
    )
    for name in files:
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text((SOURCE / name).read_text())
    (root / 'modules/common/widgets').mkdir()
    (root / 'modules/common/widgets/Placeholder.qml').write_text('import QtQuick\nQtObject {}\n')
    (root / 'modules/common/Directories.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    readonly property string base: ROOT_PATH
    readonly property string shellConfigPath: base + "/config.json"
    readonly property string generatedMaterialThemePath: base + "/colors.json"
    readonly property string wallpaperSwitchScriptPath: base + "/record.py"
    readonly property string videos: "/tmp"
}
'''.replace('ROOT_PATH', json.dumps(str(root))))
    (root / 'services/Translation.qml').write_text('''pragma Singleton
import QtQuick
QtObject { function tr(text) { return text; } }
''')
    (root / 'modules/ii/sidebarRight/quickToggles/androidStyle/AndroidQuickToggleButton.qml').write_text('''import QtQuick
Item {
    property QtObject toggleModel
    property var altAction
    property var mainAction: toggleModel.mainAction
    signal clicked()
}
''')
    (root / 'config.json').write_text('{"appearance":{"darkStyle":"standard"}}')
    (root / 'colors.json').write_text('{"background":"#000000"}')
    recorder = root / 'record.py'
    recorder.write_text(f'#!{sys.executable}\n' + r'''import json, sys
from pathlib import Path
root = Path(__file__).parent
style = json.loads((root / 'config.json').read_text())['appearance']['darkStyle']
with (root / 'calls.jsonl').open('a') as file:
    file.write(json.dumps({'args': sys.argv[1:], 'style': style}) + '\n')
''')
    recorder.chmod(0o700)
    (root / 'shell.qml').write_text('''import QtQuick
import Quickshell
import qs.modules.common
import qs.services
import qs.modules.ii.sidebarRight.quickToggles.androidStyle
ShellRoot {
    AndroidDarkModeToggle { id: toggle }
    function check(value, message) {
        if (!value) { console.error(message); Qt.exit(1); }
    }
    Timer {
        interval: 100; running: true; repeat: true
        property int step: 0
        property var menu
        onTriggered: {
            if (!Config.ready) return;
            if (step === 0) {
                menu = Array.from(toggle.data).find(item => typeof item.itemAt === "function");
                check(menu !== undefined, "Missing context menu");
                Config.options.appearance.transparency.enable = true;
                Config.options.appearance.transparency.automatic = false;
                Config.options.appearance.transparency.backgroundTransparency = 0.3;
                Config.options.appearance.transparency.contentTransparency = 0.5;
                menu.itemAt(5).triggered();
                check(MaterialThemeLoader.darkStylePending, "Generation must wait for save");
                check(Config.options.appearance.darkStyle === "pure-black", "Menu must select PureBlack");
                MaterialThemeLoader.setDarkStyle("invalid");
                step++;
            } else if (step === 1 && !MaterialThemeLoader.darkStylePending) {
                check(Appearance.pureBlack && Appearance.backgroundTransparency === 0
                      && Appearance.contentTransparency === 0, "Pure black must be opaque");
                check(Appearance.colors.colLayer0Base == Appearance.m3colors.m3background, "Pure black must suppress tint");
                Appearance.m3colors.darkmode = false;
                check(!menu.itemAt(4).visible && !menu.itemAt(5).visible, "Hide dark styles in Light");
                check(!Appearance.pureBlack && Appearance.backgroundTransparency === 0.3, "Restore Light transparency");
                check(Config.options.appearance.darkStyle === "pure-black", "Remember dark style in Light");
                menu.itemAt(1).triggered();
                Appearance.m3colors.darkmode = true;
                check(Appearance.pureBlack && menu.itemAt(5).checked, "Restore Pure black in Dark");
                toggle.clicked();
                menu.itemAt(4).triggered();
                step++;
            } else if (step === 2 && !MaterialThemeLoader.darkStylePending) {
                check(!Appearance.pureBlack && Appearance.backgroundTransparency === 0.3
                      && Appearance.contentTransparency === 0.5, "Restore Standard preferences");
                MaterialThemeLoader.setMode("invalid");
                step++;
            } else if (step === 3) {
                console.log("PURE BLACK UI CHECK PASSED");
                Qt.quit();
            }
        }
    }
}
''')
    runtime = root / 'runtime'
    runtime.mkdir(mode=0o700)
    environment = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='basic',
                       XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(root / 'cache'))
    environment.pop('WAYLAND_DISPLAY', None)
    result = subprocess.run(['quickshell', '--path', str(root / 'shell.qml'), '--no-color'],
                            env=environment, text=True, capture_output=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'PURE BLACK UI CHECK PASSED' in output, output
    assert (root / 'calls.jsonl').exists(), output
    calls = [json.loads(line) for line in (root / 'calls.jsonl').read_text().splitlines()]
    assert {'args': ['--noswitch'], 'style': 'pure-black'} in calls, calls
    assert {'args': ['--noswitch'], 'style': 'standard'} in calls, calls
    assert any(call['args'] == ['--mode', 'dark', '--noswitch'] for call in calls), calls
    assert any(call['args'] == ['--mode', 'light', '--noswitch'] for call in calls), calls
    assert len(calls) == 4, calls
    assert json.loads((root / 'config.json').read_text())['appearance']['darkStyle'] == 'standard'
    print('PASS: saved styles, menu actions, mode restoration, tint, and transparency')
