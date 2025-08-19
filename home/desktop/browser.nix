{
  pkgs,
  lib,
  ...
}: {
  programs.chromium = rec {
    enable = true;
    package = pkgs.ungoogled-chromium; # extensions need to be manually fetched for ungoogled-chromium
    extensions = let
      browserVersion = lib.versions.major package.version;
      createChromiumExtension = {
        id,
        sha256,
        version,
      }: {
        inherit id;
        crxPath = builtins.fetchurl {
          url = "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=${browserVersion}&x=id%3D${id}%26installsource%3Dondemand%26uc";
          name = "${id}.crx";
          inherit sha256;
        };
        inherit version;
      };
    in [
      # proton pass
      (createChromiumExtension {
        id = "ghmbeldphafepmbegfdlkpapadhbakde";
        sha256 = "sha256:0l7wnsir3d2lp17zp34i8vk3a44zgd5z7rqnwbj211wh2zxrg693";
        version = "1.32.4";
      })

      # surfing keys
      (createChromiumExtension {
        id = "gfbliohnnapiefjpjlpjnehglfpaknnc";
        sha256 = "sha256:0iwb01s0ch1sia0vawndzn4kf0i65nvcn4q26gb8ljn0mvhk1vi4";
        version = "1.17.11";
      })
    ];
  };
}
