def repeat-str [s: string, n: int] {
  (1..$n | each { $s } | str join)
}

def nix-extra-flags [] {
    [--extra-experimental-features "nix-command flakes"]
}

# ================= NixOS related =========================

def nixos-config-names [] {
    nix eval .#nixosConfigurations --apply builtins.attrNames --json ...(nix-extra-flags) | from json
}

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

def home-config-names [] {
    nix eval .#homeConfigurations --apply builtins.attrNames --json ...(nix-extra-flags) | from json
}

export def current-local-host [] {
    if "NIXCFG_HOSTNAME" in $env {
        $env.NIXCFG_HOSTNAME
    } else {
        (hostname)
    }
}

export def home-manager-switch [
    name: string
    mode: string
] {
    print $"home-manager switch '($name)' in '($mode)' mode..."
    print (repeat-str "=" 50)
    let flake = $".#($name)"
    if "debug" == $mode {
        nom build $".#homeConfigurations.($name).activationPackage" ...(nix-extra-flags) --show-trace --verbose
        nix shell nixpkgs#home-manager ...(nix-extra-flags) -c home-manager switch --flake $flake --show-trace --verbose
    } else {
        nix shell nixpkgs#home-manager ...(nix-extra-flags) -c home-manager switch --flake $flake
    }
}

export def local-switch [
    name: string
    mode: string
] {
    let nixosConfigs = (nixos-config-names)
    if ($name in $nixosConfigs) {
        nixos-switch $name $mode
        return
    }

    let homeConfigs = (home-config-names)
    if ($name in $homeConfigs) {
        home-manager-switch $name $mode
        return
    }

    error make {
        msg: $"Unknown local host '($name)'. nixosConfigurations: ($nixosConfigs | str join ', '); homeConfigurations: ($homeConfigs | str join ', ')"
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
    nix eval .#darwinConfigurations --apply builtins.attrNames --json --extra-experimental-features "nix-command flakes" | from json
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
    let target = $".#darwinConfigurations.($resolved).system"
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
        sudo -E ./result/sw/bin/darwin-rebuild switch --flake $".#($resolved)" --show-trace --verbose
    } else {
        sudo -E ./result/sw/bin/darwin-rebuild switch --flake $".#($resolved)"
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
