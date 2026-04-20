# 🧪 Flow Way 测试套件

Flow Way 服务端测试套件用于验证相机避让路由算法的正确性和性能。

## 📋 测试文件清单

### ✅ 所有文件都是测试用例

| 文件 | 类型 | 说明 |
|------|------|------|
| `test/regression.ts` | 回归测试 | 测试相机避让算法是否存在退化，使用真实历史路线数据 |
| `test/test-route.ts` | 集成测试 | 动态加载已保存的路线，测试避让算法性能 |

---

## 🚀 快速开始

### 方式 1: 使用统一测试运行器（推荐）

```bash
# 进入 server 目录
cd server

# 运行所有测试并查看完整总结
pnpm run test:all
```

### 方式 2: 使用 npm 脚本

```bash
# 运行所有测试（简洁版）
pnpm run test

# 仅运行回归测试
pnpm run test:regression

# 仅运行动态路线测试
pnpm run test:route
```

### 方式 3: 直接使用 ts-node

```bash
# 运行回归测试
npx ts-node test/regression.ts

# 运行动态路线测试
npx ts-node test/test-route.ts
```

---

## 📝 测试详情

### 1️⃣ Regression Test (回归测试)

**文件**: `test/regression.ts`

**目的**: 确保相机避让路由算法在代码修改后仍能正常工作

**测试场景**: 瑞都公园世家南区 → 台湖大集
- 起点: `{ lat: 39.865137, lng: 116.679391 }`
- 终点: `{ lat: 39.839413, lng: 116.629009 }`

**成功标准**:
- ✅ 算法执行时间合理（通常 < 500ms）
- ✅ 返回的路线上相机数量为 **0**
- ✅ 总里程在可接受范围内

**预期输出**:
```
✅ [PASS] Regression test PASSED! Successfully avoided all cameras.
```

---

### 2️⃣ Dynamic Route Planning Test (动态路线规划测试)

**文件**: `test/test-route.ts`

**目的**: 测试已保存路线的相机避让算法

**工作流程**:
1. 从 Redis 数据库加载最新的已保存路线
2. 获取路线沿途的相机数据
3. 运行相机避让路由算法
4. 检验算法是否找到避免相机的路线

**前置条件**:
- ✅ Next.js 开发服务器运行中 (`http://localhost:3000`)
- ✅ Redis 数据库中至少有一条已保存的路线
- ✅ `/api/cameras` 接口可用

**预期输出**:
```
✅ [PASS] Route successfully avoids all cameras!
```

---

## 📊 测试输出示例

### 成功的回归测试

```
[REGRESSION TEST] Camera Avoidance Algorithm Regression Test

[INFO] Route: 瑞都公园世家南区 -> 台湖大集
[INFO] Start point: { lat: 39.865137, lng: 116.679391 }
[INFO] End point: { lat: 39.839413, lng: 116.629009 }
[INFO] Fetched cameras via API: 8
[INFO] Starting camera-avoidance route planning algorithm...

[RESULTS] ==================================
[RESULT] Execution Time: 245 ms
[RESULT] Cameras still on route: 0
[RESULT] Total Distance: 18450 meters
[RESULT] ==================================

✅ [PASS] Regression test PASSED! Successfully avoided all cameras.
```

### 完整测试套件结果

```
╔════════════════════════════════════════════════════════╗
║       Flow Way Test Suite Runner                       ║
║       Testing Camera Avoidance Routing Algorithm       ║
╚════════════════════════════════════════════════════════╝

[Checking Prerequisites]
✅ Prerequisites checked

[Running Tests]

[08:30:15] Running: Regression Test: Camera Avoidance Algorithm...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Regression Test: Camera Avoidance Algorithm PASSED (245ms)

[08:30:16] Running: Integration Test: Dynamic Route Planning...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Integration Test: Dynamic Route Planning PASSED (312ms)

╔════════════════════════════════════════════════════════╗
║                    TEST SUMMARY                        ║
╚════════════════════════════════════════════════════════╝

✅ All tests passed!
   Total Tests: 2
   Passed: 2
   Failed: 0
   Total Time: 557ms
```

---

## 🔍 诊断常见问题

### ❌ "Cannot find module" 错误

**原因**: Next.js 开发服务器未运行

**解决**:
```bash
# 在一个终端中运行开发服务器
pnpm run dev

# 在另一个终端中运行测试
pnpm run test:all
```

### ❌ "No saved routes found"

**原因**: Redis 数据库中没有已保存的路线

**解决**:
1. 在 Flow Way 应用中规划并保存至少一条路线
2. 确认数据已保存到 Redis:
   ```bash
   # 检查已保存的路线
   redis-cli hgetall saved-routes
   ```

### ❌ 测试超时

**原因**: 相机 API 响应缓慢或网络问题

**解决**:
```bash
# 检查 API 是否可用
curl http://localhost:3000/api/cameras

# 检查 Redis 连接
redis-cli ping
```

---

## 📈 CI/CD 集成

### GitHub Actions 示例

```yaml
name: Run Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '20'
      - run: cd server && pnpm install
      - run: cd server && pnpm run dev &
      - run: sleep 10  # 等待服务器启动
      - run: cd server && pnpm run test:all
```

---

## 📚 添加新测试

当需要添加新的测试用例时:

1. **在 `test/` 目录创建新文件**
   ```bash
   touch test/my-new-test.ts
   ```

2. **添加详细的 JSDoc 注释**
   ```typescript
   /**
    * Test Suite: [测试名称]
    * 
    * Purpose: [测试目的]
    * Prerequisites: [前置条件]
    * What it tests: [测试内容]
    * Usage: npx ts-node test/my-new-test.ts
    */
   ```

3. **在 `package.json` 中添加脚本**
   ```json
   "test:mynewtest": "npx ts-node test/my-new-test.ts"
   ```

4. **更新本文档**

5. **使用统一的日志格式**:
   - `[TEST]` - 测试开始/结束
   - `[INFO]` - 信息输出
   - `[RESULT]` - 测试结果
   - `[ERROR]` - 错误信息

---

## 📊 测试命令参考表

| 命令 | 说明 | 耗时 |
|------|------|------|
| `pnpm run test:all` | 运行所有测试（完整输出） | ~1s |
| `pnpm run test` | 运行所有测试（简洁模式） | ~1s |
| `pnpm run test:regression` | 仅回归测试 | ~300ms |
| `pnpm run test:route` | 仅动态路线测试 | ~300ms |
| `npx ts-node test/regression.ts` | 直接运行回归测试 | ~300ms |
| `npx ts-node test/test-route.ts` | 直接运行动态路线测试 | ~300ms |

---

## 🎯 测试覆盖范围

```
┌─────────────────────────────────────────┐
│  Flow Way Routing Algorithm Testing    │
├─────────────────────────────────────────┤
│ ✅ Camera Detection                     │
│ ✅ Route Avoidance                      │
│ ✅ Distance Optimization                │
│ ✅ Performance Metrics                  │
│ ✅ Algorithm Termination                │
│ ✅ Edge Case Handling                   │
└─────────────────────────────────────────┘
```

---

## ❓ 常见问题

**Q: 测试需要多长时间运行?**
A: 整个测试套件通常在 1 秒内完成，包括 API 调用和算法执行。

**Q: 可以在 CI/CD 管道中使用这些测试吗?**
A: 是的！使用 `pnpm run test:all` 会返回正确的退出代码（成功时为 0，失败时为 1）。

**Q: 我应该多久运行一次测试?**
A: 建议在以下情况运行:
- 修改路由算法后
- 部署到生产环境前
- 进行性能优化后
- 定期 CI/CD 检查

---

## 📞 反馈与支持

如有问题或需要添加新测试，请查看 `test/README.md` 获取详细文档。
