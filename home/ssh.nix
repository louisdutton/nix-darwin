{...}: {
  programs.ssh = {
    enable = true;
    matchBlocks."mini-wg" = {
      hostname = "10.70.0.1";
      user = "louis";
    };
  };
}
