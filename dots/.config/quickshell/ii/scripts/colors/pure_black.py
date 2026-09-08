import configparser
import json
import os
from pathlib import Path
import re
import subprocess


def pure_black_color(color: str) -> str:
    rgb = [int(color[index:index + 2], 16) for index in (1, 3, 5)]
    lightness = sum(rgb) / 3
    # Match https://github.com/InioX/matugen/blob/v4.1.0/src/color/color.rs with --lightness-dark -0.1.
    scale = max(0, 1.1 - 25.5 / lightness) if lightness else 0
    return '#{:02x}{:02x}{:02x}'.format(*(round(channel * scale) for channel in rgb))


def pure_black_scheme(scheme: configparser.ConfigParser) -> bool:
    if scheme.getboolean('General', 'PureBlack', fallback=False):
        return False
    for section in scheme.sections():
        if not section.startswith(('Colors:', 'ColorEffects:')) and section != 'WM':
            continue
        for key, value in scheme[section].items():
            if re.fullmatch(r'#[0-9a-fA-F]{6}', value):
                scheme[section][key] = pure_black_color(value)
            elif re.fullmatch(r'\d+,\d+,\d+(?:,\d+)?', value):
                channels = value.split(',')
                color = '#{:02x}{:02x}{:02x}'.format(*(int(c) for c in channels[:3]))
                color = pure_black_color(color)
                scheme[section][key] = ','.join(
                    [str(int(color[i:i + 2], 16)) for i in (1, 3, 5)] + channels[3:])
    for section in ('Colors:Window', 'Colors:View'):
        scheme[section]['BackgroundNormal'] = '#000000'
    scheme['General']['PureBlack'] = 'true'
    return True


def apply_kde_pure_black() -> None:
    config_home = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
    with (config_home / 'illogical-impulse/config.json').open() as file:
        appearance = json.load(file).get('appearance', {})
    theming = appearance.get('wallpaperTheming', {})
    if (appearance.get('darkStyle') != 'pure-black'
            or not theming.get('enableAppsAndShell', True)
            or not theming.get('enableQtApps', True)):
        return

    from kde_material_you_colors import settings
    from kde_material_you_colors.utils import plasma_utils, konsole_utils

    changed = False
    for path in Path(settings.USER_SCHEMES_PATH).glob('MaterialYouDark*.colors'):
        scheme = configparser.ConfigParser(interpolation=None)
        scheme.optionxform = str
        scheme.read(path)
        if pure_black_scheme(scheme):
            with path.open('w') as file:
                scheme.write(file, space_around_delimiters=False)
            changed = True

    editor_path = Path(settings.KSYNTAX_THEMES_DIR) / 'material-you-dark.theme'
    if editor_path.exists():
        editor = json.loads(editor_path.read_text())
        editor['editor-colors']['BackgroundColor'] = '#000000'
        editor['editor-colors']['IconBorder'] = '#000000'
        editor_path.write_text(json.dumps(editor, indent=4))

    dark = 'prefer-dark' in subprocess.check_output(
        ['gsettings', 'get', 'org.gnome.desktop.interface', 'color-scheme'], text=True)
    if dark and changed:
        plasma_utils.apply_color_schemes(False)

    force_dark = theming.get('terminalGenerationProps', {}).get('forceDarkMode', False)
    if theming.get('enableTerminal', True) and (dark or force_dark):
        for path in (settings.KONSOLE_COLOR_SCHEME_PATH, settings.KONSOLE_COLOR_SCHEME_ALT_PATH):
            scheme = configparser.ConfigParser(interpolation=None)
            scheme.optionxform = str
            scheme.read(path)
            for section in ('Background', 'BackgroundIntense', 'BackgroundFaint'):
                scheme[section]['Color'] = '0,0,0'
            with open(path, 'w') as file:
                scheme.write(file, space_around_delimiters=False)
        konsole_utils.apply_color_scheme()


if __name__ == '__main__':
    apply_kde_pure_black()
