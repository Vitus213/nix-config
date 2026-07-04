{
  pkgs,
  ...
}:
{
  home.packages =
    with pkgs;
    (
      # -*- Data & Configuration Languages -*-#
      [
        #-- nix
        nil
        nixd
        statix # Lints and suggestions for the nix programming language
        deadnix # Find and remove unused code in .nix source files
        nixfmt # Nix Code Formatter

        taplo # TOML language server / formatter / validator
        yaml-language-server
        actionlint # GitHub Actions linter

        #-- dockerfile
        hadolint # Dockerfile linter
        dockerfile-language-server

        #-- markdown
        marksman # language server for markdown
        glow # markdown previewer
        pandoc # document converter
      ]
      ++
        #-*- General Purpose Languages -*-#
        [
          #-- c/c++
          cmake
          cmake-language-server
          gnumake
          checkmake
          # c/c++ compiler, required by nvim-treesitter!
          gcc
          gdb
          # c/c++ tools with clang-tools, the unwrapped version won't
          # add alias like `cc` and `c++`, so that it won't conflict with gcc
          # llvmPackages.clang-unwrapped
          clang-tools
          lldb
          vscode-extensions.vadimcn.vscode-lldb.adapter # codelldb - debugger

          #-- python
          (python313.withPackages (
            ps: with ps; [
              # python language server
              pyright
              ruff

              pipx # Install and Run Python Applications in Isolated Environments
              black # python formatter
              uv # python project package manager

              # my commonly used python packages
              jupyter
              ipython
              pandas
              requests
              pyquery
              pyyaml
              boto3

              # misc
              protobuf # protocol buffer compiler
              numpy
            ]
          ))

          #-- rust
          # we'd better use the rust-overlays for rust development
          rustc
          rust-analyzer
          cargo # rust package manager
          rustfmt
          clippy # rust linter

          #-- bash
          bash-language-server
          shellcheck
          shfmt
        ]
      #-*- Web Development -*-#
      ++ [
        nodejs_22
        typescript
        typescript-language-server
        # HTML/CSS/JSON/ESLint language servers extracted from vscode
        vscode-langservers-extracted
      ]
      # -*- Lisp like Languages -*-#
      # ++ [
      #   guile
      #   racket-minimal
      #   fnlfmt # fennel
      #   (
      #     if pkgs.stdenv.isLinux && pkgs.stdenv.isx86
      #     then akkuPackages.scheme-langserver
      #     else pkgs.emptyDirectory
      #   )
      # ]
      ++ [
        #-- Optional Requirements:
        prettier # common code formatter
        fzf
        gdu # disk usage analyzer, required by AstroNvim
        (ripgrep.override { withPCRE2 = true; }) # recursively searches directories for a regex pattern
      ]
    );
}
