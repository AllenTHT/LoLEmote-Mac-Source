# 本机素材准备：原声与动态

本文说明如何在自己有权获取和使用素材的前提下，本机准备现有 30 枚表情。工具不授予素材许可，不上传文件，也不把生成结果加入 Git。普通使用可只配置图片，详见 [README](../README.md)。

## 固定来源与版本

- 图片、名称索引、特效系统与纹理：CommunityDragon **16.19**，这是社区资源镜像，不是 Riot 官方素材许可。
- 原声音频容器：`research_assets/audio-release.json` 指向 Riot 公开补丁 **16.19.8230722** 的 manifest。补丁可访问不等于允许在 App 中使用或重新分发声音。
- `Resources/emotes.json` 保存 30 枚表情的运行配置；`research_assets/expansion-catalog.json` 保存工具选取的 ID；其余公开 JSON 仅含查找引用与路径，不含游戏事件图或素材内容。
- 生成的游戏特效数据、索引、纹理、声音、动画与来源记录都写入被忽略的本机目录。

先预览完整准备步骤，不下载：

```sh
python3 scripts/setup_assets.py --full --plan
```

## 安装维护环境

需要 Python **3.11 或更新版本**、Git 和 Apple Command Line Tools。安装 Python 时从 [Python 官方](https://www.python.org/downloads/macos/)取得，安装后确认 `python3 --version`。维护工具不进入 App；日常构建仍只需要 Swift。

```sh
zsh scripts/setup_tools.sh
```

该命令主动联网，在项目 `.venv` 安装 `requirements-assets.txt` 的固定 Python 依赖，并在 `.asset-cache/tools` 准备：

- CDTB 1.3.0、xxhash 4.0.1、Pillow 12.3.0、CMake 3.31.6。
- wwiser `v20260808` 的 `wwiser.pyz`。
- vgmstream 提交 `7dc938fa2f210943b37c7b6511852b516ef432ab` 的上游源码归档，编译 CLI 并开启 Vorbis；其他非必需解码后端关闭。

若 Python 有多个版本，可以指定已经安装的程序，例如：

```sh
PYTHON_EXECUTABLE=python3.14 zsh scripts/setup_tools.sh
```

Ogg 与 Vorbis 也按 vgmstream 引用的固定提交从 Xiph 上游源码归档准备，避免依赖 Git 全量克隆：Ogg `fa80aae9d50096160f2b56ada35527d7aee3f746`，Vorbis `2eac96b03ff67953354cb0a649c08aa3a23267ef`。安装或编译失败时保留日志，改用图片模式，不要生成“假原声”来充数。第三方工具许可证见 [第三方说明](../THIRD_PARTY_NOTICES.md)。

## 完整准备、构建与检查

```sh
.venv/bin/python scripts/setup_assets.py --full
zsh scripts/build.sh
"dist/LoLEmote.app/Contents/MacOS/LoLEmote" --check-assets
"dist/LoLEmote.app/Contents/MacOS/LoLEmote" --check-assets --strict
```

完整模式会重新生成原声和动画；若你已经配置了自定义声音或帧图，请先另行保存，避免被生成结果替换。图片默认保留已有文件，来源记录会标明“已有本地文件，来源未核验”。只有确认要替换图片时才直接运行 `fetch_images.py --force`。

准备分为以下阶段：

1. `fetch_images.py`：按 ID 查索引，准备透明 PNG；可用 `--ids 1492 3239` 选择部分图片。
2. `setup_assets.py`：补齐英文/中文索引、表情特效总表；`fetch_catalog_sources.py` 下载对应系统和子系统，生成本机 `research_assets/expansion-sources.json`。
3. `fetch_audio_banks.py`：从固定官方补丁范围读取需要的音频容器条目，不安装或启动游戏。
4. `prepare_sounds.py --expansion`：用 wwiser 匹配事件、vgmstream 解码，保留事件延迟和相对增益，将实际事件层混合为 WAV。部分表情使用共享模板声，不声称每枚都有独有声音。
5. `setup_assets.py`：按引用准备动态纹理；`prepare_animations.py` 按纹理、原时序、层次和固定随机种子生成 3277、3278 的透明帧。
6. `publish_catalog.py`：更新本机来源记录，不重写公开运行配置。

动态是从游戏纹理和特效定义重建的桌面帧，并非录屏或官方导出的 GIF；游戏引擎的渲染和随机粒子可能有差别。

若图片、声音或动态阶段失败，报告中明确列出失败阶段，已成功准备的文件仍保留。正常检查允许缺项并打印提示；严格检查要求配置中的全部图片、声音以及声明的动态可读取。**“准备完成”的文件数量不能代替可解码检查。**

输出位置：

| 内容 | 本机位置 | 是否进入公开 Git |
|---|---|---|
| 图片、WAV、动画帧与清单 | `Resources/Emotes`、`Resources/Sounds`、`Resources/Animations` | 否 |
| 来源与版本记录 | `Resources/asset-sources.json` | 否 |
| 准备结果与失败阶段 | `.asset-cache/setup-report.json` | 否 |
| 索引、纹理、音频容器和工具 | `.asset-cache` | 否 |
| 特效系统、解码证据、动画构建记录 | `research_assets` 中被忽略的生成文件 | 否 |
| 本机 App | `dist/LoLEmote.app` | 否 |

## 手动配置与高级诊断

手动准备时以 [README 的 ID 表](../README.md#30-枚表情对应表)为准，不必运行上述完整工具。原声音效不能靠搜索一张图片或改扩展名获得；自行取得的音频可用 `afconvert` 转换，动画需要真实帧和有效清单。

本机检查支持临时指定素材根目录。它必须包含 `emotes.json`，路径只用于当前进程，不会写入个人设置：

```sh
LOLEMOTE_ASSET_ROOT="/你本机的素材根目录" \
  "dist/LoLEmote.app/Contents/MacOS/LoLEmote" --check-assets --strict
```

同一环境变量可用于本机高级构建，将指定根目录的资源复制进 App。这样的 App 可能包含第三方素材，不能当作纯源码发布包上传。

`zsh scripts/test.sh` 使用自行生成的几何图与低音量测试 WAV 验证无素材、单图和降级行为。历史的 `check_catalog.sh`、`check_lifecycle.sh` 和桌面检查工具用于完整素材的维护；先通过严格检查，在独立测试环境按其源码说明运行。实际全局键盘测试需正常桌面和对应进程的辅助功能权限，普通用户不必运行。

网络地址失效时，核对固定版本来源或采用手动配置。不要擅自换版本并沿用旧 ID、声音映射和特效图，也不要把无法核对的素材标为“游戏原始素材”。
