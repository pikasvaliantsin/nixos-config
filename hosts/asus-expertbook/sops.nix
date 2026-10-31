# nixos-config/hosts/asus-expertbook/sops.nix
{
  inputs,
  lib,
  ...
}:

let
  hasKeyFile = lib.pathExists "/var/lib/sops-nix/key.txt";
  hasSshEd25519 = lib.pathExists "/etc/ssh/ssh_host_ed25519_key";
  hasSshRsa = lib.pathExists "/etc/ssh/ssh_host_rsa_key";
  sopsReady = hasKeyFile || hasSshEd25519 || hasSshRsa;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    age = {
      keyFile = lib.mkIf hasKeyFile "/var/lib/sops-nix/key.txt";
      sshKeyPaths =
        lib.optionals hasSshEd25519 [ "/etc/ssh/ssh_host_ed25519_key" ]
        ++ lib.optionals hasSshRsa [ "/etc/ssh/ssh_host_rsa_key" ];
    };

    secrets = lib.mkIf sopsReady {
      github_ssh_key = {
        sopsFile = ../../secrets/secrets.yaml;
        owner = "valen";
        mode = "0600";
      };
      valen_password = {
        sopsFile = ../../secrets/secrets.yaml;
      };
    };
  };

  systemd.services.sops-install-secrets.wantedBy = lib.mkIf (!sopsReady) (lib.mkForce [ ]);
}
