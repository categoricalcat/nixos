# Modular WireGuard peer management
{ lib, ... }:

let
  # Define peer configurations in a structured way
  peers = {
    fuyidong = {
      publicKey = "lGriY6UJK7M4O9oOq/JBHM6/HXTUx5pX/VH97Cs2njo=";
      ip = "10.100.0.2";
      description = "fuyidong mobile device";
      allowedSubnets = [ "10.100.0.0/24" ];
    };

    fuchuang = {
      publicKey = "aDcV7ZGtQTg/0twxpObeU1FM+nBFgD9wlYQ8Txygf3U=";
      ip = "10.100.0.3";
      description = "fuchuang wsl";
      allowedSubnets = [ "10.100.0.0/24" ];
    };

    reserved = {
      publicKey = "t3grmFcOy3IaqAEKSJawBO2SnUPMeCTjeAg";
      ip = "10.100.0.4";
      description = "router";
      allowedSubnets = [ "10.100.0.0/24" ];
    };

    # Template for adding new peers:
    # peerName = {
    #   publicKey = "base64-encoded-public-key";
    #   ip = "10.100.0.X";  # Choose next available IP
    #   description = "Device/user description";
    #   allowedSubnets = [
    #     "10.100.X.0/24"  # Optional: peer-specific subnet
    #   ];
    # };
  };

  # Convert peer definitions to WireGuard configuration format
  mkPeerConfig = _name: peer: {
    inherit (peer) publicKey;
    allowedIPs = [ "${peer.ip}/32" ] ++ peer.allowedSubnets;
    keepalive = 25;
  };

  # Generate peer configurations
  peerConfigs = lib.mapAttrsToList mkPeerConfig peers;

in
{
  # Export for use in addresses.nix
  _module.args.wireguardPeers = {
    inherit peers peerConfigs;

    # Helper functions
    nextAvailableIP =
      let
        usedIPs = lib.mapAttrsToList (_: peer: lib.toInt (lib.last (lib.splitString "." peer.ip))) peers;
        maxIP = lib.foldl' lib.max 1 usedIPs; # Start from 1 (server is .1)
      in
      "10.100.0.${toString (maxIP + 1)}";

    # Documentation generator
    peerTable = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: peer:
        "| ${name} | ${peer.ip} | ${peer.description} | `${lib.substring 0 16 peer.publicKey}...` |"
      ) peers
    );
  };
}
