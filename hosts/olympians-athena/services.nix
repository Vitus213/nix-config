{
  config,
  pkgs,
  mysecrets,
  ...
}:
# 家庭服务（接替 j1900 上的 Docker 部署）：Jellyfin / Immich / Uptime Kuma /
# qBittorrent / aria2 + AriaNg；另有 Vaultwarden 经 Cloudflare Tunnel 对外。
# 防火墙沿用 modules/nixos/base/ssh.nix 的默认关闭，
# 各服务仍声明 openFirewall，后续打开防火墙时端口不用再补。
let
  mediaRoot = "/srv/media";
  downloadRoot = "${mediaRoot}/downloads";
  aria2SecretFile = "/var/lib/aria2-secret/rpc-secret";

  # 只在首次启动时写入；之后 WebUI 里的修改（含密码）保留在原文件里。
  # 不用模块的 serverConfig：它每次启动都会整份覆盖 qBittorrent.conf。
  qbittorrentSeed = pkgs.writeText "qBittorrent.conf" ''
    [BitTorrent]
    Session\AddTrackersFromURLEnabled=true
    Session\AdditionalTrackersURL=https://cf.trackerslist.com/best.txt
    Session\DefaultSavePath=${downloadRoot}/qbittorrent/
    Session\TempPath=${downloadRoot}/qbittorrent/incomplete/
    Session\TempPathEnabled=true

    [LegalNotice]
    Accepted=true

    [Network]
    PortForwardingEnabled=false

    [WebUI]
    Address=*
    ServerDomains=*
  '';
in
{
  # 媒体目录：Jellyfin 只读，下载器各写自己的子目录，统一 0755 让 Jellyfin 能读到。
  systemd.tmpfiles.rules = [
    "d ${mediaRoot} 0755 root root - -"
    "d ${mediaRoot}/movies 0755 vitus users - -"
    "d ${mediaRoot}/tv 0755 vitus users - -"
    "d ${mediaRoot}/music 0755 vitus users - -"
    "d ${downloadRoot} 0755 root root - -"
    "d ${downloadRoot}/qbittorrent 0755 qbittorrent qbittorrent - -"
  ];

  services.jellyfin = {
    enable = true;
    openFirewall = true; # 8096
  };

  services.immich = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true; # 2283
    # 机器学习（人脸/智能搜索）默认开启；内存紧张时改成 false。
    machine-learning.enable = true;
  };

  services.uptime-kuma = {
    enable = true;
    settings.HOST = "0.0.0.0"; # 模块默认只听 127.0.0.1
  };

  services.qbittorrent = {
    enable = true;
    openFirewall = true;
    webuiPort = 8080;
    torrentingPort = 6881;
  };
  systemd.services.qbittorrent.preStart = ''
    conf=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
    if [ ! -e "$conf" ]; then
      install -Dm600 ${qbittorrentSeed} "$conf"
    fi
  '';

  # aria2 的 RPC secret 不能进 nix store：首次启动时在本机随机生成。
  systemd.services.aria2-secret = {
    description = "Generate aria2 RPC secret";
    before = [ "aria2.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "aria2-secret";
      StateDirectoryMode = "0700";
    };
    script = ''
      if [ ! -s ${aria2SecretFile} ]; then
        umask 077
        ${pkgs.openssl}/bin/openssl rand -hex 16 > ${aria2SecretFile}
      fi
    '';
  };
  systemd.services.aria2 = {
    requires = [ "aria2-secret.service" ];
    after = [ "aria2-secret.service" ];
  };

  services.aria2 = {
    enable = true;
    openPorts = true;
    rpcSecretFile = aria2SecretFile;
    downloadDirPermission = "0755";
    settings = {
      dir = "${downloadRoot}/aria2";
      rpc-listen-all = true;
      rpc-allow-origin-all = true;
      # BT 端口与 qBittorrent 的 6881 错开
      listen-port = [
        {
          from = 6888;
          to = 6888;
        }
      ];
      dht-listen-port = "6888";
    };
  };

  # AriaNg 静态页面，浏览器里填 RPC 地址 http://athena:6800/jsonrpc 与 secret
  services.nginx = {
    enable = true;
    virtualHosts.ariang = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 6880;
        }
      ];
      root = "${pkgs.ariang}/share/ariang";
    };
  };

  # Vaultwarden（Bitwarden 兼容服务端）：只听本机，经 Cloudflare Tunnel 对外；
  # /admin 在隧道入口返回 404，日常经 `ssh -L 8222:127.0.0.1:8222 root@athena` 访问。
  age.secrets = {
    # ADMIN_TOKEN='<Argon2 哈希>'；systemd 以 root 读取 EnvironmentFile
    "vaultwarden-env".file = "${mysecrets}/vaultwarden-env.age";
    # 隧道凭据，经 LoadCredential 交给 DynamicUser 的 cloudflared
    "cloudflared-athena.json".file = "${mysecrets}/cloudflared-athena.json.age";
  };

  services.vaultwarden = {
    enable = true;
    backupDir = "/var/backup/vaultwarden"; # 模块自带每日 23:00 SQLite 备份
    environmentFile = config.age.secrets."vaultwarden-env".path;
    config = {
      DOMAIN = "https://vault.vitus213.xyz";
      SIGNUPS_ALLOWED = false; # 只能由管理员邀请
      INVITATIONS_ALLOWED = true;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      # 只听本机，该头只能由 cloudflared 写入；日志与登录限流按真实客户端 IP
      IP_HEADER = "CF-Connecting-IP";
    };
  };

  # 本地管理型隧道 athena；DNS：vault.vitus213.xyz（主）与 vault.vituss.me（过渡，2026-11-02 到期）
  # 都是 CNAME <隧道 ID>.cfargotunnel.com（已开代理）。
  # 模块按 hostname 只能写一条 ingress，所以每个 hostname 那条专门拦 /admin，其余路径落到 default。
  # 只有指向本隧道 ID 的 CNAME 能把流量送进来。
  services.cloudflared = {
    enable = true;
    tunnels."929d36f9-1bfd-4013-a762-2eb4e33c6583" =
      let
        blockAdmin = {
          path = "^/admin";
          service = "http_status:404";
        };
      in
      {
        credentialsFile = config.age.secrets."cloudflared-athena.json".path;
        # protocol 保持默认 auto（QUIC 优先）：2026-10-27 cloudflared 预检 athena 出口
        # QUIC 7844/udp 通、HTTP/2 7844/tcp 握手超时（经 Q30 OpenClash fake-ip）
        ingress = {
          "vault.vitus213.xyz" = blockAdmin;
          "vault.vituss.me" = blockAdmin;
        };
        default = "http://127.0.0.1:8222";
      };
  };
}
