{
  users = {
    louis.displayName = "Louis";
    hollie.displayName = "Hollie";
  };

  groups.family.members = ["louis" "hollie"];

  # Canonical collections belong to people or groups. Client devices are
  # metadata only and authenticate as their person.
  davCollections = {
    users = {
      louis.personal = {
        tag = "VCALENDAR";
        displayName = "Louis";
        components = ["VEVENT" "VTODO"];
      };
      louis.contacts = {
        tag = "VADDRESSBOOK";
        displayName = "Louis";
      };
      hollie.personal = {
        tag = "VCALENDAR";
        displayName = "Hollie";
        components = ["VEVENT" "VTODO"];
      };
      hollie.contacts = {
        tag = "VADDRESSBOOK";
        displayName = "Hollie";
      };
    };
    groups.family = {
      family = {
        tag = "VCALENDAR";
        displayName = "Family";
        components = ["VEVENT" "VTODO"];
      };
      contacts = {
        tag = "VADDRESSBOOK";
        displayName = "Family";
      };
    };
  };
}
