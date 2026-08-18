{...}: {
  programs.ssh = {
    enable = true;
    matchBlocks.mini = {
      hostname = "10.70.0.1";
      user = "louis";
    };
    matchBlocks.ama = {
      hostname = "145.241.232.132";
      user = "ubuntu";
    };
  };
}
