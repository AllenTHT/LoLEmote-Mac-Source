# 代码、工具与素材权利

作者编写的应用、准备脚本、测试和项目文档采用根目录 [MIT 许可证](LICENSE)。其中的配置名称、ID、版本和路径用于互操作与查找，不是对相关游戏内容授予许可。

公开仓库不包含 Riot 游戏图片、音频、纹理、动画帧、游戏特效数据快照或解码证据。使用者主动取得、生成并保存在本机的文件仍受其权利人的权利约束。MIT 不覆盖这些素材，也不能替代 Riot 或其他权利人的许可。项目与 Riot Games 无关联，未获其背书或赞助；参见 [Riot 政策](https://www.riotgames.com/en/legal)。

维护阶段可能使用以下第三方项目。它们由本机维护工具另行安装，不打包进入 App；使用和修改时遵守各自上游许可证，不能将本项目 MIT 声明套用于它们：

| 项目 | 用途 | 上游与许可证入口 |
|---|---|---|
| CommunityDragon / CDTB | 游戏文件格式、补丁读取与资源索引 | [CDTB](https://github.com/CommunityDragon/CDTB)、[LICENSE](https://github.com/CommunityDragon/CDTB/blob/master/LICENSE) |
| python-xxhash | 路径哈希 | [项目与许可证](https://github.com/ifduyue/python-xxhash) |
| Pillow | 本机 PNG 动画帧处理 | [项目与许可证](https://github.com/python-pillow/Pillow) |
| CMake | 维护阶段编译 vgmstream | [项目与许可证](https://github.com/Kitware/CMake) |
| wwiser | Wwise 事件解析 | [项目与许可证](https://github.com/bnnm/wwiser) |
| vgmstream | 本机音频解码 | [项目与许可证](https://github.com/vgmstream/vgmstream) |
| Vorbis / Ogg | vgmstream 的解码依赖 | [Xiph.Org](https://xiph.org/) |

CommunityDragon 是社区镜像服务，不是 Riot 官方 CDN；镜像能够访问不等于它有权转授 App 使用或再分发许可。固定来源仅为准备流程的引用。第三方下载结果、源代码和构建输出默认位于 `.asset-cache` 或 `.venv`，被 Git 忽略。
