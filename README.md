# feishu

XAI.RUN 的 Discourse 文档风格主题。它参考了 LinuxDo Lark UI 的页面结构和交互逻辑：左侧文档导航、首页文件列表、主题正文布局、作者信息和浮动工具栏；同时保留论坛原有的内容、发帖、搜索、标签、分类和管理能力。站点 Logo 继续使用 XAI.RUN 的无文字图标。

## 本地检查

在仓库根目录执行：

```powershell
.\scripts\validate-feishu-theme.ps1
.\scripts\test-feishu-reference-parity.ps1
.\scripts\test-feishu-pinned-icon.ps1
tar -czf .\dist\feishu-theme-v0.2.4.tar.gz -C .\feishu .
```

压缩包内应直接包含 `about.json`、`common/`、`desktop/`、`mobile/` 和 `javascripts/`，不要再多套一层工作区目录。

## 首次安装到 Discourse

1. 登录 `https://xai.run` 管理账号。
2. 打开 `管理后台 → 外观 → 主题和组件`，地址为 `https://xai.run/admin/config/customize/themes`。
3. 选择安装主题，再选择“从本地设备”，上传 `dist/feishu-theme-v0.2.4.tar.gz`。
4. 安装成功后先预览，确认首页和主题页正常，再将 `feishu` 设为默认主题。

主题内容由 Discourse 保存，不需要把源码复制到 Docker 容器内，也不需要修改 Nginx 或 Docker Compose。

## 后续更新：推荐 Git 方式

1. 将 `feishu/` 目录推送到 GitHub 或 GitLab 仓库。
2. 在 Discourse 主题安装页选择“从 Git 仓库安装”，填入仓库地址。
3. 以后修改 `about.json` 的 `theme_version`，提交并推送。
4. 在主题详情页点击“检查更新”，确认差异后选择“更新到最新版本”。
5. 更新后检查首页、主题页、登录后的发帖编辑器和移动端；若有问题，先切回旧主题。

主题使用到的图片、字体等资源必须放在 Git 仓库的 `assets/` 中。不要只在远程主题后台临时上传资源，否则远程更新可能清理仓库中不存在的上传内容。

## 本地压缩包更新

如果暂时不使用 Git：

1. 修改 `feishu/` 源码并递增 `theme_version`。
2. 运行验证脚本和打包命令。
3. 在主题安装页上传新版压缩包；Discourse 会创建新的主题 ID，不会原地覆盖旧主题。
4. 预览新主题，确认后勾选“主题默认启用”并保存；旧主题先保留作为回滚版本。
5. 验证无误后，再按需在主题列表中清理旧版本。
本次线上版本为 `feishu 0.2.4`，修复首页带摘要的置顶话题中文档图标垂直错位；旧版本没有删除。
