"""Validate the standalone skin's references and expanded Home navigation."""
import copy
from pathlib import Path
import re
import sys
import unittest
import xml.etree.ElementTree as ET

SKIN = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / 'config/kodi/skin.theatre'


class SkinTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.trees = {p.name: ET.parse(p).getroot() for p in (SKIN / '1080i').glob('*.xml')}
        cls.definitions = {n.get('name'): n for root in cls.trees.values()
                           if root.tag == 'includes' for n in root if n.get('name')}

    def expand(self, node, params=None, stack=()):
        params = params or {}
        node = copy.deepcopy(node)

        def substitute(value):
            return re.sub(r'\$PARAM\[([^]]+)\]', lambda m: params.get(m[1], m[0]), value)

        for n in node.iter():
            if n.text:
                n.text = substitute(n.text)
            n.attrib = {k: substitute(v) for k, v in n.attrib.items()}
        for parent in list(node.iter()):
            for child in list(parent):
                if child.tag != 'include' or child.get('name') or child.get('file'):
                    continue
                name = child.get('content') or (child.text or '').strip()
                self.assertIn(name, self.definitions, f'Missing include {name}')
                self.assertNotIn(name, stack, f'Recursive include {name}')
                definition = self.definitions[name]
                values = {p.get('name'): p.get('default', '') for p in definition.findall('param')}
                values.update({p.get('name'): p.get('value', p.text or '') for p in child.findall('param')})
                content = definition.find('definition')
                content = content if content is not None else definition
                expanded = self.expand(content, values, stack + (name,))
                index = list(parent).index(child)
                parent.remove(child)
                for n in list(expanded):
                    if n.tag != 'param':
                        parent.insert(index, n)
                        index += 1
        return node

    def test_independent_identity_and_dependencies(self):
        addon = ET.parse(SKIN / 'addon.xml').getroot()
        self.assertEqual(addon.get('id'), 'skin.theatre')
        self.assertEqual({n.get('addon') for n in addon.findall('requires/import')},
                         {'xbmc.gui', 'plugin.program.localhome'})
        text = '\n'.join(ET.tostring(n, encoding='unicode') for n in self.trees.values())
        for obsolete in ('skinshortcuts', 'script.', 'plugin.video.', 'Skin.HasSetting', 'Skin.String', 'skin.arctic.'):
            self.assertNotIn(obsolete, text)
        self.assertTrue((SKIN / 'LICENSE.txt').is_file())

    def test_include_variable_and_font_references(self):
        fonts = {n.text for n in self.trees['Font.xml'].findall('.//font/name')}
        for filename, root in self.trees.items():
            for n in root.iter():
                if n.tag == 'include' and n.get('file'):
                    self.assertIn(n.get('file'), self.trees, filename)
                if n.tag == 'include' and not n.get('name') and not n.get('file'):
                    name = n.get('content') or (n.text or '').strip()
                    if '$PARAM' not in name:
                        self.assertIn(name, self.definitions, filename)
                if n.tag == 'font' and n.text and n.text.strip() and '$' not in n.text:
                    self.assertIn(n.text, fonts, filename)
                if n.tag == 'animation' and (n.get('type') or n.text or '').strip() == 'Conditional':
                    self.assertTrue(n.get('condition'), f'{filename}: unconditional Conditional animation')
                for text in [n.text or '', *n.attrib.values()]:
                    for name in re.findall(r'\$(?:VAR|EXP)\[([^\],]+)', text):
                        if '$PARAM' not in name:
                            self.assertIn(name, self.definitions, filename)
                    for asset in re.findall(r'(?:special://skin/)?(extras/[^\s<>\[\]]+\.png)', text):
                        self.assertTrue((SKIN / asset).is_file(), f'{filename}: {asset}')
        for name in self.trees['Font.xml'].findall('.//filename'):
            self.assertTrue((SKIN / 'fonts' / name.text).is_file(), name.text)

    def test_home_has_fixed_navigation_and_full_bleed_continue(self):
        home = self.expand(self.trees['Home.xml'])
        ids = [n.get('id') for n in home.findall('.//control[@id]')]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue({'301', '30111', '30113', '3011199', '3011399'} <= set(ids))
        self.assertNotIn('30112', ids)
        self.assertEqual(home.find(".//control[@id='301']").get('type'), 'group')
        row = home.find(".//control[@id='30111']")
        nav = home.find(".//control[@id='30113']")
        self.assertIn('section=continue', row.findtext('content'))
        self.assertEqual(row.findtext('onup'), '30111')
        self.assertFalse(nav.findall('ondown'))
        self.assertEqual([n.findtext('texture') for n in nav.findall("control[@type='image']")],
                         ['localhome/bumper-left.png', 'localhome/bumper-right.png'])
        tabs = nav.findall("control[@type='togglebutton']")
        self.assertEqual([n.findtext('label') for n in tabs], ['Home', 'Videos', 'Games'])
        for tab in tabs:
            self.assertEqual(tab.findtext('enable'), 'false')
            self.assertIsNone(tab.find('onclick'))
            self.assertEqual(tab.findtext('width'), 'auto')
            self.assertEqual(tab.findtext('textoffsetx'), '0')
            self.assertEqual(tab.findtext('alttexturefocus'), 'localhome/tab-underline.png')
        heading = home.find(".//control[@id='3011199']/control[@type='grouplist']")
        self.assertIsNone(heading.find("control[@type='image']"))
        self.assertEqual(home.find(".//control[@id='3011199']").findtext('bottom'), '100')
        left, width = int(row.findtext('left')), int(row.findtext('width'))
        self.assertLessEqual(left, 0)
        self.assertGreaterEqual(left + width, 1920)
        self.assertEqual(left + int(row.findtext('focusposition')) * int(row.find('itemlayout').get('width')), 70)
        self.assertEqual(row.findtext('movement'), '0')

    def test_grid_extends_to_footer_and_focus_border_is_not_dimmed(self):
        home = self.expand(self.trees['Home.xml'])
        for id in ('30121', '30122'):
            panel = home.find(".//control[@id='" + id + "']")
            top, height = int(panel.findtext('top')), int(panel.findtext('height'))
            self.assertEqual(top + height, 1080 - 72)
            self.assertGreater(height, 2 * int(panel.find('itemlayout').get('height')))
            def check_alpha(node, dimmed=False):
                dimmed |= any('LocalHome.Installed' in n.get('condition', '') for n in node.findall('animation'))
                if node.tag == 'texture' and node.text in ('common/selectbox.png', 'common/gradient-selectbox.png'):
                    self.assertFalse(dimmed, 'Uninstalled artwork must not dim its focus border')
                for child in node:
                    check_alpha(child, dimmed)
            check_alpha(panel.find('focusedlayout'))

    def test_native_library_and_playback_controls(self):
        for name in ('MyVideoNav.xml', 'MyPrograms.xml'):
            root = self.expand(self.trees[name])
            self.assertIsNotNone(root.find(".//control[@id='610']"))
            self.assertEqual(root.findtext('views'), '50,610')
        osd = self.trees['VideoOSD.xml']
        self.assertTrue({'13', '14', '15'} <= {n.get('id') for n in osd.findall('.//control[@id]')})
        for window in ('DialogKeyboard.xml', 'DialogSettings.xml', 'DialogGameControllers.xml',
                       'SettingsCategory.xml', 'DialogSelect.xml', 'DialogButtonMenu.xml'):
            self.assertIn(window, self.trees)
        self.assertEqual(self.trees['Startup.xml'].findtext('onload'), 'ReplaceWindow(Home)')

    def test_content_readiness_replaces_timed_transitions(self):
        home = self.expand(self.trees['Home.xml'])
        for control, section in [('30121', 'library'), ('30122', 'games')]:
            panel = home.find(".//control[@id='" + control + "']")
            self.assertIn('section=' + section, panel.findtext('content'))
            self.assertIn('widget=1', panel.findtext('content'))
            self.assertIsNone(panel.find('visible'))
        actions = [n.text or '' for n in home.findall('.//onclick')]
        self.assertFalse(any('ReplaceWindow' in action or 'ActivateWindow' in action for action in actions))
        for filename, root in self.trees.items():
            for node in root.iter():
                if node.tag == 'animation':
                    event = (node.get('type') or node.text or '').strip()
                    self.assertNotIn(event, ('WindowOpen', 'WindowClose', 'Visible', 'Hidden', 'Focus', 'Unfocus'), filename)
                    if filename == 'Home.xml' and node.get('effect') == 'slide':
                        self.assertEqual(node.get('time'), '160')
                        self.assertEqual(node.get('end'), '0,0')
                        self.assertIn(node.get('start'), ('48,0', '-48,0'))
                        self.assertIn('LocalHome.PageMotion', node.get('condition'))
                        self.assertEqual(node.get('reversible'), 'false')
                    else:
                        self.assertEqual(node.get('time', '0'), '0', filename)
                    self.assertEqual(node.get('delay', '0'), '0', filename)
                if node.tag == 'effect':
                    self.assertEqual(node.get('time', '0'), '0', filename)
                    self.assertEqual(node.get('delay', '0'), '0', filename)
                if node.tag == 'fadetime':
                    self.assertEqual(node.text, '0', filename)
                if node.tag in ('texture', 'imagepath'):
                    self.assertNotEqual(node.get('background'), 'true', filename)

    def test_button_prompts_are_shared_display_only_and_reserve_space(self):
        passive = {'Startup.xml', 'VideoFullScreen.xml', 'DialogBusy.xml',
                   'DialogVolumeBar.xml', 'DialogSeekBar.xml', 'DialogNotification.xml', 'Pointer.xml'}
        for filename, root in self.trees.items():
            if root.tag != 'window':
                continue
            expanded = self.expand(root)
            bar = expanded.find(".//control[@id='30900']")
            if filename in passive:
                self.assertIsNone(bar, filename)
                continue
            self.assertIsNotNone(bar, filename)
            self.assertEqual(bar.findtext('height'), '72')
            ids = {control.get('id') for control in bar.findall('.//control')}
            self.assertFalse({'30901', '30906', '30907', '30908'} & ids, filename)
            self.assertEqual(bar.find(".//control[@id='30911']//texture").text, 'localhome/prompt-home.png')
            self.assertTrue(all(control.get('type') in ('group', 'grouplist', 'image', 'label')
                                for control in bar.findall('.//control')), filename)
            for texture in bar.findall('.//texture'):
                if (texture.text or '').startswith('localhome/'):
                    self.assertTrue((SKIN / 'media' / texture.text.replace('.png', '.svg')).is_file())
        for node in self.trees['Includes_ButtonPrompts.xml'].iter():
            for condition in [node.get('condition', ''), node.text or '' if node.tag in ('expression', 'visible') else '']:
                depth = 0
                for char in condition:
                    depth += (char == '[') - (char == ']')
                    self.assertGreaterEqual(depth, 0, condition)
                self.assertEqual(depth, 0, condition)
        osd = self.expand(self.trees['VideoOSD.xml'])
        for control in ('13', '14', '15'):
            button = osd.find(".//control[@id='" + control + "']")
            self.assertLessEqual(int(button.findtext('top')) + int(button.findtext('height')), 1008)

    def test_parameter_expansion_resolves_native_window_variables(self):
        for filename, root in self.trees.items():
            if root.tag != 'window':
                continue
            expanded = self.expand(root)
            for node in expanded.iter():
                for text in [node.text or '', *node.attrib.values()]:
                    for name in re.findall(r'\$(?:VAR|EXP)\[([^\],]+)', text):
                        if '$PARAM' not in name:
                            self.assertIn(name, self.definitions, f'{filename}: {name}')


if __name__ == '__main__':
    unittest.main()
