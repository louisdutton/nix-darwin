"""Exercise module output, capture policy, defaults and schema compatibility."""
import json
from pathlib import Path
import sys

import jsonschema
import yaml

managed, generic, bundled, declarations, kodi_file, game_file = map(Path, sys.argv[1:])
settings = json.loads(declarations.read_text())

def read(path):
    return yaml.safe_load(path.read_text())

assert sorted(p.name for p in (managed / 'devices').iterdir()) == ['10-theatre-pro.yaml']
assert read(managed / 'devices/10-theatre-pro.yaml') == settings['devices']['10-theatre-pro']
assert read(managed / 'profiles/default.yaml') == settings['profiles']['kodi']
assert read(kodi_file) == read(managed / 'profiles/kodi.yaml')
assert read(game_file) == read(managed / 'profiles/game.yaml')
assert read(generic / 'profiles/default.yaml') == read(bundled / 'profiles/default.yaml')
assert not read(generic / 'devices/test.yaml')['options']['auto_manage']
assert read(generic / 'capability_maps/test.yaml')['id'] == 'nixos-module-test'
assert read(generic / 'capability_maps/test-v2.yaml')['version'] == 2
for directory in ('devices', 'capability_maps'):
    for original in (bundled / directory).iterdir():
        assert (generic / directory / original.name).read_bytes() == original.read_bytes()
for original in (bundled / 'capability_maps').iterdir():
    assert (managed / 'capability_maps' / original.name).read_bytes() == original.read_bytes()

# Controller invariants that must survive declarative refactors.
mapped = {entry['source_event']['gamepad']['button']: entry['target_events']
          for entry in read(game_file)['mapping']}
for source, target in [('East', 'South'), ('South', 'East'), ('North', 'North'), ('West', 'West')]:
    assert mapped[source] == [{'gamepad': {'button': target}}]
for trigger in ('LeftTrigger', 'RightTrigger'):
    assert mapped[trigger] == [{'gamepad': {'trigger': {'name': trigger}}}]
assert mapped['Guide'] == [{'keyboard': 'KeyF13'}]
assert read(managed / 'devices/10-theatre-pro.yaml')['options']['auto_manage']

# Independently compare generated output to the actual package schemas. This is
# a module regression check, not a validator in the service/build dependency path.
for tree in (managed, generic):
    for directory, schema_name in [('devices', 'composite_device'),
                                   ('profiles', 'device_profile'),
                                   ('capability_maps', 'capability_map')]:
        names = {'devices': ['10-theatre-pro' if tree == managed else 'test'],
                 'profiles': ['kodi', 'game'] if tree == managed else [],
                 'capability_maps': [] if tree == managed else ['test', 'test-v2']}[directory]
        for name in names:
            data = read(tree / directory / f'{name}.yaml')
            schema = read(bundled / 'schema' / f'{schema_name}_v{data["version"]}.json')
            jsonschema.validate(data, schema)
print('InputPlumber module: capture scope, profiles, bundled defaults and schema compatibility passed')
