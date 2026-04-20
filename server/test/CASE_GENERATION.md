# Hardcoded Case 生成说明

## 目标

- 将历史保存的导航记录固化为 test 下的独立 case 文件。
- case 内坐标和途径点直接写死，不在测试运行时依赖 Redis 历史数据。
- 保留“从历史记录生成 case”的可追溯流程，方便后续 agent 按同样方式增量更新。

## 数据来源

在 `server` 目录执行以下命令，读取当前所有保存记录：

```bash
npx tsx -e "import { config } from 'dotenv'; config({ path: './.env.local' }); import { listRoutePlanRecords } from './src/lib/saved-navigation'; (async () => { const plans = await listRoutePlanRecords(); console.log(JSON.stringify(plans, null, 2)); })();"
```

说明：

- 必须显式加载 `./.env.local`，否则拿不到 Redis 配置。
- 输出中关注字段：`name`、`start`、`end`、`waypoints`、`avoidCameras`、`createdAt`。

## 生成规则

1. 每条 `avoidCameras=true` 记录生成一个独立 `.ts` 文件。
2. 文件放在 `server/test` 根目录（`run-tests.sh` 只扫描该层）。
3. 文件名使用点位名称语义，非法路径字符替换为 `-`。
4. 每个 case 统一调用 `./utils/hardcoded-case-runner`。
5. 坐标完全硬编码，不在 case 文件里调用 `listRoutePlanRecords()`。

## 文件模板

```ts
import { config } from 'dotenv';
import { resolve } from 'path';
import { runHardcodedAvoidCase } from './utils/hardcoded-case-runner';

config({ path: resolve(process.cwd(), '.env.local') });

runHardcodedAvoidCase({
  caseName: '起点 -> 终点',
  start: { name: '起点名', lat: 0, lng: 0 },
  end: { name: '终点名', lat: 0, lng: 0 },
  waypoints: [],
  retriesPerLeg: 3,
  maxTotalHits: 1,
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FAIL]', error);
    process.exit(1);
  });
```

## maxTotalHits 设定建议

- 先用当前算法跑 2~3 次，观察总命中摄像头数。
- 阈值建议取“可稳定通过的上界”，避免偶发 API 抖动导致误报。
- 若是关键回归场景，可单独设置更严格阈值并在注释中说明原因。

## 增量更新流程（未来 agent）

1. 读取 Redis 历史记录并按 `createdAt` 倒序查看。
2. 对比 `server/test` 现有 case 文件，找出新增记录。
3. 为新增记录创建新 `.ts` case 文件并硬编码坐标。
4. 执行 `bash test/run-tests.sh` 验证。
5. 若阈值不稳定，调整 `maxTotalHits` 到稳定上界并记录原因。
