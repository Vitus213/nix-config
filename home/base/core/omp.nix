{ omp, ... }:
{
  imports = [ omp.homeManagerModules.default ];

  # Oh My Pi (omp) coding agent，由官方 flake 源码构建并固定版本于 flake.lock。
  # 取代旧的用户级 `bun install -g @oh-my-pi/pi-coding-agent`。
  #
  # settings 为声明式来源：每次 home-manager switch 整体覆盖
  # `~/.omp/agent/config.yml`（可写普通文件，omp 运行时可改写，下次 switch 恢复声明值）。
  # 迁移自原手工 config.yml：modelRoles / setupVersion / hideThinkingBlock。
  # `~/.omp/agent/models.yml`（provider 目录与 API key）仍为手工维护的用户级文件。
  #
  # memory: hindsight —— 远端 memory backend，服务端见 modules/darwin/hindsight/。
  # scoping = per-project-tagged：写共享 bank + 项目 tag（仓库主根 basename 小写，
  # 如 ~/code/General -> project:general），recall 覆盖项目 tag 与未标记全局记忆。
  programs.omp = {
    enable = true;
    settings = {
      modelRoles = {
        default = "bailian/glm-5.2-fast-preview:high";
        smol = "openai/gpt-5.5:xhigh";
        slow = "openai/gpt-5.5:xhigh";
      };
      setupVersion = 1;
      hideThinkingBlock = true;

      memory.backend = "hindsight";
      hindsight = {
        apiUrl = "http://localhost:8888";
        scoping = "per-project-tagged";
      };
    };
  };
}
