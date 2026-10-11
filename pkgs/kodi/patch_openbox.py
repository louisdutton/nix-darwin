"""Hide only Steam's library window, not game or authentication windows."""
import sys
import xml.etree.ElementTree as ET


def configure_openbox(source, output, home_command=None):
    tree = ET.parse(source)
    root = tree.getroot()
    namespace = root.tag.split('}')[0][1:] if root.tag.startswith('{') else ''
    if namespace:
        ET.register_namespace('', namespace)
    def tag(name):
        return '{' + namespace + '}' + name if namespace else name
    if home_command:
        keyboard = root.find(tag('keyboard'))
        if keyboard is None:
            keyboard = ET.SubElement(root, tag('keyboard'))
        binding = ET.SubElement(keyboard, tag('keybind'), {'key': 'F13'})
        action = ET.SubElement(binding, tag('action'), {'name': 'Execute'})
        ET.SubElement(action, tag('command')).text = home_command
    applications = root.find(tag('applications'))
    if applications is None:
        applications = ET.SubElement(root, tag('applications'))
    for window_class in ('Steam', 'steam'):
        rule = ET.SubElement(applications, tag('application'),
                             {'class': window_class, 'title': 'Steam', 'type': 'normal'})
        for name, value in [('focus', 'no'), ('iconic', 'yes'),
                            ('skip_taskbar', 'yes'), ('skip_pager', 'yes')]:
            ET.SubElement(rule, tag(name)).text = value
    ET.indent(tree)
    tree.write(output, encoding='utf-8', xml_declaration=True)


if __name__ == '__main__':
    configure_openbox(*sys.argv[1:4])
