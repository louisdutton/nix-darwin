{
  users = {
    louis.displayName = "Louis";
    hollie.displayName = "Hollie";
  };

  groups.family.members = ["louis" "hollie"];

  # Canonical Radicale collections published through device-specific principals.
  # Explicit lists prevent test or administrative collections from appearing in
  # automatic DAV discovery.
  davCollections = {
    users = {
      louis.personal = {
        tag = "VCALENDAR";
        displayName = "Louis — Private";
      };
      louis.contacts = {
        tag = "VADDRESSBOOK";
        displayName = "Louis — Private";
      };
      hollie.personal = {
        tag = "VCALENDAR";
        displayName = "Hollie — Private";
      };
      hollie.contacts = {
        tag = "VADDRESSBOOK";
        displayName = "Hollie — Private";
      };
    };
    groups.family = {
      family = {
        tag = "VCALENDAR";
        displayName = "Family";
      };
      contacts = {
        tag = "VADDRESSBOOK";
        displayName = "Family";
      };
    };
  };

  # Add a device here only when it has its own push token and WebDAV password.
  # Device labels are public identifiers; secrets remain in SOPS.
  devices = {
    hollie-pixel-8a = {
      user = "hollie";
      groups = ["family"];
    };
    louis-pixel-8 = {
      user = "louis";
      groups = ["family"];
    };
  };

  legacyWebdavDevices = {};
}
