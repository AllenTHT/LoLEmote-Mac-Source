# LoLEmote · Mac 桌面表情轮盘（纯源码版）

在 Mac 桌面按住组合键、移动选择、松开发送本地表情。原生 Swift / AppKit / SwiftUI，支持九格轮盘、窗口试用、大小、音量、静音和菜单栏开关，运行时无需联网。

**这个仓库不附带游戏图片、声音或动画。** 它保留 30 枚表情的配置，你在自己的 Mac 上准备素材，再生成自己的 App。有一张可读取的图片就能使用；声音和动态可以后续补齐。

适用设备：Apple Silicon Mac，macOS 13 或更新版本。其他架构尚未进行完整验收。代码采用 [MIT](LICENSE)，游戏素材不属于该许可证。获取和使用素材前，请核对来源及适用许可；公开可下载不等于获得 App 使用或重新分发授权。本项目与 Riot Games 无关联，未获其背书或赞助。参见 [Riot 官方政策](https://www.riotgames.com/en/legal)。

想让 Agent 帮忙配置：打开 [Agent 配置 Prompt](docs/AGENT_SETUP.md)，复制其中内容到能操作你本机的 Agent，并提供本项目的位置。手动配置按下面步骤进行。

## 1. 安装工具、下载源码

1. 在 GitHub 仓库页面选择 **Code → Download ZIP**，解压；也可以使用 GitHub Desktop 克隆仓库。
2. 在终端运行 `xcode-select --install`，按系统提示安装 Apple Command Line Tools。已有工具时不必重复安装，无需完整 Xcode。
3. 进入解压后的项目目录。可以先输入 `cd `（末尾留一个空格），再把 Finder 中的项目文件夹拖进终端，按回车。
4. 运行以下检查：

```sh
pwd
swift --version
xcode-select -p
```

目录内应能看到 `Package.swift`、`Sources`、`Resources` 和 `scripts`。此后的命令均在这个目录执行，路径有空格时保留引号。

普通构建只需要 Apple 命令行工具。联网准备图片另需 Python 3.11 或更新版本；包含原声和动态的完整准备方式见 [进阶素材说明](docs/ASSET_SETUP.md)。

## 2. 查找素材并核对 ID

先查 [Riot 官方开发者资料](https://developer.riotgames.com/docs/lol/#data-dragon) 和 [官方媒体资料](https://www.riotgames.com/en/press)。这些资料入口不保证提供下面每一枚表情，也不代表其中任何文件已许可用于这个 App。

可用于核对表情名称、ID 和文件路径的社区索引：

- [16.19 英文表情索引](https://raw.communitydragon.org/16.19/plugins/rcp-be-lol-game-data/global/default/v1/summoner-emotes.json)
- [16.19 中文表情索引](https://raw.communitydragon.org/16.19/plugins/rcp-be-lol-game-data/global/zh_cn/v1/summoner-emotes.json)
- [CommunityDragon](https://www.communitydragon.org/) 是社区镜像，**不是 Riot 官方 CDN，也不是素材授权方**。

可以用表中中文名、英文名及 `LOL emote + ID` 搜索。找到候选后，检查索引中同一条目的 `id`、`name`、`inventoryIcon`，避免同名、文字版或静态/动态版本混淆。网站截图、视频截图、搜索结果缩略图不能当成已确认的透明原图。

在索引中，`inventoryIcon` 通常以 `/lol-game-data/assets/` 开头。去掉这个前缀，将剩余路径转为小写，接在下面的版本地址后，即得到该版本的 PNG 地址：

```text
https://raw.communitydragon.org/16.19/plugins/rcp-be-lol-game-data/global/default/
```

记录原下载地址、版本及你核对的使用许可。游戏原图通常为 256×256，适合本工具的 Retina 显示；这里不声称有更高分辨率的官方版本。

### 30 枚表情对应表

以下文件路径都以源码的 `Resources/` 为起点。图片必需，声音与动态可选；目录中没有这些文件是公开仓库的正常状态。

| ID | 显示名称 | 英文名称 | 图片路径 | 可选声音路径 | 动态配置 |
|---:|---|---|---|---|---|
| 3239 | 弱爆 | Unworthy | `Emotes/3239.png` | `Sounds/3239.wav` | 可选静态效果 |
| 1468 | 机器人问号 | Does Not Compute | `Emotes/1468.png` | `Sounds/1468.wav` | 可选静态效果 |
| 1492 | 提莫点赞 | Scout-Approved | `Emotes/1492.png` | `Sounds/1492.wav` | 可选静态效果 |
| 1459 | 干得漂亮 | Nice | `Emotes/1459.png` | `Sounds/1459.wav` | 可选静态效果 |
| 1495 | 20投 / 白旗 | Surrender at 20 | `Emotes/1495.png` | `Sounds/1495.wav` | 可选静态效果 |
| 3354 | 拓蛙 | Towa Emote | `Emotes/3354.png` | `Sounds/3354.wav` | 可选静态效果 |
| 3177 | 笑哭我了 | Wahaha | `Emotes/3177.png` | `Sounds/3177.wav` | 可选静态效果 |
| 3186 | 笑哭我了 · 文字版 | Wahaha | `Emotes/3186.png` | `Sounds/3186.wav` | 可选静态效果 |
| 3709 | 提莫惊讶 | Oh... | `Emotes/3709.png` | `Sounds/3709.wav` | 可选静态效果 |
| 1030 | 拉克丝点赞 | Nice Try | `Emotes/1030.png` | `Sounds/1030.wav` | 可选静态效果 |
| 3270 | 流汗猫猫 | Never Again | `Emotes/3270.png` | `Sounds/3270.wav` | 可选静态效果 |
| 4125 | 急了急了 · iG | LPL: IG - Check That Out! | `Emotes/4125.png` | `Sounds/4125.wav` | 可选静态效果 |
| 3278 | 电玩 K.O. | Animated K.O. | `Emotes/3278.png` | `Sounds/3278.wav` | `Animations/3278/sequence.json` |
| 3279 | Game Over | Game Over | `Emotes/3279.png` | `Sounds/3279.wav` | 可选静态效果 |
| 3277 | 动态企鹅 | Animated D'Pengu | `Emotes/3277.png` | `Sounds/3277.wav` | `Animations/3277/sequence.json` |
| 3984 | 巴德吹喇叭 | Fanfare | `Emotes/3984.png` | `Sounds/3984.wav` | 可选静态效果 |
| 3272 | 悠米呸 | Dislike | `Emotes/3272.png` | `Sounds/3272.wav` | 可选静态效果 |
| 3138 | 诡话波比 | Heeere's Poppy! | `Emotes/3138.png` | `Sounds/3138.wav` | 可选静态效果 |
| 3160 | 琴女 · 咿呀 | Yikes | `Emotes/3160.png` | `Sounds/3160.wav` | 可选静态效果 |
| 3190 | 琴女 · 但为什么呢 | But Why? | `Emotes/3190.png` | `Sounds/3190.wav` | 可选静态效果 |
| 3933 | 琴女 · 好甜喔 | So Sweet! | `Emotes/3933.png` | `Sounds/3933.wav` | 可选静态效果 |
| 4773 | 永恩手势舞 | Yowone | `Emotes/4773.png` | `Sounds/4773.wav` | 可选静态效果 |
| 4638 | iG · 擦擦iG狗牌 | LPL: IG - 2024 | `Emotes/4638.png` | `Sounds/4638.wav` | 可选静态效果 |
| 4649 | OMG · Oh My God | LPL: OMG - Oh My God | `Emotes/4649.png` | `Sounds/4649.wav` | 可选静态效果 |
| 4635 | AL · 有伞，别怕！ | LPL: AL - Well Played | `Emotes/4635.png` | `Sounds/4635.wav` | 可选静态效果 |
| 4636 | BLG · 布噜噜干杯 | LPL: BLG - Bluelue | `Emotes/4636.png` | `Sounds/4636.wav` | 可选静态效果 |
| 4643 | TES · 纳什“搏”弈 | LPL: TES - Baron Call | `Emotes/4643.png` | `Sounds/4643.wav` | 可选静态效果 |
| 4987 | LGD · 不不不不不！Q！ | Nonono, Q! | `Emotes/4987.png` | `Sounds/4987.wav` | 可选静态效果 |
| 4091 | 岩雀流汗 | Magpie Oopsie | `Emotes/4091.png` | `Sounds/4091.wav` | 可选静态效果 |
| 4730 | 炼金捂脸 | Such Foolishness | `Emotes/4730.png` | `Sounds/4730.wav` | 可选静态效果 |

“科加斯喝茶”尚未确认正式条目，因此没有冒充已收录的文件。

## 3. 先用一张 PNG 跑起来

以提莫点赞（ID **1492**）为例：

1. 取得你有权使用的图片，确认为真正的 PNG。推荐 256×256 或更大的 8-bit RGBA 透明图片。
2. 在源码的 `Resources` 内建立 `Emotes` 文件夹。
3. 将图片命名为 `1492.png`，放到 `Resources/Emotes/1492.png`。Finder 隐藏扩展名时检查有没有误写成 `1492.png.png`。
4. 不需要先准备声音，也不需要一次放齐 30 枚。
5. 构建并检查：

```sh
zsh scripts/build.sh
"dist/LoLEmote.app/Contents/MacOS/LoLEmote" --check-assets
open "dist/LoLEmote.app"
```

成功后仓库中提莫点赞会显示“静态 · 无声音”，可以点击“试用”和装备。其他表情显示“未配置”，不能试用或装备；它们的缺项提示不会影响已配置的表情。

如果还没放任何素材，构建也能成功。App 会显示配置引导，桌面开关暂不可用。

### 可选：本机联网准备图片

在你确认可以获取和使用这些素材后，主动执行：

```sh
# 只显示将使用的来源和步骤，不下载
python3 scripts/setup_assets.py --images --ids 1492 --plan

# 只准备提莫点赞；不覆盖已有 PNG
python3 scripts/setup_assets.py --images --ids 1492

# 或准备整份 30 枚配置的图片
python3 scripts/setup_assets.py --images

zsh scripts/build.sh
```

下载结果和缺项写入 `.asset-cache/setup-report.json`，来源记录写入 `Resources/asset-sources.json`，都被 Git 忽略。脚本按固定版本与 ID 取图，不会绕过登录、付费或访问限制。网络不可用、地址失效或条目缺失会报告失败；已成功准备的图片仍可构建使用。日常构建不自动联网。

## 4. 后续补充声音和动态

### 声音

把自己有权使用的声音转成 WAV，推荐 **44,100 Hz、16-bit PCM、单声道或双声道**，再按 ID 放到 `Resources/Sounds/`。

例如提莫点赞的声音文件应为 `Resources/Sounds/1492.wav`。扩展名改成 `.wav` 不会转换音频；macOS 自带工具可以转换它支持的输入格式：

```sh
mkdir -p Resources/Sounds
afconvert -f WAVE -d LEI16@44100 "本机已有的音频.m4a" Resources/Sounds/1492.wav
```

声画对应关系应自行核对。原声音效不是图片索引中可以直接下载的 WAV，完整还原需要读取事件、提取和转换，见 [进阶说明](docs/ASSET_SETUP.md)。声音缺失或无法解码时静音播放，并在资源检查中提示。

### 动态

现有配置的动态企鹅（3277）和电玩 KO（3278）使用透明 PNG 帧与 `sequence.json`，**直接放 GIF 或 MP4 不会自动成为动态表情**。每枚动态仍需要一张仓库静态图。

`Resources/Animations/3277/sequence.json` 的最小结构示例：

```json
{
  "duration": 0.8,
  "canvasScale": 1,
  "frames": [
    {"time": 0, "image": "Animations/3277/0000.png"},
    {"time": 0.4, "image": "Animations/3277/0001.png"}
  ]
}
```

`time` 单位为秒，从 0 开始严格递增，每个值小于 `duration`；`canvasScale` 为图片画布相对于表情显示大小的比例，必须大于 0。帧路径相对于 `Resources/`，所有帧都必须可读取。这个例子仅解释格式，仓库不附带示例图片，也不冒充游戏动作。

动态清单或任意帧缺失/损坏时，整枚表情退回静态效果。原始动态纹理和时序的本机准备流程见 [进阶说明](docs/ASSET_SETUP.md)。

每次增删素材后，**从菜单栏退出旧 App，再重新运行构建脚本并打开新 App**。素材是构建时复制的；App 运行中不自动刷新。不要往已经签名的 App 包内部手动塞文件。

## 5. 使用轮盘

1. 在 App 中点击“试用”，检查图片、声音和动态，不需要辅助功能权限。
2. 点击左侧轮盘中的一个位置，再点击已配置表情，将其装备到该位置。中央加外圈共九格；没有配置图片的位置不会发送。
3. 开启“启用桌面表情”，按提示进入 **系统设置 → 隐私与安全性 → 辅助功能**，允许 **LoLEmote**。返回 App 后自动检测；必要时退出并重新打开。
4. 在桌面目标位置按住默认 **Control＋Option＋Shift** 约 **0.18 秒**，移动鼠标选择，松开发送。**Esc 或右键取消**。
5. 可调图片大小、音量和静音，设置自动保存。关闭控制窗口后仍驻留菜单栏；菜单栏可暂停、重开窗口或退出。

可以将本机生成的 App 复制到“应用程序”，但移动或重新构建后，macOS 可能需要重新添加辅助功能授权。本机构建采用 ad-hoc 签名，未做 Apple Developer ID 签名和公证。若系统拦截可信的本机构建，按系统设置的提示允许打开；不要全局关闭系统安全功能。App 不需要麦克风或屏幕录制权限。

## 6. 检查与常见问题

```sh
# 配置错误导致失败；缺少素材仅报告提示，允许部分配置
"dist/LoLEmote.app/Contents/MacOS/LoLEmote" --check-assets

# 所有配置图片、声音及声明的动态必须齐全并可读取
"dist/LoLEmote.app/Contents/MacOS/LoLEmote" --check-assets --strict

# 核心与素材降级行为测试：使用生成的几何图片和独立设置
zsh scripts/test.sh

# 核对 Git 当前文件与全部本地历史中没有素材
python3 scripts/check_public_source.py
```

窗口相关测试需要已登录的正常 macOS 桌面会话。它们用受控输入边界验证轮盘发送，不会代替真实全局快捷键的人工检查，也不会给你的 App 修改系统授权。

| 现象 | 处理方式 |
|---|---|
| 表情显示“未配置” | 检查 ID、文件名与真正的 PNG 格式；确保文件放在源码目录，再重建并重开 App。 |
| 有图片但没声音 | 声音可选；检查同 ID 的 WAV 能否解码和音量/静音设置，查看资源检查提示。 |
| 动态仍是静态 | 检查 `sequence.json`、时间顺序与每一张帧图；GIF/MP4 不能直接作为动态配置。 |
| 下载失败或版本地址失效 | 查看准备报告与来源记录；可改用手动配置。不要猜另一个表情来替换相同 ID。 |
| 配置了素材，App 没变化 | 退出旧实例，从当前源码重新构建并打开 `dist/LoLEmote.app`。 |
| 构建找不到 Swift | 安装或更新 Apple Command Line Tools，用 `xcode-select -p` 检查选中的工具。 |
| 终端路径被空格截断 | 引号包住路径，或把目录从 Finder 拖到终端。 |
| 快捷键无响应 | 至少装备一个有图片的表情；检查辅助功能权限、总开关和快捷键是否与其他 App 冲突。 |

## 7. 上传自己的纯源码仓库

本目录应拥有独立 Git 历史，**不要把原来包含素材的 `.git` 复制进来**。原有 `LoLEmote-Mac` 仓库的初始提交含素材，请检查它的可见性；这个新目录不会自动清理旧仓库或改变旧仓库设置。

1. GitHub Desktop 选择 **File → Add Local Repository**，选中这个纯源码目录。若下载 ZIP 后尚未初始化仓库，可按提示创建；不要覆盖已有 README 或忽略规则。
2. 提交前检查 Changes：应是代码、说明与选定配置，不能出现素材、缓存、设计稿或 `dist`。
3. 在终端运行 `python3 scripts/check_public_source.py`。用命令行提交时，先 `git add .`，再运行这个检查，通过后才提交；GitHub Desktop 中如有改动则填写说明并提交。
4. 使用 **Publish repository**，名称例如 `LoLEmote-Mac-Source`，选择可见性，确认发布的是这个独立副本。Desktop 会创建远端仓库，采用这条路线时不用先在网页创建同名仓库。
5. 如果你已在网页建好空仓库，则在 Desktop 的 **Repository → Repository Settings → Remote** 设置该仓库地址，再推送；不要重复创建同名仓库。

`.gitignore` 不会自动排除已经被追踪的文件，所以不能用旧仓库“删除素材后再提交”来替代新历史。以后下载的素材默认被忽略；不要使用 `git add -f` 强行提交，也不要在 Release 中上传本机包含素材的 App 或素材压缩包。

## 代码和第三方权利

[MIT 许可证](LICENSE)覆盖作者编写的工具代码与项目文档，不授予任何 Riot 或战队素材的使用权。第三方维护工具按各自的许可证使用，见 [第三方说明](THIRD_PARTY_NOTICES.md)。素材来源链接只用于查找和核对，自行下载不会自动取得 Riot 授权。本项目不声称“已登记”“已获授权”或“可公开分发官方素材”。
