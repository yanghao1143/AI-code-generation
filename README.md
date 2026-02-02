# Chi Code 🇨🇳

<p align="center">
  <img src="docs/screenshots/banner.png" alt="Chi Code Banner" width="800">
</p>

<p align="center">
  <strong>基于 Zed 的高性能中文代码编辑器</strong>
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#界面预览">界面预览</a> •
  <a href="#安装使用">安装使用</a> •
  <a href="#开发进度">开发进度</a> •
  <a href="#参与贡献">参与贡献</a>
</p>

---

## ✨ 功能特性

Chi Code 是 [Zed](https://zed.dev) 编辑器的中文深度定制版，专为中文开发者打造。

| 特性 | 描述 |
|------|------|
| 🌏 **完整中文界面** | 菜单、设置、提示、错误信息全部中文化 |
| ⚡ **极致性能** | GPU 加速渲染，启动快、响应快 |
| 🤖 **AI 原生集成** | 内置 AI 助手，支持多种模型 |
| 👥 **实时协作** | 多人同时编辑，语音通话 |
| 🎨 **现代 UI** | 简洁美观，支持自定义主题 |

## 📸 界面预览

<p align="center">
  <img src="docs/screenshots/main-editor.png" alt="主编辑器界面" width="800">
  <br>
  <em>主编辑器界面 - 完整中文菜单和工具栏</em>
</p>

<p align="center">
  <img src="docs/screenshots/command-palette.png" alt="命令面板" width="600">
  <br>
  <em>命令面板 - 中文命令搜索</em>
</p>

<p align="center">
  <img src="docs/screenshots/settings.png" alt="设置界面" width="800">
  <br>
  <em>设置界面 - 全中文配置选项</em>
</p>

<p align="center">
  <img src="docs/screenshots/ai-assistant.png" alt="AI 助手" width="800">
  <br>
  <em>AI 助手 - 智能代码补全和对话</em>
</p>

## 🚀 安装使用

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/yanghao1143/AI-code-generation.git
cd AI-code-generation

# 安装依赖 (Windows)
# 需要: Rust, Visual Studio Build Tools, CMake

# 构建
cargo build --release

# 运行
./target/release/chi-code
```

### 系统要求

- **操作系统**: Windows 10/11, macOS 12+, Linux
- **内存**: 8GB+ 推荐
- **显卡**: 支持 Vulkan/Metal/DirectX 12

## 📊 开发进度

### 国际化 (i18n) 模块

| 模块 | 状态 | 翻译条目 |
|------|:----:|:--------:|
| workspace | ✅ | ~200 |
| project_panel | ✅ | ~50 |
| title_bar | ✅ | ~30 |
| debugger_ui | ✅ | ~80 |
| git_ui | ✅ | ~100 |
| search | ✅ | ~60 |
| collab_ui | ✅ | ~90 |
| terminal_view | ✅ | ~40 |
| settings_ui | ✅ | ~150 |
| editor | ✅ | ~120 |
| diagnostics | ✅ | ~70 |
| outline | ✅ | ~25 |
| file_finder | ✅ | ~35 |
| command_palette | ✅ | ~45 |
| theme_selector | ✅ | ~20 |
| onboarding | ✅ | ~60 |
| repl | ✅ | ~40 |
| slash_commands | ✅ | ~30 |

**总计**: 1200+ 条中文翻译

### 最近更新

- **2026-02-02**: 完成 repl、git_ui、workspace 模块翻译 (+40 条)
- **2026-02-01**: 三 Agent 协作系统上线，加速翻译进度
- **2026-01-30**: 完成 slash commands 中文支持
- **2026-01-28**: 设置界面全面中文化

## 🛠️ 技术架构

```
Chi Code
├── crates/
│   ├── i18n/           # 国际化核心
│   │   └── locales/
│   │       └── zh-CN/  # 中文翻译文件
│   ├── editor/         # 编辑器核心
│   ├── workspace/      # 工作区管理
│   ├── ui/             # UI 组件库
│   └── ...
├── assets/             # 资源文件
└── docs/
    └── screenshots/    # 截图
```

## 🤝 参与贡献

欢迎贡献代码、翻译或反馈问题！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 提交 Pull Request

### 翻译贡献

翻译文件位于 `crates/i18n/locales/zh-CN/main.ftl`，使用 [Fluent](https://projectfluent.org/) 格式。

## 📬 联系方式

- **QQ**: 3257138054
- **Issues**: [GitHub Issues](https://github.com/yanghao1143/AI-code-generation/issues)

## 📄 许可证

本项目基于 [GPL-3.0](LICENSE-GPL) 许可证开源。

---

<p align="center">
  <sub>Made with ❤️ by Chi Code Team</sub>
</p>
