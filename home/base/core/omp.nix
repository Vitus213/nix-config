{
  config,
  lib,
  pkgs,
  ...
}:
let
  ompAgentDir = "${config.home.homeDirectory}/.omp/agent";
  modelsTarget = "${ompAgentDir}/models.yml";
  modelsGenerated = "${ompAgentDir}/.models.generated.yml";
  modelsTemplate = ./omp-models.yml.in;
  syncScript = ./omp-sync.py;
  keysFile = "/run/agenix/omp-keys";

  # 从 agenix 解密出的 key 文件 + Nix store 模板，生成实际 models.yml（含明文 key，仅落用户目录）。
  # 手动运行 `omp-sync-models` 可从模板重置本机配置（覆盖手改）。
  ompSyncModels = pkgs.writeShellScriptBin "omp-sync-models" ''
    set -euo pipefail
    keys="${keysFile}"
    gen="${modelsGenerated}"
    tgt="${modelsTarget}"
    mkdir -p "$(dirname "$gen")"
    if [ ! -r "$keys" ]; then
      echo "omp-sync-models: 缺少 $keys（agenix 未解密 omp-keys？）" >&2
      exit 1
    fi
    ${pkgs.python3}/bin/python3 "${syncScript}" "$keys" "${modelsTemplate}" "$gen"
    chmod 600 "$gen"
    ln -sfn ".models.generated.yml" "$tgt"
    echo "omp-sync-models: 已生成 $gen 并链接 $tgt"
  '';
in
{
  home.packages = [ ompSyncModels ];

  # B 模式：仅当目标缺失或不是软链接时从模板生成；重建/切换不覆盖用户手改。
  home.activation.ompModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${modelsTarget}" ] || [ ! -L "${modelsTarget}" ]; then
      ${ompSyncModels}/bin/omp-sync-models || echo "ompModels: 生成失败，可稍后手动运行 omp-sync-models" >&2
    else
      echo "ompModels: ${modelsTarget} 已存在（用户文件优先，跳过）"
    fi
  '';
}
