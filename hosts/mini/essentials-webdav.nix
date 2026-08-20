{
  config,
  lib,
  pkgs,
  ...
}: let
  identities = import ./essentials-identities.nix;
  interface = "wg0";
  listenAddress = "10.70.0.1";
  port = 8091;
  serviceUser = "essentials-webdav";
  louisDataDir = "/home/louis/.local/share/essentials";
  louisConfigDir = "/home/louis/.config/essentials";
  hollieDataDir = "/home/hollie/.local/share/essentials";
  hollieConfigDir = "/home/hollie/.config/essentials";
  sharedDir = "/srv/essentials/family";
  stateDir = "/var/lib/essentials-webdav";
  authFile = config.sops.secrets."essentials-webdav/htpasswd".path;
  deviceNames = lib.attrNames identities.devices;
  legacyDeviceNames = lib.attrNames identities.legacyWebdavDevices;
  devicesForUser = user:
    lib.filter (
      device:
        identities.devices.${device}.user == user
    ) deviceNames;
  legacyDevicesForUser = user:
    lib.filter (
      device:
        lib.elem user identities.legacyWebdavDevices.${device}.privateUsers
    ) legacyDeviceNames;
  devicesForGroup = group:
    lib.filter (
      device:
        lib.elem group identities.devices.${device}.groups
    ) deviceNames;
  legacyDevicesForGroup = group:
    lib.filter (
      device:
        lib.elem group identities.legacyWebdavDevices.${device}.groups
    ) legacyDeviceNames;
  members = values: lib.concatStringsSep " " values;
  authGroupFile = pkgs.writeText "essentials-webdav-groups" ''
    louis-private: ${members (devicesForUser "louis" ++ legacyDevicesForUser "louis")}
    hollie-private: ${members (devicesForUser "hollie" ++ legacyDevicesForUser "hollie")}
    family: ${members (devicesForGroup "family" ++ legacyDevicesForGroup "family")}
  '';
  davDirectory = url: directory: group: ''
    Alias "${url}/" "${directory}/"
    <Directory "${directory}">
      Dav On
      FileETag Digest
      Options None
      AllowOverride None
      AuthType Basic
      AuthName "Essentials"
      AuthBasicProvider file
      AuthUserFile "${authFile}"
      AuthGroupFile "${authGroupFile}"
      Require group ${group}
    </Directory>
  '';
in {
  assertions = [
    {
      assertion = lib.versionAtLeast (lib.getVersion pkgs.apacheHttpd) "2.4.68";
      message = "Essentials WebDAV requires Apache HTTP Server 2.4.68 or newer.";
    }
    {
      assertion = lib.all (
        group: lib.all (user: lib.hasAttr user identities.users) group.members
      ) (lib.attrValues identities.groups);
      message = "Every Essentials group member must be a declared user.";
    }
    {
      assertion = lib.all (
        device:
          lib.hasAttr device.user identities.users
          && lib.all (group: lib.hasAttr group identities.groups) device.groups
      ) (lib.attrValues identities.devices);
      message = "Every Essentials device must reference a declared user and group.";
    }
    {
      assertion = lib.all (
        device:
          lib.all (user: lib.hasAttr user identities.users) device.privateUsers
          && lib.all (group: lib.hasAttr group identities.groups) device.groups
      ) (lib.attrValues identities.legacyWebdavDevices);
      message = "Every legacy WebDAV ACL must reference a declared user and group.";
    }
  ];

  sops.secrets."essentials-webdav/htpasswd" = {
    owner = serviceUser;
    group = "radicale";
    mode = "0440";
    restartUnits = ["httpd.service" "radicale.service"];
  };

  users.groups.${serviceUser} = {};
  users.users.${serviceUser} = {
    isSystemUser = true;
    group = serviceUser;
  };
  users.groups.essentials-family = {};
  users.users.louis = {
    extraGroups = ["essentials-family"];
    # The group mode bit is the ACL mask; the owning group remains denied.
    homeMode = "710";
  };
  users.groups.hollie = {};
  users.users.hollie = {
    isNormalUser = true;
    description = identities.users.hollie.displayName;
    group = "hollie";
    extraGroups = ["essentials-family"];
    home = "/home/hollie";
    createHome = true;
    homeMode = "710";
    hashedPassword = "!";
    shell = lib.getExe' pkgs.shadow "nologin";
  };

  systemd.tmpfiles.rules = [
    "d ${louisDataDir} 0700 louis users - -"
    "d ${louisConfigDir} 0700 louis users - -"
    "d /home/hollie/.local 0700 hollie hollie - -"
    "d /home/hollie/.local/share 0700 hollie hollie - -"
    "d /home/hollie/.config 0700 hollie hollie - -"
    "d ${hollieDataDir} 0700 hollie hollie - -"
    "d ${hollieConfigDir} 0700 hollie hollie - -"
    "d ${sharedDir} 2770 root essentials-family - -"
    "d ${stateDir} 0700 ${serviceUser} ${serviceUser} - -"
    "a+ /home/louis - - - - g::---,m::--x,u:${serviceUser}:--x"
    "a+ /home/louis/.local - - - - g::---,m::--x,u:${serviceUser}:--x"
    "a+ /home/louis/.local/share - - - - g::---,m::--x,u:${serviceUser}:--x"
    "a+ /home/louis/.config - - - - g::---,m::--x,u:${serviceUser}:--x"
    "A+ ${louisDataDir} - - - - m::rwx,u:${serviceUser}:rwX"
    "a+ ${louisDataDir} - - - - d:m::rwx,d:u:${serviceUser}:rwx,d:u:louis:rwx"
    "A+ ${louisConfigDir} - - - - m::rwx,u:${serviceUser}:rwX"
    "a+ ${louisConfigDir} - - - - d:m::rwx,d:u:${serviceUser}:rwx,d:u:louis:rwx"
    "a+ /home/hollie - - - - g::---,m::--x,u:${serviceUser}:--x"
    "a+ /home/hollie/.local - - - - g::---,m::--x,u:${serviceUser}:--x"
    "a+ /home/hollie/.local/share - - - - g::---,m::--x,u:${serviceUser}:--x"
    "a+ /home/hollie/.config - - - - g::---,m::--x,u:${serviceUser}:--x"
    "A+ ${hollieDataDir} - - - - m::rwx,u:${serviceUser}:rwX"
    "a+ ${hollieDataDir} - - - - d:m::rwx,d:u:${serviceUser}:rwx,d:u:hollie:rwx"
    "A+ ${hollieConfigDir} - - - - m::rwx,u:${serviceUser}:rwX"
    "a+ ${hollieConfigDir} - - - - d:m::rwx,d:u:${serviceUser}:rwx,d:u:hollie:rwx"
    "A+ ${sharedDir} - - - - m::rwx,u:${serviceUser}:rwX,g:essentials-family:rwX"
    "a+ ${sharedDir} - - - - d:m::rwx,d:u:${serviceUser}:rwx,d:g:essentials-family:rwx"
  ];

  services.httpd = {
    enable = true;
    user = serviceUser;
    group = serviceUser;
    logFormat = "common";
    extraConfig = ''
      DavLockDB ${stateDir}/DavLock
    '';
    virtualHosts."essentials-webdav" = {
      hostName = "essentials-webdav";
      http2 = false;
      listen = [
        {
          ip = listenAddress;
          inherit port;
        }
      ];
      extraConfig = ''
        ${davDirectory "/users/louis/data" louisDataDir "louis-private"}
        ${davDirectory "/users/louis/config" louisConfigDir "louis-private"}
        ${davDirectory "/users/hollie/data" hollieDataDir "hollie-private"}
        ${davDirectory "/users/hollie/config" hollieConfigDir "hollie-private"}
        ${davDirectory "/shared/family" sharedDir "family"}
      '';
    };
  };

  systemd.services.httpd = {
    after = ["wireguard-${interface}.service"];
    requires = ["wireguard-${interface}.service"];
    serviceConfig = {
      AmbientCapabilities = lib.mkForce [];
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = false;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        louisDataDir
        louisConfigDir
        hollieDataDir
        hollieConfigDir
        sharedDir
        stateDir
        config.services.httpd.logDir
      ];
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      RestrictSUIDSGID = true;
      UMask = "0007";
    };
  };

  networking.firewall.interfaces.${interface}.allowedTCPPorts = [port];
}
