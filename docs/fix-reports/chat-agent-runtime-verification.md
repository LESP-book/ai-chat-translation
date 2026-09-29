# Chat 独立 Agent 运行验证

## 背景与判断

独立 Agent 配置实现曾将 `AiAgent.enabled` 作为翻译前置条件，导致存在且模型可解析的 Agent 1 被拦截。此前交接已移除该条件；本次核对官方翻译调用语义与运行结果，没有再修改业务代码。

当前配置：Chat Agent 1，模型 `gpt-5.6-luna`；目标语言 `en`、`ja`、`zh_CN`。语言检测继续使用官方检测 Agent。

旧消息不会在配置修复后立即重试：实时任务关闭 Sidekiq 自动重试；历史语言检测每 5 分钟运行，历史译文回填每 15 分钟运行。检查期间观察到旧消息 1–4 被后台语言检测写入 locale，但开始检查时尚无译文。这不是检测失败的证据。

## 本地验证

环境：`localhost:3000`，`discourse_dev` 容器，运行副本 `/src/plugins/ai-chat-translation`。

- 首页 HTTP 返回 200。
- Agent / 模型解析、启用判断通过，Sidekiq 正常运行。
- 对消息 4 执行一次 `Jobs::DetectTranslateChatMessage`，成功保存英文、日文译文。
- 通过正式 `Chat::CreateMessage` 服务在频道 2 创建明确标注的测试消息 5、6，使用现有用户 1 的 Guardian，不绕过权限。
- 未手动执行这两条新消息的翻译任务；正常创建事件与 Sidekiq 自动完成语言检测及翻译。
- 消息 5：中文原文，生成英文和日文译文。
- 消息 6：英文原文，生成日文和简体中文译文。
- 最近对应模型调用审计状态均为 200，模型为 `gpt-5.6-luna`。
- `LocalizationPayloadQuery` 对消息 5 的英文请求、消息 6 的中文请求均返回正确 cooked 译文和 source_hash。
- 插件 RSpec：48 examples，0 failures。

命令：

```sh
docker exec -u discourse -w /src -e LOAD_PLUGINS=1 discourse_dev \
  bundle exec rspec plugins/ai-chat-translation/spec
```

## 边界

本次验证了实际模型调用、后台实时处理、数据库译文和前端所用 payload 查询；没有执行浏览器视觉交互验收。

译文按用户界面语言选择，不代表一条消息会在当前界面同时显示所有语言。用户 1 的 locale 为 en，站点默认语言为 zh_CN，自动翻译偏好开启。

未修改站点设置、Agent 配置或回填参数；未主动启动整批回填，未重启服务。测试消息 5、6 保留在频道中以便核对。本次真实调用会产生模型费用，后台已有自动回填仍按原配置运行。未提交、推送或部署。
