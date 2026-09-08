import json
from pathlib import Path
import subprocess
import sys
import unittest
from midnight import midnight_color


SCRIPT_DIR = Path(__file__).resolve().parent


class MidnightTest(unittest.TestCase):
    def test_all_palettes_match_matugen_and_keep_readable_surfaces(self):
        for palette in ('content', 'expressive', 'fidelity', 'fruit-salad', 'monochrome',
                        'neutral', 'rainbow', 'tonal-spot', 'vibrant'):
            with self.subTest(palette=palette):
                command = ['matugen', '--dry-run', '--json', 'hex', '--type',
                           f'scheme-{palette}', 'color', 'hex', '#6750a4']
                standard = json.loads(subprocess.check_output(command))['colors']
                midnight = json.loads(subprocess.check_output(
                    command + ['--lightness-dark', '-0.1']))['colors']
                self.assertEqual(midnight['background']['dark']['color'], '#000000')
                self.assertNotEqual(midnight['surface_container_high']['dark']['color'], '#000000')
                for role in standard:
                    self.assertEqual(standard[role]['light'], midnight[role]['light'])
                    if role == 'source_color':
                        self.assertEqual(standard[role], midnight[role])
                        continue
                    expected = midnight[role]['dark']['color']
                    actual = midnight_color(standard[role]['dark']['color'])
                    for index in (1, 3, 5):
                        self.assertLessEqual(abs(int(actual[index:index + 2], 16)
                                                 - int(expected[index:index + 2], 16)), 1)
                channels = [int(midnight['on_background']['dark']['color'][i:i + 2], 16) / 255
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
        midnight = generate('--mode', 'dark', '--dark-style', 'midnight')
        self.assertEqual(midnight['background'].lower(), '#000000')
        self.assertEqual(midnight['term0'].lower(), '#000000')
        self.assertNotEqual(midnight['onBackground'].lower(), '#000000')
        self.assertNotEqual(midnight['surfaceContainerHigh'].lower(), '#000000')
        self.assertEqual(standard, generate('--mode', 'dark', '--dark-style', 'standard'))
        self.assertEqual(generate('--mode', 'light'),
                         generate('--mode', 'light', '--dark-style', 'midnight'))


if __name__ == '__main__':
    unittest.main()
