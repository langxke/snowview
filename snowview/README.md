# 雪象 (SnowView)

基于AI辅助的智能日程规划和专注工具

## 项目简介

雪象是一款桌面端应用程序，旨在帮助用户高效管理学习任务、提升专注力，通过智能算法优化时间分配，实现个人目标的高效达成。

## 功能特性

- 🤖 **AI任务生成**：基于学习目标自动生成具体任务列表
- 📅 **智能日程规划**：智能分配任务到用户时间表
- 🍅 **番茄钟功能**：提升专注力的时间管理工具
- 📊 **专注统计**：详细的效率分析和数据统计
- 🎨 **现代化UI**：美观易用的用户界面
- 🌙 **主题支持**：深色/浅色主题切换

## 技术架构

项目采用 **Clean Architecture（清洁架构）** 设计模式：

```
lib/
├── core/                    # 核心模块
│   ├── constants/          # 常量定义
│   ├── errors/             # 错误处理
│   ├── theme/              # 主题配置
│   └── utils/              # 工具类
├── data/                   # 数据层
│   ├── datasources/        # 数据源
│   ├── models/             # 数据模型
│   └── repositories/       # 数据仓库实现
├── domain/                 # 业务逻辑层
│   ├── entities/           # 业务实体
│   ├── repositories/       # 仓库接口
│   └── usecases/           # 用例
├── presentation/           # 表现层
│   ├── screens/            # 页面
│   ├── widgets/            # 组件
│   └── providers/          # 状态管理
└── services/               # 服务层
    ├── database_service.dart
    ├── ai_service.dart
    ├── schedule_service.dart
    ├── focus_service.dart
    ├── notification_service.dart
    └── storage_service.dart
```

## 技术栈

- **开发框架**：Flutter 3.x
- **状态管理**：Provider
- **本地数据库**：SQLite
- **AI服务**：OpenAI API
- **桌面集成**：window_manager
- **通知服务**：local_notifications

## 开发环境

- Flutter SDK 3.9.2+
- Dart 3.0+
- 支持平台：Windows、macOS、Linux

## 快速开始

1. 克隆项目
```bash
git clone <repository-url>
cd snowview
```

2. 安装依赖
```bash
flutter pub get
```

3. 运行项目
```bash
flutter run
```

## 项目状态

🚧 **开发中** - 项目结构已搭建完成，正在开发核心功能

## 许可证

MIT License