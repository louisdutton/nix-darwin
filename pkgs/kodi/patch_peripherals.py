"""Leave HDMI-CEC ownership to the TV CLI, not Kodi's remote-input thread."""
import sys
import xml.etree.ElementTree as ET


def patch(path):
    tree = ET.parse(path)
    settings = tree.findall("./peripheral[@bus='cec']/setting[@key='enabled']")
    if len(settings) != 1:
        raise RuntimeError('Kodi CEC defaults changed; review adapter ownership')
    settings[0].set('value', '0')
    tree.write(path, encoding='utf-8', xml_declaration=True)


if __name__ == '__main__':
    patch(sys.argv[1])
