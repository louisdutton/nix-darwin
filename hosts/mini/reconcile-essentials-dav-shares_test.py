import csv
import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).with_name("reconcile-essentials-dav-shares.py")
SPEC = importlib.util.spec_from_file_location("reconcile_dav", SCRIPT)
assert SPEC and SPEC.loader
reconcile_dav = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reconcile_dav)

IDENTITIES = {
    "users": {"alice": {"displayName": "Alice"}, "bob": {"displayName": "Bob"}},
    "groups": {"family": {"members": ["alice", "bob"]}},
    "davCollections": {
        "users": {
            "alice": {
                "personal": {
                    "tag": "VCALENDAR",
                    "displayName": "Alice",
                    "components": ["VEVENT", "VTODO"],
                },
                "contacts": {"tag": "VADDRESSBOOK", "displayName": "Alice — Private"},
            },
            "bob": {"personal": {"tag": "VCALENDAR", "displayName": "Bob — Private"}},
        },
        "groups": {"family": {
            "calendar": {"tag": "VCALENDAR", "displayName": "Family"},
            "contacts": {"tag": "VADDRESSBOOK", "displayName": "Family"},
        }},
    },
}


class ReconcileTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.storage = Path(self.temporary.name) / "collections"
        self.database = self.storage / "collection-db" / "sharing.csv"

    def tearDown(self):
        self.temporary.cleanup()

    def rows(self):
        with self.database.open(newline="", encoding="utf-8") as source:
            return list(csv.DictReader(source, delimiter=";"))

    @mock.patch.object(reconcile_dav.time, "time", return_value=1234)
    def test_creates_canonical_collections_and_person_maps(self, _time):
        reconcile_dav.reconcile(IDENTITIES, self.storage, self.database)
        props = json.loads((self.storage / "collection-root/alice/personal/.Radicale.props").read_text())
        self.assertEqual({
            "C:supported-calendar-component-set": "VEVENT,VTODO",
            "D:displayname": "Alice",
            "tag": "VCALENDAR",
        }, props)
        mappings = {row["PathOrToken"]: row for row in self.rows()}
        self.assertEqual({
            "/alice/family-calendar/", "/alice/family-contacts/",
            "/bob/family-calendar/", "/bob/family-contacts/",
        }, set(mappings))
        family = mappings["/alice/family-calendar/"]
        self.assertEqual("/family/calendar/", family["PathMapped"])
        self.assertEqual("family", family["Owner"])
        self.assertEqual("alice", family["User"])
        self.assertEqual("rw", family["Permissions"])
        self.assertEqual("True", family["EnabledByOwner"])
        self.assertEqual("False", family["HiddenByUser"])

    @mock.patch.object(reconcile_dav.time, "time", side_effect=[100, 200, 300])
    def test_is_idempotent_and_revokes_removed_memberships(self, _time):
        reconcile_dav.reconcile(IDENTITIES, self.storage, self.database)
        original = self.rows()[0]
        reconcile_dav.reconcile(IDENTITIES, self.storage, self.database)
        unchanged = self.rows()[0]
        self.assertEqual(original["TimestampCreated"], unchanged["TimestampCreated"])
        self.assertEqual(original["TimestampUpdated"], unchanged["TimestampUpdated"])
        without_members = copy.deepcopy(IDENTITIES)
        without_members["groups"]["family"]["members"] = []
        reconcile_dav.reconcile(without_members, self.storage, self.database)
        self.assertEqual([], self.rows())
        self.assertTrue((self.storage / "collection-root/alice/personal").is_dir())

    def test_preserves_properties_and_contents(self):
        collection = self.storage / "collection-root/alice/personal"
        collection.mkdir(parents=True)
        (collection / "event.ics").write_text("calendar data")
        (collection / ".Radicale.props").write_text(json.dumps({"ICAL:calendar-color": "#123456"}))
        reconcile_dav.reconcile(IDENTITIES, self.storage, self.database)
        props = json.loads((collection / ".Radicale.props").read_text())
        self.assertEqual("#123456", props["ICAL:calendar-color"])
        self.assertEqual("calendar data", (collection / "event.ics").read_text())

    def test_rejects_unsafe_names(self):
        invalid = copy.deepcopy(IDENTITIES)
        invalid["users"]["../escape"] = {"displayName": "Escape"}
        with self.assertRaisesRegex(ValueError, "invalid user name"):
            reconcile_dav.reconcile(invalid, self.storage, self.database)


if __name__ == "__main__":
    unittest.main()
