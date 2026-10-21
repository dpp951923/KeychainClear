# KeychainClear: Rootless Tweak + Unix Socket + Python

将 `Makefile` 中的 `KeychainClear_FILTER` 改成目标 App 的 Bundle ID。

## 编译

```sh
export THEOS=/path/to/theos
make package THEOS_PACKAGE_SCHEME=rootless
```

生成的 `.deb` 安装到 Dopamine rootless 设备后，重启 SpringBoard 或目标 App。

## Socket 命令

Tweak 注入目标 App 后创建：

```text
/var/mobile/Library/Caches/com.example.keychainclear.sock
```

支持：

```text
ping    检查 Tweak 是否加载
status  查询状态
clear   删除当前 App access group 可访问的 Keychain 项
```

## 使用 Python

```sh
python3 control.py ping
python3 control.py status
python3 control.py clear
```

Python 必须在 iPhone 本机运行，并且 Tweak 已经注入目标 App。`SecItemDelete` 只影响当前 App 有权限访问的 Keychain 项，不会删除其他 App 的 Keychain。
