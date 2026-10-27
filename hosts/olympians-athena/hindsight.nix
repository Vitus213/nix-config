{ ... }:
# Hindsight：agent 长期记忆后端（omp memory.backend = hindsight）。
# 服务端为单容器（内嵌 PostgreSQL），原跑在 artemis（macOS colima），
# 2026-10 迁到 athena 常驻，局域网内 apollo / artemis 的 omp 都连本服务；
# 数据卷由 artemis 的 docker 卷 hindsight-data 导出导入，见 documents/hindsight.md。
let
  containerName = "hindsight";
  envFile = "/var/lib/hindsight/hindsight.env";
in
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.${containerName} = {
    image = "ghcr.io/vectorize-io/hindsight:latest";
    autoStart = true;
    ports = [
      "8888:8888" # REST API：omp memory backend
      "9999:9999" # Web UI
    ];
    environment = {
      HINDSIGHT_API_LLM_PROVIDER = "openai";
      HINDSIGHT_API_LLM_BASE_URL = "https://sub.scitrace.cc/v1";
      HINDSIGHT_API_LLM_MODEL = "gemini-3.1-flash-lite";
    };
    environmentFiles = [ envFile ];
    volumes = [ "hindsight-data:/home/hindsight/.pg0" ];
  };

  # LLM key 不进 store：首次启动从 agenix 解密的 omp-keys 提取 gemini 行生成
  # env 文件（与 artemis 手工维护的 hindsight.env 同源）；文件非空则不动。
  # omp-keys 无 gemini 行时生成空文件让容器照常启动（LLM 操作降级），
  # 下次重启会重试提取。gemini key 轮换后删除该文件重新 bootstrap。
  systemd.services.${containerName} = {
    after = [ "agenix.service" ];
    preStart = ''
      install -d -m 700 /var/lib/hindsight
      if [ ! -s ${envFile} ]; then
        key=$(sed -n 's/^gemini:[[:space:]]*//p' /run/agenix/omp-keys)
        if [ -n "$key" ]; then
          printf 'HINDSIGHT_API_LLM_API_KEY=%s\n' "$key" > ${envFile}
          chmod 600 ${envFile}
        else
          : > ${envFile}
        fi
      fi
    '';
  };

  # 防火墙当前默认关闭；先声明端口，将来打开时无需补
  networking.firewall.allowedTCPPorts = [ 8888 9999 ];
}
