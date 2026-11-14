{
  pkgs,
  interfaceConfig,
}:
pkgs.testers.runNixOSTest {
  name = "theatre-wireguard-recovery";

  nodes.machine = {lib, ...}: {
    # Exercise theatre's peer settings with a disposable key and deterministic
    # hostname lookup. No provider credentials or reachable peer are needed.
    networking.wireguard.interfaces.wg0 =
      interfaceConfig
      // {
        privateKeyFile = null;
        privateKey = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE=";
        peers = map (peer: peer // {name = "mini";}) interfaceConfig.peers;
      };
    system.nssDatabases.hosts = lib.mkForce ["files"];
  };

  testScript = ''
    start_all()
    unit = "wireguard-wg0-peer-mini-refresh.service"

    def restarts():
        return int(machine.succeed(f"systemctl show {unit} -p NRestarts --value"))

    def recovered(address):
        machine.wait_until_succeeds(
            f"wg show wg0 endpoints | grep -F '{address}:51820'", timeout=60
        )
        machine.wait_until_succeeds(
            "ip route get 10.70.0.2 | grep -F 'dev wg0 src 10.70.0.3'", timeout=30
        )

    with subtest("retry startup when the endpoint hostname is unavailable"):
        machine.wait_for_unit("multi-user.target")
        machine.wait_until_succeeds(
            f"test $(systemctl show {unit} -p NRestarts --value) -ge 2", timeout=45
        )
        machine.succeed("systemctl is-active wireguard-wg0.service")
        machine.fail("ip route get 10.70.0.2 | grep -F 'dev wg0'")
        machine.succeed(
            "cp /etc/hosts /tmp/wg-hosts; "
            "echo '192.0.2.1 mini.lan' >> /tmp/wg-hosts; "
            "mount --bind /tmp/wg-hosts /etc/hosts"
        )
        recovered("192.0.2.1")

    with subtest("refresh an endpoint after its address changes"):
        machine.succeed(
            "sed 's/192.0.2.1/192.0.2.2/' /tmp/wg-hosts > /tmp/wg-hosts-next; "
            "cat /tmp/wg-hosts-next > /tmp/wg-hosts"
        )
        recovered("192.0.2.2")

    with subtest("recover the peer and routes after a later lookup failure"):
        previous_restarts = restarts()
        machine.succeed(
            "grep -v mini.lan /tmp/wg-hosts > /tmp/wg-hosts-next; "
            "cat /tmp/wg-hosts-next > /tmp/wg-hosts"
        )
        machine.wait_until_succeeds(
            f"test $(systemctl show {unit} -p NRestarts --value) -gt {previous_restarts}",
            timeout=60,
        )
        machine.succeed("echo '192.0.2.2 mini.lan' >> /tmp/wg-hosts")
        recovered("192.0.2.2")
  '';
}
