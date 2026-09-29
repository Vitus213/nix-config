{
  pkgs,
  ...
}:
let
  # docker-compose.yml 唯一内容源是 ./hindsight-compose.yml；
  # 这里转成 store 文件供 launchd 用固定路径引用（工作区路径可变，store 路径稳定）。
  composeFile = pkgs.writeText "hindsight-docker-compose.yml" (
    builtins.readFile ./hindsight-compose.yml
  );
in
{
  # colima（docker daemon 运行时）：登录即启动，`colima start` 幂等。
  launchd.user.agents."hindsight-colima" = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.colima}/bin/colima"
        "start"
        "--cpu"
        "2"
        "--memory"
        "4"
      ];
      RunAtLoad = true;
      ProcessType = "Background";
      StandardOutPath = "/tmp/hindsight-colima.log";
      StandardErrorPath = "/tmp/hindsight-colima.log";
    };
  };

  # hindsight 容器：RunAtLoad 拉起一次；StartInterval 300s 兜底自愈
  # （覆盖容器被误删/daemon 未就绪等场景，up -d 幂等）。
  launchd.user.agents."hindsight-compose" = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.docker-compose}/bin/docker-compose"
        "-p"
        "hindsight"
        "-f"
        "${composeFile}"
        "up"
        "-d"
      ];
      RunAtLoad = true;
      StartInterval = 300;
      ProcessType = "Background";
      EnvironmentVariables = {
        DOCKER_HOST = "unix:///Users/vitus/.colima/default/docker.sock";
      };
      StandardOutPath = "/tmp/hindsight-compose.log";
      StandardErrorPath = "/tmp/hindsight-compose.log";
    };
  };
}
