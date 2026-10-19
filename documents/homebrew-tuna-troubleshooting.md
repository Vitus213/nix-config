# Homebrew TUNA 镜像排障

这份记录用于排查 Homebrew 已经切到 TUNA 镜像后，升级时仍然尝试从 `ghcr.io` 下载 bottle 的问题。

## 现象

执行 `brew upgrade` 或 `darwin-rebuild switch` 时，Homebrew 报错:

```text
Error: Failed to download resource "libngtcp2"
Download failed: https://ghcr.io/v2/homebrew/core/libngtcp2/blobs/sha256:...
curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to ghcr.io:443
```

后续 activation 还可能因为缓存文件不存在而失败:

```text
Error: No such file or directory @ rb_sysopen -
/Users/vitus/Library/Caches/Homebrew/downloads/...--libnghttp2--1.69.0.arm64_tahoe.bottle.tar.gz
```

## 根因

当前交互 shell 已经有 TUNA 环境变量，但 `nix-darwin` Homebrew
activation 环境里仍然导出了旧镜像配置。

这会导致 activation 触发的 `brew bundle` 或 `brew upgrade` 没有拿到期望的
`HOMEBREW_BOTTLE_DOMAIN`，于是回退到默认 bottle 源:

```text
https://ghcr.io/v2/homebrew/core
```

需要同时检查两个来源:

- `modules/darwin/apps.nix`: 持久化的 nix-darwin 配置
- `~/.zprofile`: 交互 shell 配置

两边的 Homebrew 环境变量必须一致。

## 期望的 TUNA 配置

```sh
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
```

Homebrew 仓库 remote 也应指向 TUNA:

```sh
git -C /opt/homebrew remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
```

## 排查命令

检查新 login shell 看到的变量:

```sh
zsh -lc 'env | rg "^HOMEBREW_"'
```

检查 Homebrew 看到的配置:

```sh
zsh -lc 'brew config'
```

重点字段:

```text
ORIGIN: https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
HOMEBREW_API_DOMAIN: https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api
HOMEBREW_BOTTLE_DOMAIN: https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
HOMEBREW_BREW_GIT_REMOTE: https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
HOMEBREW_CORE_GIT_REMOTE: https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
```

查找仓库里的旧镜像配置:

```sh
rg -n 'bfsu|ustc|aliyun|HOMEBREW_(API_DOMAIN|BOTTLE_DOMAIN|BREW_GIT_REMOTE|CORE_GIT_REMOTE|PIP_INDEX_URL)' ~/nix-config
```

查看 Homebrew 期望的缓存路径:

```sh
zsh -lc 'brew --cache libnghttp2 libngtcp2 xz curl'
```

## 恢复步骤

修复 `modules/darwin/apps.nix` 和 `~/.zprofile` 后，开新 shell 或通过 login shell 执行:

```sh
zsh -lc 'brew config'
```

如果之前 activation 已经半途失败，先用修正后的环境预下载缺失 bottle:

```sh
zsh -lc 'brew fetch -v --force libnghttp2 libngtcp2 xz'
```

然后重新执行失败的 upgrade:

```sh
zsh -lc 'brew upgrade curl'
```

对 nix-darwin，修复配置后重新 activation:

```sh
darwin-rebuild switch --flake ~/nix-config
```

如果 `brew update` 显示 TUNA git mirror 排队，说明已经走到 TUNA
remote。那是镜像侧队列，不是本地配置问题。

## 本次事件验证

修复后，之前失败的 bottle 能正常下载并校验:

```text
Bottle libnghttp2 (1.69.0)
Bottle libngtcp2 (1.22.1)
Bottle xz (5.8.3)
```

后续升级成功:

```text
curl 8.19.0 -> 8.20.0
```
