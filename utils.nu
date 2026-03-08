def repeat-str [s: string, n: int] {
  (1..$n | each { $s } | str join)
}

# ================= NixOS related =========================

export def nixos-switch [
    name: string
    mode: string
] {
    print $"nixos-switch '($name)' in '($mode)' mode..."
    print (repeat-str "=" 50)
    if "debug" == $mode {
        # show details via nix-output-monitor
        nom build $".#nixosConfigurations.($name).config.system.build.toplevel" --show-trace --verbose
        nixos-rebuild switch --sudo --flake $".#($name)" --show-trace --verbose
    } else {
        nixos-rebuild switch --sudo --flake $".#($name)"
    }
}


# ====================== Misc =============================

export def make-editable [
    path: string
] {
    print (repeat-str "=" 50)
    let tmpdir = (mktemp -d)
    rsync -avz --copy-links $"($path)/" $tmpdir
    rsync -avz --copy-links --chmod=D2755,F744 $"($tmpdir)/" $path
}


# ================= macOS related =========================

def darwin-config-names [] {
    nix eval path:.#darwinConfigurations --apply builtins.attrNames --json --extra-experimental-features "nix-command flakes" | from json
}

def require-darwin-config [name: string] {
    let available = (darwin-config-names)
    if ($name in $available) {
        $name
    } else {
        error make {
            msg: $"Unknown darwinConfiguration '($name)'. Available: ($available | str join ', ')"
        }
    }
}

export def darwin-build [
    name: string
    mode: string
] {
    let resolved = (require-darwin-config $name)
    print $"darwin-build '($resolved)' in '($mode)' mode..."
    print (repeat-str "=" 50)
    let target = $"path:.#darwinConfigurations.($resolved).system"
    if "debug" == $mode {
        nom build $target --extra-experimental-features "nix-command flakes"  --show-trace --verbose
    } else {
        nix build $target --extra-experimental-features "nix-command flakes"
    }
}

export def darwin-switch [
    name: string
    mode: string
] {
    let resolved = (require-darwin-config $name)
    print $"darwin-switch '($resolved)' in '($mode)' mode..."
    print (repeat-str "=" 50)
    if "debug" == $mode {
        sudo -E ./result/sw/bin/darwin-rebuild switch --flake $"path:.#($resolved)" --show-trace --verbose
    } else {
        sudo -E ./result/sw/bin/darwin-rebuild switch --flake $"path:.#($resolved)"
    }
}

export def darwin-rollback [] {
    ./result/sw/bin/darwin-rebuild --rollback
}

# ==================== Virtual Machines related =====================

# Build and upload a VM image
export def upload-vm [
    name: string
    mode: string
] {
    print $"upload-vm '($name)' in '($mode)' mode..."
    print (repeat-str "=" 50)
    let target = $".#($name)"
    if "debug" == $mode {
        nom build $target --show-trace --verbose
    } else {
        nix build $target
    }

    let remote = $"ryan@rakushun:/data/caddy/fileserver/vms/kubevirt-($name).qcow2"
    rsync -avz --progress --copy-links --checksum result $remote
}
