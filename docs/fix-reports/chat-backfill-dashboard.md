# 聊天翻译回填与仪表盘变更记录

## 背景

聊天消息数量通常远高于帖子数量，继续复用帖子翻译的回填速率和时间范围，会让历史聊天翻译消耗过多 token 和执行时间。本次将聊天历史回填拆成独立设置，并提供频道范围选择和管理端进度仪表盘。

## 新增限制

- `ai_chat_translation_backfill_hourly_rate`：聊天历史回填每小时处理量，默认 `0`。
- `ai_chat_translation_backfill_max_age_days`：聊天历史回填最大消息年龄，默认 `0`。
- `ai_chat_translation_allowed_channel_ids`：允许翻译的公开聊天频道 ID 列表，留空表示所有公开聊天频道。

## 触发条件与影响范围

- 两个 backfill 设置任一为 `0` 时，聊天历史回填不会扫描和翻译旧消息。
- 设置频道 ID 列表后，实时聊天翻译候选和历史回填候选都只包含这些公开频道。
- 帖子、话题、分类、标签翻译不受影响，仍使用 `discourse-ai` 原有设置。
- 私信范围、bot 内容和最大消息长度仍沿用既有 AI 翻译设置，没有新增隐藏兜底。

## 测试方式

- RSpec：`timeout 60s docker exec -u discourse:discourse -w "/src" -e LOAD_PLUGINS=1 "discourse_dev" bundle exec rspec "plugins/ai-chat-translation/spec"`，结果 `22 examples, 0 failures`。
- 前端：ESLint 和 Prettier check 通过。
- 浏览器：Codex 内置浏览器打开 `/admin/plugins/ai-chat-translation/dashboard`，确认仪表盘、回填设置、频道列表和进度区正常渲染。

## 风险

- 由于默认关闭聊天历史回填，升级后不会自动补翻历史聊天；管理员需要在仪表盘或站点设置里显式配置速率和天数。
- 频道列表留空表示所有公开频道，若站点只希望少量频道翻译，需要明确勾选并保存频道范围。
