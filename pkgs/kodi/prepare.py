"""Prepare owned Kodi configuration before starting Kodi, preserving state."""
import datetime
import json
import os
from pathlib import Path
import shutil
import sys
import xml.etree.ElementTree as ET


def xml_value(value):
    return str(value).lower() if isinstance(value, bool) else str(value)


def prepare(config, data):
    data = Path(data)
    data.mkdir(parents=True, exist_ok=True)
    backup_root = data / 'nix-backups' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')

    # Upgrades can migrate databases (including RC updates). Preserve the profile before
    # touching settings, so rolling back Kodi does not lose watch history.
    if 'coreVersion' in config:
        marker = data / '.nix-core-version'
        version = str(config['coreVersion'])
        if not marker.is_file() or marker.read_text(encoding='utf-8') != version:
            userdata = data / 'userdata'
            if userdata.exists():
                backup_root.mkdir(parents=True, mode=0o700, exist_ok=True)
                os.chmod(backup_root, 0o700)
                shutil.copytree(userdata, backup_root / 'pre-upgrade-userdata', symlinks=True)
            temporary = data / '.nix-core-version.tmp'
            temporary.write_text(version, encoding='utf-8')
            temporary.replace(marker)

    def backup(path):
        if path.exists() or path.is_symlink():
            target = backup_root / path.relative_to(data)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), str(target))

    # User-installed copies must not shadow the immutable system add-ons.
    for addon in config['managedAddons']:
        backup(data / 'addons' / addon)
    # Retire the old writable skin/menu without discarding recoverable state.
    for relative in config.get('retiredProfilePaths', []):
        backup(data / relative)

    for relative, source in config.get('profileFiles', {}).items():
        target = data / relative
        content = Path(source).read_bytes()
        if not target.is_file() or target.read_bytes() != content:
            backup(target)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)

    settings_path = data / 'userdata/guisettings.xml'
    tree = ET.parse(settings_path) if settings_path.exists() else ET.ElementTree(ET.Element('settings', version='2'))
    root = tree.getroot()
    changed = False
    # Kodi requires these sections even before it has saved display/view state.
    for section in ('resolutions', 'viewstates'):
        if root.find(section) is None:
            ET.SubElement(root, section)
            changed = True
    for name, value in config['gui'].items():
        node = next((n for n in root.findall('setting') if n.get('id') == name), None)
        if node is None:
            node = ET.SubElement(root, 'setting', id=name)
            changed = True
        value = xml_value(value)
        if (node.text or '') != value or 'default' in node.attrib:
            node.text = value
            node.attrib.pop('default', None)
            changed = True
    if changed:
        backup(settings_path)
        settings_path.parent.mkdir(parents=True, exist_ok=True)
        ET.indent(tree)
        tree.write(settings_path, encoding='utf-8', xml_declaration=True)

    for source in config['mediaSources']:
        Path(source['path']).mkdir(parents=True, exist_ok=True)


if __name__ == '__main__':
    with open(sys.argv[1], encoding='utf-8') as handle:
        config = json.load(handle)
    data = os.environ.get('KODI_DATA', str(Path.home() / '.kodi'))
    prepare(config, data)
