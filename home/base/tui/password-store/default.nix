{
  pkgs,
  config,
  lib,
  ...
}:
let
  passwordStoreDir = "${config.xdg.dataHome}/password-store";
  passExtensions =
    exts:
    [
      # an easy flow for updating passwords
      exts.pass-update
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin) [
      # pass-import currently pulls a Python dependency chain that fails on Darwin.
      exts.pass-import
    ];
in
{
  programs.password-store = {
    enable = true;
    package = pkgs.pass.withExtensions (
      exts:
      [
        # support for one-time-password (OTP) tokens
        # NOTE: Saving the password and OTP together runs counter to the purpose of secondary verification!
        # exts.pass-otp
      ]
      ++ passExtensions exts
    );
    # See the “Environment variables” section of pass(1) and the extension man pages for more information about the available keys.
    settings = {
      PASSWORD_STORE_DIR = passwordStoreDir;
      # 加密用的 GPG key 由 `pass init <你的 key ID>` 写入密码库的 .gpg-id，不在这里固定。
      PASSWORD_STORE_CLIP_TIME = "60";
      PASSWORD_STORE_GENERATED_LENGTH = "12";
      PASSWORD_STORE_ENABLE_EXTENSIONS = "true";
    };
  };

  # password-store extensions for browsers
  # you need to install the browser extension for this to work
  # https://github.com/browserpass/browserpass-extension
  programs.browserpass = {
    enable = true;
    browsers = [
      "chrome"
      "chromium"
      "firefox"
    ];
  };
}
