import json
import configparser
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch
from pure_black import pure_black_color


SCRIPT_DIR = Path(__file__).resolve().parent


class PureBlackTest(unittest.TestCase):
    def test_kde_hook_outputs_optouts_and_restoration(self):
        from pure_black import apply_kde_pure_black
        from kde_material_you_colors import settings
        from kde_material_you_colors.schemeconfigs import ThemeConfig
        from kde_material_you_colors.utils import m3_scheme_utils, plasma_utils, konsole_utils, ksyntax_utils

        colors = m3_scheme_utils.get_material_you_colors('#6750a4', 0, 'color', 5, 1, 1)
        theme = ThemeConfig(colors, '#6750a4', toolbar_opacity=100, toolbar_opacity_dark=100)
        with tempfile.TemporaryDirectory(prefix='pure_black-kde-') as directory:
            root = Path(directory)
            config = root / 'illogical-impulse/config.json'
            config.parent.mkdir()
            paths = dict(USER_SCHEMES_PATH=str(root / 'schemes'),
                         THEME_DARK_PATH=str(root / 'schemes/MaterialYouDark'),
                         THEME_LIGHT_PATH=str(root / 'schemes/MaterialYouLight'),
                         KSYNTAX_THEMES_DIR=str(root / 'editor') + '/',
                         KONSOLE_DIR=str(root / 'terminal'),
                         KONSOLE_COLOR_SCHEME_PATH=str(root / 'terminal/MaterialYou.colorscheme'),
                         KONSOLE_COLOR_SCHEME_ALT_PATH=str(root / 'terminal/MaterialYouAlt.colorscheme'))
            with (patch.multiple(settings, **paths), patch.dict(os.environ, XDG_CONFIG_HOME=directory),
                  patch.object(plasma_utils, 'apply_color_schemes'),
                  patch.object(konsole_utils, 'apply_color_scheme'),
                  patch('pure_black.subprocess.check_output', return_value="'prefer-dark'")):
                def generate():
                    plasma_utils.make_scheme(theme)
                    ksyntax_utils.export_schemes(theme)
                    konsole_utils.export_scheme(schemes=theme, dark_light=False)

                def snapshot():
                    return {str(path.relative_to(root)): path.read_bytes()
                            for folder in ('schemes', 'editor', 'terminal')
                            for path in (root / folder).iterdir()}

                generate()
                standard = snapshot()
                config.write_text('{"appearance":{"darkStyle":"pure-black"}}')
                apply_kde_pure_black()
                scheme = configparser.ConfigParser()
                scheme.read(settings.THEME_DARK_PATH + '.colors')
                self.assertEqual(scheme['Colors:Window']['BackgroundNormal'], '#000000')
                scheme.read(settings.KONSOLE_COLOR_SCHEME_PATH)
                self.assertEqual(scheme['Background']['Color'], '0,0,0')
                editor = json.loads((root / 'editor/material-you-dark.theme').read_text())
                self.assertEqual(editor['editor-colors']['BackgroundColor'], '#000000')

                generate()
                config.write_text('{"appearance":{"darkStyle":"standard"}}')
                apply_kde_pure_black()
                self.assertEqual(snapshot(), standard)
                for option in ('enableAppsAndShell', 'enableQtApps', 'enableTerminal'):
                    generate()
                    config.write_text(json.dumps({'appearance': {'darkStyle': 'pure-black',
                                                   'wallpaperTheming': {option: False}}}))
                    apply_kde_pure_black()
                    after = snapshot()
                    for path, contents in standard.items():
                        if option != 'enableTerminal' or path.startswith('terminal/'):
                            self.assertEqual(after[path], contents)

    def test_rendered_shell_gtk_and_launcher_backgrounds(self):
        config_root = SCRIPT_DIR.parents[3]
        config = tomllib.loads((config_root / 'matugen/config.toml').read_text())
        with tempfile.TemporaryDirectory(prefix='pure_black-render-') as directory:
            root = Path(directory)
            entries = ['[config]\nversion_check = false']
            for name in ('m3colors', 'gtk3', 'gtk4', 'fuzzel'):
                template = config['templates'][name]
                source = config_root / template['input_path'].removeprefix('~/.config/')
                entries.append(f'[templates.{name}]\ninput_path = {json.dumps(str(source))}\n'
                               f'output_path = {json.dumps(str(root / name))}')
            path = root / 'config.toml'
            path.write_text('\n\n'.join(entries))
            command = ['matugen', '--config', str(path), '--mode', 'dark', 'color', 'hex', '#6750a4']
            subprocess.run(command, check=True, capture_output=True)
            standard = {name: (root / name).read_bytes() for name in ('m3colors', 'gtk3', 'gtk4', 'fuzzel')}
            subprocess.run(command + ['--lightness-dark', '-0.1'], check=True, capture_output=True)
            self.assertEqual(json.loads((root / 'm3colors').read_text())['background'], '#000000')
            for name in ('gtk3', 'gtk4'):
                self.assertIn('@define-color window_bg_color #000000;', (root / name).read_text())
            launcher = configparser.ConfigParser()
            launcher.read(root / 'fuzzel')
            self.assertEqual(launcher['colors']['background'], '000000ff')
            subprocess.run(command, check=True, capture_output=True)
            for name, contents in standard.items():
                self.assertEqual((root / name).read_bytes(), contents)

    def test_kde_backgrounds_colors_and_repeated_application(self):
        from pure_black import pure_black_scheme
        scheme = configparser.ConfigParser(interpolation=None)
        scheme.optionxform = str
        scheme.read_string('[General]\nName=Material You dark\n'
                           '[Colors:Window]\nBackgroundNormal=#211f24\nForegroundNormal=#e6e0e9\n'
                           '[Colors:View]\nBackgroundNormal=#141218\n'
                           '[Colors:Button]\nBackgroundNormal=#2b292f\n'
                           '[WM]\nactiveBackground=43,41,47,200\n'
                           '[KDE]\ncontrast=4\n')
        self.assertTrue(pure_black_scheme(scheme))
        self.assertEqual(scheme['Colors:Window']['BackgroundNormal'], '#000000')
        self.assertEqual(scheme['Colors:View']['BackgroundNormal'], '#000000')
        self.assertNotEqual(scheme['Colors:Button']['BackgroundNormal'], '#000000')
        self.assertNotEqual(scheme['Colors:Window']['ForegroundNormal'], '#000000')
        self.assertEqual(scheme['WM']['activeBackground'].split(',')[-1], '200')
        self.assertEqual(scheme['KDE']['contrast'], '4')
        before = {key: dict(scheme[key]) for key in scheme}
        self.assertFalse(pure_black_scheme(scheme))
        self.assertEqual(before, {key: dict(scheme[key]) for key in scheme})

    def test_all_palettes_match_matugen_and_keep_readable_surfaces(self):
        for palette in ('content', 'expressive', 'fidelity', 'fruit-salad', 'monochrome',
                        'neutral', 'rainbow', 'tonal-spot', 'vibrant'):
            with self.subTest(palette=palette):
                command = ['matugen', '--dry-run', '--json', 'hex', '--type',
                           f'scheme-{palette}', 'color', 'hex', '#6750a4']
                standard = json.loads(subprocess.check_output(command))['colors']
                pure_black = json.loads(subprocess.check_output(
                    command + ['--lightness-dark', '-0.1']))['colors']
                self.assertEqual(pure_black['background']['dark']['color'], '#000000')
                self.assertNotEqual(pure_black['surface_container_high']['dark']['color'], '#000000')
                for role in standard:
                    self.assertEqual(standard[role]['light'], pure_black[role]['light'])
                    if role == 'source_color':
                        self.assertEqual(standard[role], pure_black[role])
                        continue
                    expected = pure_black[role]['dark']['color']
                    actual = pure_black_color(standard[role]['dark']['color'])
                    for index in (1, 3, 5):
                        self.assertLessEqual(abs(int(actual[index:index + 2], 16)
                                                 - int(expected[index:index + 2], 16)), 1)
                channels = [int(pure_black['on_background']['dark']['color'][i:i + 2], 16) / 255
                            for i in (1, 3, 5)]
                linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
                          for c in channels]
                luminance = sum(c * weight for c, weight in zip(linear, (0.2126, 0.7152, 0.0722)))
                self.assertGreaterEqual((luminance + 0.05) / 0.05, 4.5)

    def test_terminal_dark_style_and_light_restoration(self):
        command = [sys.executable, str(SCRIPT_DIR / 'generate_colors_material.py'),
                   '--color', '#6750a4', '--termscheme',
                   str(SCRIPT_DIR / 'terminal/scheme-base.json'), '--blend_bg_fg']

        def generate(*args):
            result = subprocess.run(command + list(args), capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return dict(line.strip('$;').split(': ') for line in result.stdout.splitlines())

        standard = generate('--mode', 'dark')
        pure_black = generate('--mode', 'dark', '--dark-style', 'pure-black')
        self.assertEqual(pure_black['background'].lower(), '#000000')
        self.assertEqual(pure_black['term0'].lower(), '#000000')
        self.assertNotEqual(pure_black['onBackground'].lower(), '#000000')
        self.assertNotEqual(pure_black['surfaceContainerHigh'].lower(), '#000000')
        self.assertEqual(standard, generate('--mode', 'dark', '--dark-style', 'standard'))
        self.assertEqual(generate('--mode', 'light'),
                         generate('--mode', 'light', '--dark-style', 'pure-black'))


if __name__ == '__main__':
    unittest.main()
