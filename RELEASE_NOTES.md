# Music Alarm v1.0.0

macOS 原生闹钟应用（SwiftUI + AppKit，纯 `swiftc` 编译，无需 Xcode 工程）。

## 本版本包含两个包（均为 Universal 通用版，Intel + Apple 芯片原生支持）

| 包 | 说明 |
|---|---|
| `MusicAlarm_v1.dmg` | V1 正式版安装镜像（本地音频闹钟）。拖入 Applications 即可安装 |
| `MusicAlarm_v2.dmg` | V2 版本（新增 Spotify 歌单闹钟）。拖入 Applications 即可安装 |

---

## V2 —— Spotify 歌单闹钟（本版新增）

- 添加闹钟页的「Alarm Sound」新增 **Segmented Control**：
  - **本地音频 (.mp3 / .m4a)**：原有导入与选择流程
  - **Spotify 歌单**：粘贴歌单链接（`https://open.spotify.com/playlist/...` 或 `spotify:playlist:...`），带实时校验提示
- 响铃时通过 **AppleScript** 控制 Spotify：
  1. 自动解析链接 → 标准 `spotify:playlist:ID`
  2. 激活 Spotify
  3. `set shuffle enabled to false`（**关闭随机播放，按顺序播放歌单**）
  4. `play track "spotify:playlist:ID"`
- 点击 **Stop / Snooze** 时执行 `tell application "Spotify" to pause` 暂停播放
- **容错回退**：Spotify 未安装 / 未运行 / 控制失败时，自动回退到内置循环提示音，保证闹钟一定响
- V2 版本号 2.0，已声明 `NSAppleEventsUsageDescription`

## V1 —— 本地音频闹钟

- 顶部大数字时钟 + 下一个闹钟倒计时
- 导入 .mp3 / .m4a 作为闹钟铃声，支持 20s 音量渐入
- 重复方式：一次 / 每天 / 工作日；支持 5 分钟稍后提醒
- 毛玻璃头部（NSVisualEffectView）与本地音频库

## 系统要求

- macOS 11.0+
- **Universal 通用版**：同时支持 Apple 芯片（arm64）与 Intel（x86_64），均可原生运行
- 当前 ad-hoc 签名，首次运行请在「系统设置 → 隐私与安全性」中允许打开

## 从源码构建

```bash
# V1（默认构建 Universal 双架构；可用 ARCHS="x86_64" 只构建单架构）
./build.sh
# V2
cd V2 && ./build.sh
# DMG 安装包
./make_dmg.sh                                  # V1 -> dist/MusicAlarm_v1.dmg
./make_dmg.sh V2/dist/MusicAlarm.app dist/MusicAlarm_v2.dmg   # V2
```

## 说明

- 在 Apple 芯片机器（或 CI 的 arm64 Runner）上用现代 Xcode / Swift 工具链执行 `build.sh` 时，会自动编译 arm64 + x86_64 并合并成 Universal 二进制
- 应用为 ad-hoc 签名，首次启动 V2 时 macOS 会请求「自动化控制 Spotify」权限，请允许
- 为保证闹钟可靠，响铃时请保持 Spotify 已安装并允许自动化控制
