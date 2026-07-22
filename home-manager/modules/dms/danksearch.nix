{ config, pkgs, inputs, ... }:

{
    imports = [
      inputs.danksearch.homeModules.default
    ];

    programs.dsearch = {
      enable = true;
      
      config = {
        listen_addr = ":43654";
        max_file_bytes = 5242880;  # 5MB
        worker_count = 8;
        
        index_paths = [
          {
            path = "~/Documents";
            max_depth = 0;  # No limit
            exclude_hidden = false;
            exclude_dirs = [ ];
          }
          {
            path = "~/Projects";
            max_depth = 8;
            exclude_hidden = true;
            exclude_dirs = [ "node_modules" "venv" "target" ".git" "dist" "build" ];
          }
          {
            path = "/mnt/shared";
            max_depth = 5;
            watch = false;  # Disable watchers for network mount
            exclude_dirs = [ ".cache" ];
          }
        ];
      };
    };
}
