# Password Store

这个目录配置基于 `pass` 的密码管理。

参考:

- <https://www.passwordstore.org/>
- [awesome-password-store](https://github.com/tijn/awesome-password-store)
- [gopass](https://github.com/gopasspw/gopass)
- [Android Password Store](https://github.com/android-password-store/Android-Password-Store)
- [browserpass](https://github.com/browserpass/browserpass-extension)

## 更换 password-store 的 GPG key

建议每隔几年轮换一次 GPG key。流程如下:

1. 创建新的 GPG key pair，并安全备份
2. 确认旧 key 和新 key 都可用
3. 更新 `default.nix`，切换到新的 GPG subkey
4. 检查当前 password-store 使用的 key:

   ```bash
   cd ~/.local/share/password-store/
   cat .gpg-id
   gpg --list-packets path/to/any/password.gpg
   ```

5. 重新初始化 password-store:

   ```bash
   pass init <new-key-id>
   ```

   这一步会要求解锁新旧 key，然后重新加密所有密码。

6. 再次检查:

   ```bash
   cat .gpg-id
   gpg --list-packets path/to/any/password.gpg
   ```

7. 确认无误后删除旧 key:

   ```bash
   gpg --delete-secret-keys <old-key-id>
   gpg --delete-keys <old-key-id>
   ```
