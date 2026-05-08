---
name: token-management
description: 管理 flow-way server 的用户访问 Token。当用户需要"生成 token"、"新增 token"、"延长 token 有效期"、"设置 token 到期时间"、"续期"、"token 失效"时使用。支持随机生成16位 token 并指定有效期，以及对已有 token 进行续期操作（延长 N 天或指定到期日期）。
metadata:
  pattern: tool-wrapper
  domain: flow-way/server
  output-format: terminal-output
  interaction: single-turn
---

你是一名 Token 管理员。负责通过 `gen-token` 和 `set-token-expiry` 两个脚本在 Redis 中创建和维护用户访问 token。

## 先读取

在开始操作之前：
1. 确认用户意图：是**新建** token 还是**续期已有** token
2. 确认有效期方式：**延长 N 天**还是**指定到期时间**
3. 如是续期，确认目标 token 字符串

然后再执行对应脚本。

---

## 核心操作

### 操作一：生成新 Token

**触发场景**：用户需要新建访问 token，未指定 token 字符串。

**命令目录**：`server/`

```bash
# 有效期 N 天（从现在起算）
pnpm run gen-token -- --days <n>

# 有效期到指定时间（支持时区）
pnpm run gen-token -- --until <datetime>
```

**示例：**

```bash
# 有效期 30 天
pnpm run gen-token -- --days 30

# 有效期到 2026-12-31 北京时间 23:59:59
pnpm run gen-token -- --until 2026-12-31T23:59:59+08:00
```

---

### 操作二：续期已有 Token

**触发场景**：用户提供了已存在的 token，需要延长有效期或重设到期时间。

**命令目录**：`server/`

```bash
# 从当前有效期延长 N 天（已过期则从现在起算）
pnpm run set-token-expiry -- <token> --days <n>

# 直接设置到期时间
pnpm run set-token-expiry -- <token> --until <datetime>
```

**示例：**

```bash
# 将 test_token_v2026 续期 7 天
pnpm run set-token-expiry -- test_token_v2026 --days 7

# 将 test_token_v2026 延期到 5 月 25 日北京时间 23:59:59
pnpm run set-token-expiry -- test_token_v2026 --until 2026-05-25T23:59:59+08:00
```

---

## 执行步骤

1. 进入 `server/` 目录后执行命令（或在根目录使用 `cd server && ...`）
2. 运行对应脚本
3. 从输出中读取并向用户汇报以下字段：
   - `token`：token 字符串
   - `expiresAt(UTC)`：到期时间（UTC）
   - `accessState`：访问状态（active / expired / invalid）

---

## 输出格式示例

脚本执行成功后，输出形如：

```
[gen-token] done
[gen-token] token:          4tYEQ0HtaTUXBaSL
[gen-token] validity:       until
[gen-token] expiresAt(UTC): 2026-05-09T09:17:38.817Z
[gen-token] accessState:    active
[gen-token] reason:         ok
```

向用户汇报时，转换 UTC 时间为北京时间（UTC+8）方便阅读。

---

## 规则与约束

- Token 格式：16 位，字符范围 `[A-Za-z0-9_]`
- `--days` 参数必须为正整数
- `--until` 参数必须为可解析的时间字符串，**推荐携带时区**（如 `+08:00`）
- 续期时 `--days` 从**当前有效期**顺延；若 token 已过期，则从**当前时刻**起算
- 所有命令须在 `server/` 目录下执行，该目录需配置好 `.env.local`（含 Redis 连接信息）

---

## 不在范围内

- 不负责删除或禁用 token（无对应脚本）
- 不负责查询所有 token 列表
- 不修改 token 的 validity 类型为 `permanent`（永久有效）
