{
  description = "Ryan Yin's nix configuration for both NixOS & macOS";

  ##################################################################################################################
  #
  # Want to know Nix in details? Looking for a beginner-friendly tutorial?
  # Check out https://github.com/ryan4yin/nixos-and-flakes-book !
  #
  ##################################################################################################################

  outputs = inputs: import ./outputs inputs;

  # the nixConfig here only affects the flake itself, not the system configuration!
  # for more information, see:
  #     https://nixos-and-flakes.thiscute.world/nix-store/add-binary-cache-servers
  nixConfig = {
    # substituers will be appended to the default substituters when fetching packages
    extra-substituters = [
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
      "https://tail.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "tail.cachix.org-1:8wrCmBbcfPfvYdZ3b/bmkcPqs0AukBJug08DIBu19Ao="
    ];
  };

  # This is the standard format for flake.nix. `inputs` are the dependencies of the flake,
  # Each item in `inputs` will be passed as a parameter to the `outputs` function after being pulled and built.
  inputs = {
    # There are many ways to reference flake inputs. The most widely used is github:owner/name/reference,
    # which represents the GitHub repository URL + branch/commit-id/tag.

    # Official NixOS package source, using nixos's unstable branch by default
    # Find git commit hash with build status here(3 jobs per day):
    # https://hydra.nixos.org/jobset/nixpkgs/unstable
    # update via nix flake update nixpkgs --override-input nixpkgs github:NixOS/nixpkgs/<commit-hash>
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # nixpkgs with some custom patches
    nixpkgs-patched.url = "github:ryan4yin/nixpkgs/nixos-unstable";

    # for macos
    # nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/master";
      # url = "github:nix-community/home-manager/release-25.11";

      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs dependencies.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://github.com/catppuccin/nix
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    preservation = {
      url = "github:nix-community/preservation";
    };

    # generate iso/qcow2/docker/... image from nixos configuration
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    refind-minimal = {
      url = "github:evanpurkhiser/rEFInd-minimal";
      flake = false;
    };

    # secrets management
    agenix = {
      # lock with git commit at May 18, 2025
      url = "github:ryantm/agenix/4835b1dc898959d8547a871ef484930675cb47f1";
      # replaced with a type-safe reimplementation to get a better error message and less bugs.
      # url = "github:ryan4yin/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # add git hooks to format nix code before commit
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nuenv = {
      url = "github:DeterminateSystems/nuenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Oh My Pi (omp) coding agent, installed via its official Home Manager module
    # instead of the previous user-level `bun install -g`.
    omp.url = "github:can1357/oh-my-pi";

    # Zen Browser —— 垂直标签栏 Firefox 开源分支，社区 flake 打包（上游每日自动更新）。
    # 仅提供 x86_64-linux / aarch64-linux，用于 home/linux GUI 链。
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ########################  Some non-flake repositories  #########################################

    nu_scripts = {
      url = "github:ryan4yin/nu_scripts";
      flake = false;
    };

    ########################  My own repositories  #########################################

    # Syllune 语音输入（替代 Type4Me），远程 flake 锁定已验证提交。
    # nixpkgs-syllune 固定到 syllune 自身 flake.lock 验证过的提交，避免主仓库
    # nixpkgs 更新时 sherpa-onnx/onnxruntime 依赖漂移、本机源码重编译。
    syllune = {
      url = "github:Vitus213/syllune";
      inputs.nixpkgs.follows = "nixpkgs-syllune";
    };
    nixpkgs-syllune.url = "github:NixOS/nixpkgs/e73de5be04e0eff4190a1432b946d469c794e7b4";

    # my private secrets repository.
    mysecrets = {
      url = "git+https://github.com/Vitus213/my-secrets.git";
      flake = false;
    };

    # my wallpapers
    wallpapers = {
      url = "github:Vitus213/wallpapers";
      flake = false;
    };

    # my-asahi-firmware = {
    #   url = "git+ssh://git@github.com/ryan4yin/asahi-firmware.git?shallow=1";
    #   flake = false;
    # };

    # nur-ryan4yin = {
    #   url = "github:ryan4yin/nur-packages";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # for waydroid
    # nur-ataraxiasjel.url = "github:AtaraxiaSjel/nur";
  };
}
