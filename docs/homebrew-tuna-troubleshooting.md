# Homebrew TUNA Mirror Troubleshooting

This note records the diagnostic process for a Homebrew upgrade that still tried to download bottles
from `ghcr.io` after switching Homebrew to the TUNA mirror.

## Symptom

During a `brew upgrade` or `darwin-rebuild switch`, Homebrew failed with errors like:

```text
Error: Failed to download resource "libngtcp2"
Download failed: https://ghcr.io/v2/homebrew/core/libngtcp2/blobs/sha256:...
curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to ghcr.io:443
```

The same activation later failed to pour a dependency because the expected cache file was missing:

```text
Error: No such file or directory @ rb_sysopen -
/Users/vitus/Library/Caches/Homebrew/downloads/...--libnghttp2--1.69.0.arm64_tahoe.bottle.tar.gz
```

## Root Cause

The active shell had the TUNA variables, but the `nix-darwin` Homebrew activation environment still
exported the old mirror settings. That meant `brew bundle` or `brew upgrade` launched by activation
could run without the intended `HOMEBREW_BOTTLE_DOMAIN`, causing Homebrew to fall back to its
default bottle host:

```text
https://ghcr.io/v2/homebrew/core
```

The durable source of these variables is:

```text
modules/darwin/apps.nix
```

The interactive shell source is:

```text
~/.zprofile
```

Both need to agree.

## Expected TUNA Configuration

Use these values:

```sh
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
```

The Homebrew repository remote should also point to TUNA:

```sh
git -C /opt/homebrew remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
```

## Diagnostic Commands

Check what a new login shell sees:

```sh
zsh -lc 'env | rg "^HOMEBREW_"'
```

Check what Homebrew sees:

```sh
zsh -lc 'brew config'
```

Important fields in `brew config`:

```text
ORIGIN: https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
HOMEBREW_API_DOMAIN: https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api
HOMEBREW_BOTTLE_DOMAIN: https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
HOMEBREW_BREW_GIT_REMOTE: https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
HOMEBREW_CORE_GIT_REMOTE: https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
```

Find stale mirror settings in the repo:

```sh
rg -n 'bfsu|ustc|aliyun|HOMEBREW_(API_DOMAIN|BOTTLE_DOMAIN|BREW_GIT_REMOTE|CORE_GIT_REMOTE|PIP_INDEX_URL)' ~/nix-config
```

Check the cached bottle paths Homebrew expects:

```sh
zsh -lc 'brew --cache libnghttp2 libngtcp2 xz curl'
```

## Recovery Steps

After fixing `modules/darwin/apps.nix` and `~/.zprofile`, start a new shell or run commands through
a login shell:

```sh
zsh -lc 'brew config'
```

If an earlier activation already failed partway through, prefetch the missing bottles with the
corrected environment:

```sh
zsh -lc 'brew fetch -v --force libnghttp2 libngtcp2 xz'
```

Then rerun the failed upgrade:

```sh
zsh -lc 'brew upgrade curl'
```

For `nix-darwin`, rerun activation after the config change:

```sh
darwin-rebuild switch --flake ~/nix-config
```

If TUNA's git mirror reports a long queue during `brew update`, that confirms the TUNA git remote is
being used. It is a mirror-side queue, not a local configuration problem.

## Verification From This Incident

The fixed environment downloaded and verified the previously failing bottles:

```text
Bottle libnghttp2 (1.69.0)
Bottle libngtcp2 (1.22.1)
Bottle xz (5.8.3)
```

The follow-up upgrade completed successfully:

```text
curl 8.19.0 -> 8.20.0
```
