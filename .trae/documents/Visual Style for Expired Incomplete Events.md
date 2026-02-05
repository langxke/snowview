# 实施方案：过期未完成时间块灰度化

## 1. 目标
通过修改 UI 渲染逻辑，将所有结束时间早于当前时间且状态为“未完成”的时间块，显示为极浅灰色（低对比度），以降低视觉干扰并提示用户。

## 2. 修改文件 (`lib/presentation/screens/schedule/shared/widgets/event_block.dart`)

### A. 逻辑判断
在 `build` 方法中引入状态判断：
```dart
final bool isExpiredIncomplete = !event.isCompleted && event.end.isBefore(DateTime.now());
```

### B. 样式覆盖
定义一套“过期样式”变量，当 `isExpiredIncomplete` 为真时使用该套变量，否则使用原有的 `event.color` 逻辑。

*   **主色调 (Base Color)**:
    *   正常: `event.color`
    *   过期: `Colors.grey`
*   **背景透明度**:
    *   正常: 0.3 (未选) / 0.4 (选中)
    *   过期: **0.1** (极浅)
*   **边框透明度**:
    *   正常: 0.6 (未选) / 0.8 (选中)
    *   过期: **0.2** (极淡边框)
*   **文字颜色**:
    *   正常: 主色调 (透明度 0.9/0.7)
    *   过期: **Colors.grey[600]** (确保在浅灰背景上仍可读，但对比度低)

### C. 组件应用
将上述颜色逻辑应用到：
1.  `_buildMainBlock` (背景与边框)
2.  `_buildCompactLayout` (文本颜色)
3.  `_buildExpandedLayout` (文本颜色)
4.  `EventResizeHandle` (手柄颜色)

## 3. 验证
确认修改后：
*   未来的时间块颜色正常。
*   刚刚过去的未完成时间块自动变为浅灰色。
*   点击将该灰色块标记为完成后，它应立即恢复为该分类原本的鲜艳颜色（并打勾）。
