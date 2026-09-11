# 余时

余时是一款 Flutter 本地优先的个人时间安排应用。它服务于工作之外同时维护个人项目、骑行、私事和长期学习计划的人：打开首页便知道今天先做什么，也允许完成一件后安心停下。

## 当前可用

- 今天：首页直接显示今日重点、其他安排、时间和预计时长；支持完成、撤销、改到明天和归档。
- 快速记录：一句话保存到本地收集箱，可一键安排到今天。
- 节奏：以一周视图查看每天实际安排，长期计划可设为每日、工作日、指定星期或每周次数。
- 项目：记录项目及“我为什么在意它”，支持暂停、恢复和归档。
- 今日计划图片：本地生成 PNG 预览，可保存相册或打开系统分享面板；私密任务默认不进入图片。
- 数据管理：导出完整 JSON 备份；导入前预览新增、重复和冲突，可合并或完整替换。
- 本地存储：业务数据存入 SQLite，无需账号与网络。

提醒权限和系统通知尚未接入，任务中的时间目前用于排期与展示。

## 项目结构

```text
lib/
  app_controller.dart       应用状态与操作
  data/local_repository.dart SQLite、导入与导出
  domain/                    数据模型和排期规则
  ui/                        页面、主题与功能图标
assets/
  branding/app-icon.png      应用图标源文件
  fonts/                     中文编辑风字体
docs/                        产品、流程、设计和数据契约
```

## 运行与验证

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

Android 安装包：

```bash
flutter build apk --release
```

本次已构建的可安装文件位于 `release/yushi-v0.1.0.apk`。

## 文档

- [产品说明](docs/product.md)
- [业务流程](docs/business-flow.md)
- [视觉与图标规范](docs/design-system.md)
- [数据契约](docs/data-contract.md)
