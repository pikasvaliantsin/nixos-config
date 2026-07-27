{config, pkgs, ...}:

{
services.displayManager.dms-greeter = {
  compositor = {
    name = "niri"; # Required. Can be also "hyprland" or "sway"
    customConfig = ''
      # Optional custom compositor configuration
    '';
  };

  # Sync your user's DankMaterialShell theme with the greeter. You'll probably want this
  configHome = "/home/valen";

  # Custom config files for non-standard config locations
  configFiles = [
    "/home/valen/.config/DankMaterialShell/settings.json"
  ];

  # Save the logs to a file
  logs = {
    save = true; 
    path = "/tmp/dms-greeter.log";
  };

  # Custom Quickshell Package    
  quickshell.package = pkgs.quickshell;
};
}
