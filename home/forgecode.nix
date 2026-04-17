{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.programs.forge-code;
  jsonFormat = pkgs.formats.json {};

  # transform programs.mcp servers into forge's format
  mkMcpServer = server:
    (removeAttrs server ["disabled"])
    // (lib.optionalAttrs (server ? url) {type = "http";})
    // (lib.optionalAttrs (server ? command) {type = "stdio";})
    // {disable = server.disabled or false;};

  transformedMcpServers =
    lib.optionalAttrs
    (cfg.enableMcpIntegration && config.programs.mcp.enable)
    (lib.mapAttrs (_name: mkMcpServer) config.programs.mcp.servers);

  # forge-specific servers take precedence over shared mcp servers
  mergedMcpServers = transformedMcpServers // cfg.mcpServers;

  mcpConfig = {mcpServers = mergedMcpServers;};
in {
  options.programs.forge-code = {
    enable = lib.mkEnableOption "Forge Code AI coding agent";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The forge-code package to install.";
    };

    enableMcpIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to integrate with programs.mcp shared server definitions.";
    };

    mcpServers = lib.mkOption {
      type = jsonFormat.type;
      default = {};
      description = "Forge Code-specific MCP server definitions (merged with programs.mcp if enabled).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    # forge expects its mcp config at ~/forge/.mcp.json
    home.file."forge/.mcp.json" = lib.mkIf (mergedMcpServers != {}) {
      source = jsonFormat.generate "forge-mcp.json" mcpConfig;
    };
  };
}
