{
  lib,
  pkgs,
  ...
}:
#############################################################
#
#  Athena - 实体机：开发机 + 家庭服务（接替 j1900），平时 SSH 远程使用，
#  保留与 apollo 相同的 niri 桌面，需要时直接接显示器。
#  MS-H610M + i5-12400F（无核显）+ RTX 4060，与 Windows 双系统。
#
#############################################################
let
  hostName = "athena";
  muslCc = pkgs.pkgsCross.musl64.stdenv.cc;
in
{
  imports = [
    ./hardware-configuration.nix
    ../_shared/nvidia.nix
    ./services.nix
    ./hindsight.nix
  ];

  # 常驻网关不依赖 SSH / 图形登录会话。
  users.users.vitus.linger = true;
  networking.firewall.allowedTCPPorts = [ 3425 ];

  # 固定到 LTS 系列：非 LTS 内核 EOL 后会被 nixpkgs 直接删除，导致求值失败
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  # Match Windows' default RTC behavior for dual boot.
  time.hardwareClockInLocalTime = true;

  boot.loader = {
    grub.enable = false;
    systemd-boot = {
      enable = true;
      # 与 Windows 共用的 ESP 只有 300M，限制保留的 generation 数，避免内核/initrd 写满
      configurationLimit = 3;
    };
    efi = {
      # systemd-boot 会自动把同一 ESP 上的 Windows Boot Manager 加进菜单
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  networking = {
    inherit hostName;
    networkmanager.enable = true; # WiFi 由 NetworkManager 管理，nmcli / noctalia 面板连接
    useDHCP = lib.mkDefault true;
    useNetworkd = false;
    # 有线网卡（RTL8111）魔术包唤醒；由 udev .link 设置，还需 BIOS 打开 PCIe 唤醒并关闭 ErP
    interfaces.enp2s0.wakeOnLan.enable = true;
  };

  # 开发机基础工具链（编辑器、git、curl 等已由 modules/base/packages.nix 提供）
  environment.systemPackages = with pkgs; [
    gcc
    python3
    nodejs_22
    go
    protobuf
    gperf
    # Corepack shims read packageManager; pkgs.yarn would install Yarn Classic.
    corepack_22
    # Keep Home Manager's native cargo/rustc; expose only the rustup manager.
    (writeShellScriptBin "rustup" ''
      exec ${pkgs.rustup}/bin/rustup "$@"
    '')
    # Native gcc remains glibc; this command always targets x86_64 musl.
    (writeShellScriptBin "musl-gcc" ''
      exec ${muslCc}/bin/${muslCc.targetPrefix}cc "$@"
    '')
  ];
  programs.nix-ld.enable = true;

  # 从 apollo `just remote-host athena` 免密远程部署（ssh 同步 worktree + 目标机本地切换）：
  # - 放行 nixos-rebuild switch（每代 store 路径哈希变化，用通配；其余 sudo 照旧要密码）
  # - 保留 switch-to-configuration 免密，供只激活不更新 profile 的场景
  # - 远程 nix copy 闭包所需 trusted-users 已由 modules/base/nix.nix 全局提供
  security.sudo.extraRules = [
    {
      users = [ "vitus" ];
      commands = [
        {
          command = "/nix/store/*/bin/nixos-rebuild switch *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/nix/store/*/bin/switch-to-configuration *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # 常驻服务器：禁用挂起/休眠，避免空闲后自动睡眠导致 SSH 与家庭服务断开
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # tailscaled 由 modules/nixos/desktop/networking/tailscale.nix 启用；athena 不登录、不加入 tailnet

  # 首次安装（nixos-install）时的版本，之后不要改
  system.stateVersion = "26.05";
}
