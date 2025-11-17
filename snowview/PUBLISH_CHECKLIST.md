# GitHub 发布前检查清单

## ✅ 必须完成的项目

### 1. 文档文件
- [x] `README.md` - 项目说明文档已更新
- [x] `LICENSE` - AGPL-3.0 许可证已添加
- [x] `CONTRIBUTING.md` - 贡献指南已创建
- [ ] 添加项目截图到 `README.md` 或 `docs/screenshots/` 文件夹

### 2. 代码检查
- [ ] 运行 `flutter analyze` 确保没有错误
- [ ] 删除所有 debug 用的 `print()` 语句
- [ ] 检查是否有硬编码的 API Key（不应该有）
- [ ] 确认所有 TODO 注释都已处理或记录

### 3. .gitignore 配置
- [x] 已添加数据库文件忽略规则（`.db`, `.sqlite`, `.hive`）
- [x] 已添加环境变量忽略规则（`.env`）
- [x] 已添加用户数据目录忽略规则

### 4. 版本信息
- [ ] 更新 `pubspec.yaml` 中的版本号
- [ ] 更新 `pubspec.yaml` 中的项目描述

### 5. 敏感信息检查
- [ ] 确认没有提交任何 API Key
- [ ] 确认没有提交测试用的数据库文件
- [ ] 确认 `build/` 目录被忽略

### 6. Git 配置
- [ ] 初始化 Git 仓库：`git init`（如果还没有）
- [ ] 添加所有文件：`git add .`
- [ ] 提交初始版本：`git commit -m "Initial commit: 雪象 SnowView v1.0.0"`

### 7. GitHub 设置
- [ ] 在 GitHub 创建新仓库
- [ ] 添加远程仓库：`git remote add origin https://github.com/your-username/snowview.git`
- [ ] 推送代码：`git push -u origin main`

## 📝 推荐完成的项目

### 文档优化
- [ ] 添加应用截图
- [ ] 创建 CHANGELOG.md 记录版本变更
- [ ] 添加开发文档到 `docs/` 文件夹

### 代码质量
- [ ] 编写单元测试
- [ ] 配置 CI/CD（GitHub Actions）
- [ ] 添加代码覆盖率检查

### 用户体验
- [ ] 提供预编译的可执行文件（Releases）
- [ ] 创建安装指南视频或 GIF
- [ ] 添加使用教程

## 🚀 发布命令参考

### 检查代码
```bash
# 代码分析
flutter analyze

# 格式化代码
dart format lib/

# 查看 Git 状态
git status
```

### 初始化 Git（如果需要）
```bash
# 初始化仓库
git init

# 添加所有文件
git add .

# 查看将要提交的文件
git status

# 提交
git commit -m "Initial commit: 雪象 SnowView v1.0.0"
```

### 推送到 GitHub
```bash
# 添加远程仓库（替换为你的仓库地址）
git remote add origin https://github.com/your-username/snowview.git

# 推送到主分支
git push -u origin main

# 如果是 master 分支
git push -u origin master
```

### 创建 Release
```bash
# 创建标签
git tag -a v1.0.0 -m "Release version 1.0.0"

# 推送标签
git push origin v1.0.0
```

## ⚠️ 重要提醒

1. **API Key 安全**：绝对不要将 OpenAI API Key 提交到 GitHub
2. **用户数据**：不要提交任何测试数据库或用户数据
3. **构建产物**：`build/` 目录已在 `.gitignore` 中，不会被提交
4. **敏感配置**：确认所有敏感配置都在应用内通过 UI 设置

## 📧 发布后

- [ ] 在 GitHub 仓库设置中添加项目描述和标签
- [ ] 添加项目主题标签：`flutter`, `desktop-app`, `ai`, `productivity`
- [ ] 考虑提交到 Flutter Awesome 列表
- [ ] 在社交媒体分享项目

---

完成以上检查后，你的项目就可以安全地发布到 GitHub 了！🎉

