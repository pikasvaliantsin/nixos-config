# sops-nix: секреты расшифровываются host-ключом при boot/активации.
#
# ВАЖНО: при переустановке перенеси /etc/ssh/ssh_host_ed25519_key
# (и .pub) до первого nixos-rebuild — иначе секреты не расшифруются.
{
  inputs,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      github_ssh_key = {
        sopsFile = ../../secrets/secrets.yaml;
        owner = "valen";
        mode = "0600";
      };
      valen_password = {
        sopsFile = ../../secrets/secrets.yaml;
        # Устанавливается до activation-скрипта users, иначе hashedPasswordFile
        # не успевает появиться и пароль не обновится.
        neededForUsers = true;
      };
      opencode_api_key = {
        sopsFile = ../../secrets/secrets.yaml;
        owner = "valen";
        mode = "0400";
      };
    };
  };
}
