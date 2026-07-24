{ config, pkgs, inputs,  ... }:

{

    imports = [
        inputs.nixvim.homeModules.nixvim
      ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;  # Сделать nvim редактором по умолчанию ($EDITOR)
    
    # Базовые настройки редактора
    opts = {
      number = true;
      relativenumber = true;
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      clipboard = "unnamedplus";
      signcolumn = "yes";
      updatetime = 250;
      
      # Поиск
      ignorecase = true;
      smartcase = true;
      hlsearch = false;
      incsearch = true;
    };
    
    # Лидер-клавиша (пробел)
    globals.mapleader = " ";
    
    # Цветовая схема (Catppuccin Mocha — совпадает с твоим Alacritty)
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        transparent_background = true;
      };
    };
    
    # Автокоманды
    autoCmd = [
      # Автоформатирование Nix при сохранении
      {
        event = [ "BufWritePre" ];
        pattern = [ "*.nix" ];
        callback.__raw = ''
          function()
            vim.lsp.buf.format({ async = false })
          end
        '';
      }
      # Подсветка при yank
      {
        event = [ "TextYankPost" ];
        callback.__raw = "function() vim.highlight.on_yank() end";
      }
    ];
    
    # Keymaps
    keymaps = [
      # Leader-биндинги
      { mode = "n"; key = "<leader>ff"; action = "<cmd>Telescope find_files<cr>"; options.desc = "Find files"; }
      { mode = "n"; key = "<leader>fg"; action = "<cmd>Telescope live_grep<cr>"; options.desc = "Live grep"; }
      { mode = "n"; key = "<leader>fb"; action = "<cmd>Telescope buffers<cr>"; options.desc = "Find buffers"; }
      { mode = "n"; key = "<leader>fh"; action = "<cmd>Telescope help_tags<cr>"; options.desc = "Help tags"; }
      
      # Файловый менеджер
      { mode = "n"; key = "<leader>e"; action = "<cmd>Neotree toggle<cr>"; options.desc = "Toggle file tree"; }
      
      # LSP биндинги
      { mode = "n"; key = "gd"; action = "<cmd>lua vim.lsp.buf.definition()<cr>"; options.desc = "Go to definition"; }
      { mode = "n"; key = "gD"; action = "<cmd>lua vim.lsp.buf.declaration()<cr>"; options.desc = "Go to declaration"; }
      { mode = "n"; key = "gi"; action = "<cmd>lua vim.lsp.buf.implementation()<cr>"; options.desc = "Go to implementation"; }
      { mode = "n"; key = "gr"; action = "<cmd>lua vim.lsp.buf.references()<cr>"; options.desc = "Go to references"; }
      { mode = "n"; key = "K"; action = "<cmd>lua vim.lsp.buf.hover()<cr>"; options.desc = "Hover documentation"; }
      { mode = "n"; key = "<leader>ca"; action = "<cmd>lua vim.lsp.buf.code_action()<cr>"; options.desc = "Code action"; }
      { mode = "n"; key = "<leader>rn"; action = "<cmd>lua vim.lsp.buf.rename()<cr>"; options.desc = "Rename symbol"; }
      { mode = "n"; key = "<leader>f"; action = "<cmd>lua vim.lsp.buf.format({ async = true })<cr>"; options.desc = "Format file"; }
      
      # Диагностика
      { mode = "n"; key = "[d"; action = "<cmd>lua vim.diagnostic.goto_prev()<cr>"; options.desc = "Previous diagnostic"; }
      { mode = "n"; key = "]d"; action = "<cmd>lua vim.diagnostic.goto_next()<cr>"; options.desc = "Next diagnostic"; }
      { mode = "n"; key = "<leader>d"; action = "<cmd>lua vim.diagnostic.open_float()<cr>"; options.desc = "Show diagnostic"; }
    ];
    
    # Плагины
    plugins = {
      # === Навигация и UI ===
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
        };
      };
      
      web-devicons.enable = true;
      
      neo-tree = {
        enable = true;
        filesystem = {
          filteredItems = {       # <-- Вернули camelCase, как просит ошибка
            hideDotfiles = false;
            hideGitignored = false;
          };
        };
      };
      
      which-key.enable = true;  # Подсказки по хоткеям
      
      # === Синтаксис ===
      treesitter = {
        enable = true;
        settings = {
          ensure_installed = [ "nix" "bash" "fish" "lua" "yaml" "toml" "json" "markdown" ];
          highlight.enable = true;
          indent.enable = true;
        };
      };
      
      # === LSP ===
      lsp = {
        enable = true;
        servers = {
          # Nix LSP — ВАЖНО: это даст тебе валидацию при написании
          nixd.enable = true;
          
          # Для Bash и Fish скриптов
          bashls.enable = true;
          
          # Для YAML/TOML конфигов
          yamlls.enable = true;
          taplo.enable = true;
          
          # Для Lua (если будешь писать конфиги)
          lua_ls.enable = true;
        };
        keymaps = {
          silent = true;
          diagnostic = {
            "[d" = "goto_prev";
            "]d" = "goto_next";
            "<leader>d" = "open_float";
          };
          lspBuf = {
            "gd" = "definition";
            "gD" = "declaration";
            "gi" = "implementation";
            "gr" = "references";
            "K" = "hover";
            "<leader>ca" = "code_action";
            "<leader>rn" = "rename";
            "<leader>f" = "format";
          };
        };
      };
      
      # === Автодополнение ===
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
      
      # === Git интеграция ===
      gitsigns = {
        enable = true;
        settings = {
          current_line_blame = true;
        };
      };
      
      # === UI ===
      lualine.enable = true;
      bufferline.enable = true;
      
      # Уведомления
      notify.enable = true;
      noice.enable = true;  # Красивые cmdline и popup-уведомления
      
      # Индикатор автодополнения
      lsp-status.enable = true;
      
      # Авто-пары скобок
      nvim-autopairs.enable = true;
      
      # Подсветка цветов (#ff0000 и т.д.)
      colorizer.enable = true;
      
      # Отступы
      indent-blankline.enable = true;
    };
  };
}
