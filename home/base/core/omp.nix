{ omp, ... }:
{
  imports = [ omp.homeManagerModules.default ];

  # Oh My Pi (omp) coding agent，由官方 flake 源码构建并固定版本于 flake.lock。
  # 取代旧的用户级 `bun install -g @oh-my-pi/pi-coding-agent`。
  # `~/.omp/agent/config.yml` 与 `models.yml` 仍由用户手工维护，不在这里声明。
  programs.omp.enable = true;
}
