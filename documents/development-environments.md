# Go、Rust、Java、Python 开发环境

四种语言的安装声明集中在 `home/base/tui/dev-tools.nix`，由 Home Manager 管理，版本跟随 `flake.lock`
的主 `nixpkgs`。参考 ryan4yin 的 Nixpkgs 工具链组合，不引入额外的语言版本管理器。

## 主机与安装内容

Apollo、Athena 提供完整的四种环境。原来放在 `home/base/tui/editors/packages.nix`
的 Python、Rust 已迁入开发工具文件，所有原有主机继续安装它们；Go、Java 和配套工具只在
`osConfig.networking.hostName` 为 `apollo`、`athena` 时启用。

| 语言   | 当前版本              | 安装内容                                                               |
| ------ | --------------------- | ---------------------------------------------------------------------- |
| Go     | `1.26.8`              | `go`、`gopls`、`gotools`、`delve`、`gomodifytags`、`iferr`、`impl`     |
| Rust   | `rustc 1.98.1`        | `rustc`、`cargo`、`rust-analyzer`、`rustfmt`、`clippy`                 |
| Java   | OpenJDK `21.0.12.1+1` | JDK 21 LTS、Maven `3.9.16`、Gradle `8.14.4`                            |
| Python | `3.13.15`             | Python 3.13、uv `0.13.0`、Pyright、Ruff、Black、pipx、Jupyter、IPython |

Python 保留已有的 NumPy、pandas、requests、pyquery、PyYAML、boto3 和 protobuf。 `uv`
是独立命令，不再重复放入 `python313.withPackages`。

## 路径与使用

Go 使用 `programs.go` 安装，`GOPATH` 固定为 `~/go`；Home Manager 生成
`~/.config/go/env`。新增 Go 设置写回 `programs.go.env`，避免对该只读文件执行 `go env -w`。Bash 已有
`~/go/bin` 和 `~/.cargo/bin`，Apollo、Athena 的 Nushell 也补齐这两个目录，
`go install`、`cargo install` 安装的用户命令可以直接调用。

Rust 使用 Nixpkgs 配套组件；`rust-analyzer` 包的 wrapper 已提供标准库源码。不需要执行
`rustup component add`。需要 nightly、额外 target 或项目指定编译器时，在项目的 `devShell`
中声明相应工具链。

Java 由 `programs.java` 安装 JDK 并设置 `JAVA_HOME`；Nushell 的 `env.nu`
同样声明它，独立启动 Nushell 时也能使用。Maven、Gradle 遵循 `JAVA_HOME`。当前 Gradle
8.14.4 不能使用 Java 25 运行，因此默认选 JDK 21；已有项目优先使用其 `./mvnw`、`./gradlew`。

Python 全局环境由 Nix 管理，项目依赖放入虚拟环境，避免向只读 Nix store 安装：

```sh
uv venv --python python3 --no-python-downloads .venv
uv pip install --python .venv/bin/python requests
.venv/bin/python -c 'import requests; print(requests.__version__)'
```

Nushell 激活方式：

```nu
overlay use .venv/bin/activate.nu
```

项目有 `pyproject.toml` / `uv.lock` 时使用项目自己的 `uv sync` /
`uv run`；需要其他 Python 版本或原生库时，在 `devShell` 中声明。现有 `direnv` / `nix-direnv`
已启用，项目 `.envrc` 可使用 `use flake`，然后执行 `direnv allow`。

## 部署、验证与回滚

本轮只修改仓库并构建验证，未对 Apollo、Athena 执行系统切换。在目标机拉取配置后运行
`just local`；重新打开终端，以加载 `JAVA_HOME` 和新 PATH。Athena 也可使用仓库已有的
`just remote-host athena` 部署流程。

已完成的验证：

- Apollo `home.path` 完整构建，提供四种语言和构建工具。
- Apollo、Athena 的完整 toplevel 求值通过，generic 未新增 Go、Java。
- 临时目录内实际执行 `go run`、`cargo run --offline`、`cargo clippy`、`javac` / `java`。
- Gradle 离线编译并运行 Java 应用；Maven 离线 `validate` 通过。
- Python 运行并导入现有常用库；uv 用声明的 Python 创建隔离环境并执行程序。
- 生成的 Nushell 环境确认 `JAVA_HOME` 和 Go/Cargo 用户命令路径；`just test` 返回
  `true`，两个修改过的 Nix 文件通过 `nixfmt --check`。

Maven 验证不包含从中央仓库下载插件；未在 Athena 实机运行程序。

回滚时从 `dev-tools.nix`
移除对应工具及环境设置，再重新部署。不要把语言包同时放回编辑器配置而保留开发工具文件中的重复安装。项目目录、虚拟环境和语言缓存不自动删除。

## 参考

- [ryan4yin 的语言工具组合](https://github.com/ryan4yin/nix-config/blob/main/home/base/tui/editors/packages.nix)
- [Home Manager Go 模块](https://github.com/nix-community/home-manager/blob/ab97a5d09e0f2aa7339cfd35ec5824fd6653e27c/modules/programs/go.nix)
- [Home Manager Java 模块](https://github.com/nix-community/home-manager/blob/ab97a5d09e0f2aa7339cfd35ec5824fd6653e27c/modules/programs/java.nix)
- [Gradle 8.14.4 Java 兼容矩阵](https://docs.gradle.org/8.14.4/userguide/compatibility.html)
- [uv 虚拟环境](https://docs.astral.sh/uv/pip/environments/)
