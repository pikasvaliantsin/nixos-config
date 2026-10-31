# NixVim и настройки Micro.
_:

{
  # Настройки Micro
  xdg.configFile."micro/settings.json" = {
    text = ''
      {
        "colorscheme": "solarized",
        "tabstospaces": true,
        "tabwidth": 2,
        "autosu": true,
        "ruler": true,
        "softwrap": true,
        "clipboard": "external"
      }
    '';
    force = true;
  };

  # Настройки NixVim (Neovim)
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    opts = {
      number = true;
      relativenumber = true;
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      clipboard = "unnamedplus";
      signcolumn = "yes";
      updatetime = 250;
      ignorecase = true;
      smartcase = true;
      hlsearch = false;
      incsearch = true;
    };

    globals.mapleader = " ";

    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        transparent_background = true;
      };
    };

    autoCmd = [
      {
        event = [ "BufWritePre" ];
        pattern = [ "*.nix" ];
        callback.__raw = ''
          function()
            vim.lsp.buf.format({ async = false })
          end
        '';
      }
      {
        event = [ "TextYankPost" ];
        callback.__raw = "function() vim.highlight.on_yank() end";
      }
    ];

    keymaps = [
      {
        mode = "n";
        key = "<leader>ff";
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "Find files";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action = "<cmd>Telescope live_grep<cr>";
        options.desc = "Live grep";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = "<cmd>Telescope buffers<cr>";
        options.desc = "Find buffers";
      }
      {
        mode = "n";
        key = "<leader>fh";
        action = "<cmd>Telescope help_tags<cr>";
        options.desc = "Help tags";
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "Toggle file tree";
      }
      {
        mode = "n";
        key = "gd";
        action = "<cmd>lua vim.lsp.buf.definition()<cr>";
        options.desc = "Go to definition";
      }
      {
        mode = "n";
        key = "gD";
        action = "<cmd>lua vim.lsp.buf.declaration()<cr>";
        options.desc = "Go to declaration";
      }
      {
        mode = "n";
        key = "gi";
        action = "<cmd>lua vim.lsp.buf.implementation()<cr>";
        options.desc = "Go to implementation";
      }
      {
        mode = "n";
        key = "gr";
        action = "<cmd>lua vim.lsp.buf.references()<cr>";
        options.desc = "Go to references";
      }
      {
        mode = "n";
        key = "K";
        action = "<cmd>lua vim.lsp.buf.hover()<cr>";
        options.desc = "Hover documentation";
      }
      {
        mode = "n";
        key = "<leader>ca";
        action = "<cmd>lua vim.lsp.buf.code_action()<cr>";
        options.desc = "Code action";
      }
      {
        mode = "n";
        key = "<leader>rn";
        action = "<cmd>lua vim.lsp.buf.rename()<cr>";
        options.desc = "Rename symbol";
      }
      {
        mode = "n";
        key = "<leader>f";
        action = "<cmd>lua vim.lsp.buf.format({ async = true })<cr>";
        options.desc = "Format file";
      }
      {
        mode = "n";
        key = "[d";
        action = "<cmd>lua vim.diagnostic.goto_prev()<cr>";
        options.desc = "Previous diagnostic";
      }
      {
        mode = "n";
        key = "]d";
        action = "<cmd>lua vim.diagnostic.goto_next()<cr>";
        options.desc = "Next diagnostic";
      }
      {
        mode = "n";
        key = "<leader>d";
        action = "<cmd>lua vim.diagnostic.open_float()<cr>";
        options.desc = "Show diagnostic";
      }
    ];

    plugins = {
      telescope.enable = true;
      web-devicons.enable = true;
      neo-tree = {
        enable = true;
        settings.filesystem.filtered_items = {
          hide_gitignored = false;
          hide_dotfiles = false;
        };
      };
      which-key.enable = true;
      treesitter = {
        enable = true;
        settings = {
          ensure_installed = [
            "nix"
            "bash"
            "fish"
            "lua"
            "yaml"
            "toml"
            "json"
            "markdown"
          ];
          highlight.enable = true;
          indent.enable = true;
        };
      };
      lsp = {
        enable = true;
        servers = {
          nixd.enable = true;
          bashls.enable = true;
          yamlls.enable = true;
          taplo.enable = true;
          lua_ls.enable = true;
        };
      };
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          sources = [
            { name = "nvim_lsp"; }
            { name = "buffer"; }
            { name = "path"; }
            { name = "luasnip"; }
          ];
          mapping = {
            "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<C-Space>" = "cmp.mapping.complete()";
          };
        };
      };
      cmp-nvim-lsp.enable = true;
      cmp-buffer.enable = true;
      cmp-path.enable = true;
      cmp_luasnip.enable = true;
      luasnip.enable = true;
      gitsigns.enable = true;
      lualine.enable = true;
      bufferline.enable = true;
      notify.enable = true;
      noice.enable = true;
      lsp-status.enable = true;
      nvim-autopairs.enable = true;
      colorizer.enable = true;
      indent-blankline.enable = true;
    };
  };
}
