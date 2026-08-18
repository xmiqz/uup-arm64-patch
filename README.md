# uup-arm64-patch

让 UUP dump 在 Windows on Arm（骁龙等 ARM64 芯片）设备上以**原生速度**转换 ISO。

## 为什么需要它

[UUP dump](https://uupdump.net) 生成的转换包中，工具链（wimlib、7-Zip、cdimage、aria2 等）
全部是 x86 / x86-64 版本。在 ARM64 Windows 设备上它们只能跑在模拟层里，
转换一个 Windows ISO 往往要多花数倍时间。

本工具把其中负载最重的组件替换为**原生 ARM64 构建**：

| 组件 | 来源 | 版本 | 说明 |
|---|---|---|---|
| wimlib | [wimlib.net](https://wimlib.net) 官方 | 1.14.4 | WIM 导出/压缩，**最重的 CPU 环节** |
| 7-Zip | [ip7z/7zip](https://github.com/ip7z/7zip) 官方 | 最新 | cab/msu 解包 |
| aria2 | [minnyres/aria2-windows-arm64](https://github.com/minnyres/aria2-windows-arm64) | 1.37.0 | UUP 下载器（可选） |

实测 WIM 压缩环节提速 2~4 倍。

## 使用方法

1. 从 [uupdump.net](https://uupdump.net) 下载转换包（zip）并解压
2. 把整个 `uup-arm64-patch` 文件夹复制到解压目录中
   （与 `uup_download_windows.cmd` 同级）
3. 运行：
   - **离线版**：双击 `uup-arm64-patch.cmd`（自带全部 ARM64 工具及预补丁的
     转换器包，无需联网）
   - **在线版**：双击 `uup-arm64-patch-online.cmd`（联网下载最新版工具后打补丁）
4. 照常运行 `uup_download_windows.cmd`，流程与官方完全一致

> 两个版本都支持**全新解压、从未运行过下载脚本**的包：离线版从自带的
> 预补丁副本恢复缺失的 `files\7zr.exe` 与 `files\uup-converter-wimlib.7z`；
> 在线版则直接从 uupdump.net 获取。先打补丁、后跑下载脚本即可。

## 工具做了什么

- 备份 `files\uup-converter-wimlib.7z` → `*.7z.bak`（仅首次）
- 将 7z 转换包内 `bin\`、`bin\bin64\` 的 wimlib / 7-Zip 替换为 ARM64 原生版
  （以后重跑下载脚本，解压出来的也是原生版）
- 从 `files\converter_windows`（aria2 清单）中移除转换包下载条目，
  防止重跑时 sha256 校验失败导致重新下载 x86 原版
- 若 `bin\` 已解压且无转换在进行，直接替换实体文件
- （可选）注入 aria2c 并同步更新 `get_aria2.ps1` 的 SHA256 校验值
- 全程可重复运行，原版备份保留，可随时恢复

## 已知局限

- `cdimage.exe`（ISO 生成）暂无 ARM64 替代：可从 Windows ADK（Deployment Tools）
  提取 ARM64 版 `oscdimg.exe`，放入 `arm64\` 文件夹后重跑工具即可自动注入
  （会改名为 `cdimage.exe`，参数兼容）
- `PSFExtractor.exe`（增量补丁解压）为混合模式 .NET，无法转为 ARM64，
  属轻负载，对总耗时影响很小

## 恢复原版

- 删除 `files\uup-converter-wimlib.7z`，将 `.bak` 改回原名
- `bin\` 下文件可从 `bin_backup_x86\` 拷回

## 许可

- 本仓库中的脚本以 [MIT License](LICENSE) 发布
- 分发的第三方二进制遵循其各自许可：
  [wimlib](https://wimlib.net) (GPLv3+) ·
  [7-Zip](https://www.7-zip.org) (LGPL / BSD-3 / unRAR) ·
  [aria2](https://aria2.github.io) (GPLv2)
