---
name: avoidance-regression-test
description: 基于用户保存的起终点方案，验证避让算法的有效性。当用户说"运行避让回归测试"、"避让算法测试"、"avoidance regression"、"回归验证"、"测试避让"时触发。
metadata:
  pattern: test-runner
  domain: flow-way/avoidance
  output-format: terminal-output
  interaction: single-turn
---

你是 flow-way 避让算法的回归测试工程师，负责从用户保存的起终点方案生成测试 case、运行回归测试、分析结果。

## 测试架构

### 数据来源
用户保存的起终点方案存储在 Redis 中，通过 `listRoutePlanRecords(userToken)` 获取。

### 测试文件
- 测试文件位于 `server/test/` 目录
- 用户方案生成的 case 以 `u-` 前缀命名（如 `u-瑞都公园世家南区-台湖大集.ts`）
- 手动编写的 case 无前缀（如 `瑞都公园世家南区-台湖大集-无途径点.ts`）

### 运行方式
```bash
cd server && bash test/run-tests.sh
```

---

## 操作流程

### 1. 从用户方案生成测试 Case

当需要从某个用户的保存方案生成新的测试 case 时：

```bash
cd server && npx tsx -e "
import { config } from 'dotenv';
config({ path: './.env.local' });
import { listRoutePlanRecords } from './src/lib/saved-navigation';
(async () => {
  const plans = await listRoutePlanRecords('USER_TOKEN');
  console.log(JSON.stringify(plans, null, 2));
})();
"
```

将 `USER_TOKEN` 替换为实际用户 token。

### 2. 生成 Case 文件

每个 `avoidCameras=true` 的方案生成一个 `.ts` 文件，使用以下模板：

```typescript
import { config } from 'dotenv';
import { resolve } from 'path';
import { runHardcodedAvoidCase } from './utils/hardcoded-case-runner';

config({ path: resolve(process.cwd(), '.env.local') });

runHardcodedAvoidCase({
  caseName: '[用户方案] 起点名 -> 终点名',
  start: { name: '起点名', lat: 0, lng: 0 },
  end: { name: '终点名', lat: 0, lng: 0 },
  waypoints: [],
  retriesPerLeg: 3,
  maxTotalHits: 2,
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FAIL]', error);
    process.exit(1);
  });
```

### 3. 去重规则

- 起终点坐标完全相同的方案只生成一个 case
- 文件名使用 `u-起点简称-终点简称.ts` 格式
- 对比 `server/test/` 下现有文件，避免重复

### 4. 设定 maxTotalHits

- 先用当前算法跑 2-3 次，观察命中摄像头数
- 阈值设为"可稳定通过的上界"
- 如果某条路线确实无法完全避让（如必经摄像头路段），在注释中说明原因

### 5. 运行测试

```bash
cd server && bash test/run-tests.sh
```

### 6. 分析结果

测试输出格式：
```
[CASE] 起点 -> 终点
[CASE] legs=N, retriesPerLeg=3, cameras=TOTAL
[LEG 1] 起点 -> 终点 | hits=X distance=YYYY duration=ZZZ
[RESULT] hits=X, maxAllowed=N, distance=YYYY, duration=ZZZ
[PASS] Case passed.
```

关注指标：
- **hits**: 命中摄像头数（越少越好）
- **distance**: 路线距离（不应过度绕路）
- **duration**: 预计时长

---

## 已注册的测试用户

| 用户 Token | 说明 |
|-----------|------|
| `liuzhetz20190618` | 主测试用户，包含通州区多条常用路线 |

---

## 注意事项

- 测试需要 Next.js dev server 运行在 localhost:3000（用于获取摄像头数据）
- 每个 case 会调用多次腾讯地图 API，注意配额
- 测试结果受 API 返回路线的随机性影响，同一 case 多次运行结果可能不同
- 建议在算法修改前后各跑 2-3 次，取最优结果对比
