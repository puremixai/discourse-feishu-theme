# feishu

一个面向 Discourse 的文档风格主题。`feishu` 通过文档化的导航、话题列表和主题阅读布局，让 Discourse 社区更适合沉淀知识、经验和长期内容。

这是一个独立的 Discourse 主题实现，不是飞书官方产品，也不是参考项目的官方发行版。

在线预览：[https://xai.run](https://xai.run)

## 项目简介

`feishu` 以 Discourse 原生主题能力为基础，使用 SCSS 和 Discourse API initializer 实现，不依赖额外插件。主题在调整信息组织方式的同时，保留 Discourse 原有的发帖、搜索、分类、标签、管理和响应式能力。

## 特性

- 文档化的侧边导航和首页布局
- 文件列表风格的话题列表，支持分类、标签、摘要和置顶状态
- 更适合长内容阅读的主题页布局、作者信息和浮动工具栏
- 桌面端与移动端响应式适配
- 样式和脚本使用 `feishu-*` 命名空间，降低与其他主题或插件冲突的可能
- 不修改 Discourse 数据模型，不需要额外后端服务

## 项目信息

| 项目 | 内容 |
| --- | --- |
| 主题名称 | `feishu` |
| 当前版本 | `0.2.4` |
| 类型 | Discourse Theme |
| Discourse 版本 | `3.0.0` 及以上 |
| 许可证 | [MIT License](LICENSE) |

## 参考来源与致谢

本项目的页面结构、样式组织和交互思路参考了以下开源项目：

- [starwingcc/linuxdo-lark-ui](https://github.com/starwingcc/linuxdo-lark-ui)
- [linuxdo-lark.user.js](https://github.com/starwingcc/linuxdo-lark-ui/blob/master/linuxdo-lark.user.js)

重点参考内容包括文档式侧边导航、首页文件列表、主题上下文信息、作者区域和浮动工具等。本项目将这些设计思路重新适配到 Discourse 主题体系中，并根据 Discourse 的 DOM 结构、主题生命周期和移动端布局进行了独立实现与调整。

参考项目的版权、许可证和原始实现归其作者及原项目所有；使用或再分发相关内容时，请同时遵循原项目的说明。

## 安装

### 从 Git 仓库安装

推荐使用 Git 安装，便于后续检查更新：

1. 登录 Discourse 管理账号。
2. 打开 `管理后台 → 外观 → 主题和组件`。
3. 选择“安装主题”，再选择“从 Git 仓库安装”。
4. 填入仓库地址：

   ```text
   https://github.com/puremixai/discourse-feishu-theme.git
   ```

5. 安装后先使用预览功能检查首页、主题页和移动端，再将主题设为默认。

### 从压缩包安装

在仓库根目录执行：

```bash
git archive --format=tar.gz --output=feishu-theme-v0.2.4.tar.gz HEAD
```

然后在 Discourse 主题安装页选择“从您的设备”上传压缩包。压缩包根目录应直接包含 `about.json`、`common/`、`desktop/`、`mobile/` 和 `javascripts/`。

## 开发

```bash
git clone https://github.com/puremixai/discourse-feishu-theme.git
cd discourse-feishu-theme
git checkout -b feature/your-change
```

修改主题后：

1. 按语义递增 `about.json` 中的 `theme_version`。
2. 检查桌面端、移动端、首页、话题页和管理相关界面。
3. 使用 Discourse 的主题预览确认样式和脚本没有影响原生功能。
4. 提交并推送分支，通过 Pull Request 提交改动。

### 目录结构

```text
about.json                                  # 主题清单和版本信息
settings.yml                                # 主题设置
common/common.scss                           # 通用样式
desktop/desktop.scss                         # 桌面端样式
mobile/mobile.scss                           # 移动端样式
javascripts/discourse/api-initializers/      # Discourse 前端初始化脚本
```

## 贡献

欢迎提交 Issue 和 Pull Request。提交问题时，建议附上：

- Discourse 版本和主题版本
- 浏览器、屏幕尺寸或移动端型号
- 可复现问题的页面和操作步骤
- 必要的截图或控制台错误信息

请保持样式选择器在 `feishu-*` 命名空间内，避免引入与主题目标无关的改动。

## 更新记录

### 0.2.4

- 修复首页带摘要的置顶话题中文档图标垂直错位。
- 增加置顶图标定位回归检查。

## 许可证

本项目使用 [MIT License](LICENSE) 发布。
