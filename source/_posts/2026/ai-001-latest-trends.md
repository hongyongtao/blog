---
title: OpenClaw 万字拆解：一条消息如何跑完整个 Agent Runtime
date: 2026-03-21 22:00:00
author: 洪致知
tags:
- AI
- Agent
- 系统架构
- 技术日志
preview: /_media/images/2026/ai-001-latest-trends/img-01.jpg
introduce: |
    从一条真实消息的执行链路出发，系统化拆解 OpenClaw 的运行时设计：协议适配、路由分发、会话治理、上下文组装、工具调用、记忆索引与多 Agent 协作。
---

> 原文已做技术向整理，移除了推广信息、作者标识与无关内容，仅保留工程实现相关部分。

## 阅读导航

- 先看「十五、总结」了解全局结论
- 再看「一、整体架构」和「四、路由治理」建立主干认知
- 最后按需阅读「八~十四」深入到记忆、技能与多 Agent 协作细节

## 3 分钟结论

1. OpenClaw 的核心不是“会聊天”，而是 **运行时治理能力**。  
2. 关键工程价值来自：协议收束、幂等去重、会话车道、上下文压缩、错误回退。  
3. 多 Agent 的落地重点不在“多”，而在 **边界与回流机制**：谁拆任务、谁汇总、谁对最终结果负责。

OpenClaw 常被当作“会聊天、会调工具”的 Agent 应用来看待。  
但从工程实现角度，它更接近一个 **Agent Runtime + Gateway**：把消息接入、会话治理、上下文管理、技能注入、工具调用、状态持久化、多 Agent 协作全部串成可运行、可扩展、可治理的链路。

![](/_media/images/2026/ai-001-latest-trends/img-02.png)

为了更直观，我们用一个典型请求贯穿全文：

> 帮我整理今天的重要邮件，提炼待办，并生成一份给老板的简报。

---

## 一、整体架构：五层抽象

OpenClaw 的架构可以抽象为五层：

1. **用户接口层**：CLI / Web / App / WebSocket API  
2. **Gateway 核心层**：连接管理、接入、配置热加载、健康检查  
3. **消息处理层**：执行器、路由、会话、媒体、出站  
4. **扩展插件层**：通道插件、技能系统、sub-agent  
5. **基础设施层**：配置密钥、日志、任务、事件总线、记忆检索、安全沙箱

![](/_media/images/2026/ai-001-latest-trends/img-03.png)

一条消息的执行主线是：

**消息源 -> 协议适配 -> 路由分发 -> 会话构建 -> Agent 执行 -> 响应投递 -> 状态持久化**

![](/_media/images/2026/ai-001-latest-trends/img-04.png)

---

## 二、消息进门：先做协议适配

不同通道（钉钉、飞书、Telegram、Discord、WebSocket）消息结构天然异构。  
OpenClaw 不让核心逻辑直接接触外部原始格式，而是先统一收敛成 `MsgContext`。

```ts
interface MsgContext {
  Body: string;
  BodyForAgent?: string;
  BodyForCommands?: string;
  RawBody?: string;
  SessionKey: string;
  Provider: string;
  Surface?: string;
  ChatType?: "direct" | "group";
  SenderId?: string;
  SenderName?: string;
  SenderUsername?: string;
  OriginatingChannel?: string;
  OriginatingTo?: string;
  AccountId?: string;
  MessageThreadId?: string;
  CommandAuthorized?: boolean;
  MessageSid?: string;
  GatewayClientScopes?: string[];
}
```

这样后续处理层只面向统一模型，不被通道细节污染。

![](/_media/images/2026/ai-001-latest-trends/img-05.png)

---

## 三、统一入口：dispatchInboundMessage

所有入站最终都收束到统一入口，典型逻辑是：

```ts
export async function dispatchInboundMessage(params) {
  const finalized = finalizeInboundContext(params.ctx);
  return await withReplyDispatcher({
    dispatcher: params.dispatcher,
    run: () => dispatchReplyFromConfig({
      ctx: finalized,
      cfg: params.cfg,
      dispatcher: params.dispatcher,
      replyOptions: params.replyOptions,
      replyResolver: params.replyResolver,
    }),
  });
}
```

这里核心是两步：

- 先 `finalizeInboundContext` 做最终标准化  
- 再进入统一回复分发主干

![](/_media/images/2026/ai-001-latest-trends/img-06.png)

---

## 四、路由治理：去重、拦截、目标 Agent 选择

### 1) 幂等去重

生产环境中，Webhook 重试和网络抖动会导致重复投递。  
OpenClaw 会构建幂等键，避免同一消息被重复执行。

```ts
export function buildInboundDedupeKey(ctx: MsgContext): string | null {
  const provider = normalizeProvider(
    ctx.OriginatingChannel ?? ctx.Provider ?? ctx.Surface
  );
  const messageId = ctx.MessageSid?.trim();
  if (!provider || !messageId) return null;

  const peerId = resolveInboundPeerId(ctx);
  if (!peerId) return null;

  const sessionKey = ctx.SessionKey?.trim() ?? "";
  const accountId = ctx.AccountId?.trim() ?? "";
  const threadId = ctx.MessageThreadId ? String(ctx.MessageThreadId) : "";

  return [provider, accountId, sessionKey, peerId, threadId, messageId]
    .filter(Boolean)
    .join("|");
}
```

默认 TTL 常见配置是 20 分钟。

![](/_media/images/2026/ai-001-latest-trends/img-07.png)

### 2) 控制命令拦截

像 `/stop` 这类控制命令会被优先处理，而不是继续进入任务链路。

### 3) started 快速响应

Web 场景会先返回 started，再异步执行，降低用户感知等待。

---

## 五、会话路由与 sessionKey

OpenClaw 会先确定“这条消息归谁处理”：

- Web 内部通道常可直接带 `sessionKey`
- 外部通道按绑定规则匹配目标 Agent（通道、账户、peer、角色等）

确定后构造会话键，典型形式：

- `assistant:main`
- `assistant:whatsapp:direct:+1234567890`
- `assistant:discord:channel:987654321`

这个键直接决定后续会话隔离与并发控制。

---

## 六、车道机制：保证顺序与系统吞吐

同一 `sessionKey` 串行执行，避免并发乱序导致上下文污染。  
同时可配置全局并发上限，防止系统被瞬时流量打爆。

![](/_media/images/2026/ai-001-latest-trends/img-08.png)

---

## 七、执行前上下文组装

真正调用模型前，OpenClaw 会按顺序组装：

**系统提示词 -> 技能提示 -> 对话历史 -> 当前消息**

这个顺序本质上定义了模型认知层级。

![](/_media/images/2026/ai-001-latest-trends/img-09.png)

---

## 八、Bootstrap 与记忆召回规则

系统提示词通过工作区文件注入，而不是硬编码大段 prompt。常见文件包括：

- `AGENTS.md`
- `SOUL.md`
- `TOOLS.md`
- `IDENTITY.md`
- `USER.md`
- `HEARTBEAT.md`
- `BOOTSTRAP.md`
- `MEMORY.md` / `memory.md`

并且会显式要求：涉及历史决策/偏好/待办时，优先走记忆检索再回答。

---

## 九、Skills：不仅是工具列表

Skills 的作用不是“暴露函数名”，而是先把能力边界、使用方式、调用约束注入模型，再由运行时执行真实工具。

典型流程：

1. 发现（工作区/用户目录/内置/插件）
2. 过滤（平台/通道/权限/黑白名单）
3. 安全策略（profile、sandbox、sub-agent 继承）
4. 生成技能提示并注入上下文

![](/_media/images/2026/ai-001-latest-trends/img-10.png)

---

## 十、会话历史与压缩

会话一般双层存储：

- 轻量索引：`sessions.json`
- 完整转录：`{sessionId}.jsonl`

历史加载时会按 token 预算回溯读取。  
当上下文接近上限，系统会：

- 限制历史轮次
- 截断工具结果
- 分块摘要压缩早期历史
- 必要时切换更大上下文模型或降级策略

![](/_media/images/2026/ai-001-latest-trends/img-11.png)

---

## 十一、记忆系统与索引

OpenClaw 通常区分：

- 长期记忆：`MEMORY.md` / `memory.md`
- 每日记忆：`memory/YYYY-MM-DD.md`

并维护独立索引（如 `~/.openclaw/memory/index.db`）支持：

- 向量检索
- 全文检索
- 增量同步与重建

这让记忆从“文本备忘录”升级为可检索知识层。

![](/_media/images/2026/ai-001-latest-trends/img-12.png)

---

## 十二、运行期执行：流式、工具调用、容错回退

在执行阶段，系统会：

- 用 SSE / WebSocket 流式输出
- 在推理中断点调用工具，再回注结果继续推理
- 面对限流/超时/鉴权失败做模型或策略回退

![](/_media/images/2026/ai-001-latest-trends/img-13.png)

---

## 十三、任务完成后的收尾

完成响应后仍有关键收尾步骤：

- 回复投递到目标通道
- 会话与转录持久化
- 释放车道锁与并发额度
- 标记幂等键、清理归档历史

![](/_media/images/2026/ai-001-latest-trends/img-14.png)

---

## 十四、多 Agent 协作如何落地

复杂任务可拆为主从协作：

- 主 Agent 拆分任务
- 通过 `sessions_spawn` 创建子 Agent
- 子 Agent 完成后结果回流主 Agent
- 主 Agent 汇总并最终回复

创建子 Agent 前会做深度、并发、权限、沙箱等校验，避免递归失控和资源耗尽。

![](/_media/images/2026/ai-001-latest-trends/img-15.png)

![](/_media/images/2026/ai-001-latest-trends/img-16.png)

![](/_media/images/2026/ai-001-latest-trends/img-17.png)

---

## 十五、总结

OpenClaw 的关键价值不在“会不会聊天”，而在它把消息执行全过程做成了可治理、可扩展、可追踪、可恢复的运行时链路。

它的核心特征可以概括为四点：

1. **分层清晰**：通道、运行时、执行、扩展、基础设施职责边界明确  
2. **运行时导向**：去重、车道、压缩、回退、清理等机制完备  
3. **可扩展性强**：插件、技能、子 Agent、记忆索引均可演进  
4. **具备协作雏形**：从单 Agent 走向任务拆解与层级协作

![](/_media/images/2026/ai-001-latest-trends/img-18.png)

![](/_media/images/2026/ai-001-latest-trends/img-19.png)

![](/_media/images/2026/ai-001-latest-trends/img-20.png)

![](/_media/images/2026/ai-001-latest-trends/img-21.png)

![](/_media/images/2026/ai-001-latest-trends/img-22.png)

---

## 十六、实践建议（给落地团队）

- 先做单通道 + 单 Agent 跑通闭环，再引入多 Agent  
- 先把幂等、并发、超时、回退做稳，再追求工具数量  
- 记忆系统优先保证“可检索 + 可追溯”，再优化“智能写入”  
- 把链路指标做全：入站耗时、模型耗时、工具耗时、失败率、重试率
