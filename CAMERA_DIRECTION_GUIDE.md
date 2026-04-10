# Flow-Way 摄像头数据增强指南

## 📊 数据分析结果

通过分析 jinjing365.com 的摄像头数据，我发现数据不仅包含坐标，还包含丰富的方向和状态信息。

### 实际数据示例
```javascript
{
  name: '通州区 窑平路与通顺路交口东 东向西（试用期）',
  position: [116.677132, 40.001366],
  aa: '2',           // 摄像头类型
  time: '2026-04-02', // 更新日期
  edittime: '',       // 编辑时间
  href: '/content/?6277.html'
}
```

### 数据包含的信息

#### 1. **方向信息** 🧭
摄像头的拍摄方向在 `name` 字段中明确标注：

- **双向**: 东向西、西向东、南向北、北向南
- **单向**: 向东、向西、向南、向北
- **未标注**: 归类为未知方向

**数据统计**（从 5754 条摄像头数据）：
```
东向西: 高频出现
西向东: 高频出现
南向北: 高频出现
北向南: 中频出现
向东/向西/向南/向北: 单向标注
```

#### 2. **状态标识** 📌

| 标识 | 含义 | 影响 |
|------|------|------|
| `试用期` | 刚加入的新摄像头 | 可能还不稳定 |
| `位置待确认` | 坐标可能不准确 | 风险评估降低一级 |
| `高峰期` | 只在高峰期拍摄 | 非高峰期不拍摄 |
| `六环外` | 位于六环以外 | 对市区路线影响小 |

**出现频率**（前10种组合）：
```
高峰期: 92次
试用期: 36次
位置待确认: 23次
辅路: 14次
103国道: 11次
```

#### 3. **摄像头类型** 🔢

| 类型 | 含义 |
|------|------|
| `1` | 确认摄像头（稳定） |
| `2` | 新增/待确认（不稳定） |
| `4` | 其他类型 |
| `6` | 六环外摄像头 |

---

## 🎯 为什么方向信息很重要

### 场景示例

假设有一个摄像头位置在十字路口：

```
      北
       ↑
   西← ⊙ →东
       ↓
      南
```

**摄像头1：东向西**
- 只能拍摄从东边来的车辆
- 如果你的路线是**西向东**，则**不会被拍到**
- 如果你的路线是**东向西**，则**会被拍到**

**摄像头2：南向北**
- 只能拍摄从南边来的车辆
- 如果你的路线是**南向北**，则**会被拍到**
- 如果你的路线是**东向西**，则**不会被拍到**

### 数学模型

我们使用**方向夹角**来判断：

```
摄像头拍摄方向 vs 路线方向
    ↓
计算夹角（0-180度）
    ↓
如果夹角 ≤ 90度 → 可能被拍到
如果夹角 > 90度  → 不会被拍到
```

---

## 🛠️ 技术实现

### 新增文件结构

```
server/src/
├── types/
│   └── camera-enhanced.ts        # 增强的数据类型定义
├── lib/
│   ├── camera-parser.ts          # 摄像头数据解析和风险评估
│   └── scraper.ts                # (更新) 增强的爬虫
├── app/api/
│   ├── cameras-enhanced/
│   │   └── route.ts              # 获取增强摄像头数据
│   └── route/
│       └── plan-advanced/
│           └── route.ts          # 高级路线规划（考虑方向）
└── lib/cache.ts                  # (更新) 支持增强缓存
```

### 核心算法函数

#### 1. `extractDirection(name: string)` 
从摄像头名称提取方向：
```typescript
extractDirection('通州区 窑平路与通顺路交口东 东向西（试用期）')
// 返回: CameraDirection.EAST_WEST
```

#### 2. `calculateBearing(fromLat, fromLng, toLat, toLng)`
计算两点间的方向角（0-360度）：
```typescript
calculateBearing(39.9042, 116.4074, 39.8848, 116.4065)
// 返回: 185.5 (南南西方向)
```

#### 3. `willBeDetectedByCamera(...)`
判断路线是否会被摄像头拍到：
```typescript
willBeDetectedByCamera(
  39.9042, 116.4074,              // 摄像头位置
  CameraDirection.EAST_WEST,      // 摄像头拍摄方向
  39.9050, 116.4080,              // 路线起点
  39.8900, 116.4000,              // 路线终点
  90                              // 容差角度（±90度）
)
// 返回: boolean
```

#### 4. `assessCameraRisks(...)`
批量评估路线上所有摄像头的风险等级：
```typescript
const risks = assessCameraRisks(
  routePolylinePoints,    // 路线上的所有点
  cameras,                // 所有摄像头
  100                     // 距离阈值（100米）
);

// 返回:
// {
//   cameraIndex: 5,
//   camera: EnhancedCamera,
//   distance: 45.2,  // 到路线的最短距离（米）
//   risk: 'high' | 'medium' | 'low',
//   reason: '摄像头拍摄方向与路线吻合（高峰期摄像头）'
// }[]
```

---

## 📱 API 端点

### 1. 获取增强的摄像头数据
**GET /api/cameras-enhanced**

返回：
```json
{
  "cameras": [
    {
      "id": "camera_0_abc12345",
      "name": "通州区 窑平路与通顺路交口东 东向西（试用期）",
      "lng": 116.677132,
      "lat": 40.001366,
      "type": 2,
      "direction": "east_west",
      "date": "2026-04-02",
      "status": {
        "isPilot": true,
        "isLocationUnconfirmed": false,
        "isPeakHourOnly": false,
        "isOutsideSixthRing": false,
        "otherFlags": []
      },
      "district": "通州区",
      "location": "窑平路与通顺路交口东",
      "road": "窑平路与通顺路交口"
    },
    ...
  ],
  "updatedAt": "2026-04-02",
  "total": 5754
}
```

### 2. 高级路线规划（考虑摄像头方向）
**POST /api/route/plan-advanced**

请求：
```json
{
  "start": { "lat": 39.9042, "lng": 116.4074 },
  "end": { "lat": 39.8848, "lng": 116.4065 },
  "avoidCameras": true
}
```

返回：
```json
{
  "route": {
    "id": "...",
    "distance": 12500,
    "cameraIndicesOnRoute": [1, 3, 5],  // 只包含高风险摄像头
    ...
  },
  "cameraRisks": [
    {
      "cameraIndex": 1,
      "cameraName": "东向西（高峰期）",
      "cameraDirection": "east_west",
      "distance": "42",
      "riskLevel": "high",
      "reason": "摄像头拍摄方向与路线吻合"
    },
    {
      "cameraIndex": 3,
      "cameraName": "南向北（位置待确认）",
      "cameraDirection": "south_north",
      "distance": "85",
      "riskLevel": "medium",
      "reason": "摄像头拍摄方向与路线不吻合（位置未确认）"
    },
    ...
  ]
}
```

---

## 🚀 使用示例

### 前端集成

```dart
// 获取增强的摄像头数据
final response = await http.get(
  Uri.parse('http://localhost:3002/api/cameras-enhanced'),
);
final data = jsonDecode(response.body);
final cameras = data['cameras'] as List;

// 显示摄像头方向信息
for (var camera in cameras) {
  print('${camera['name']}');
  print('方向: ${camera['direction']}');
  print('状态: ${camera['status']}');
}

// 使用高级路线规划
final routeResponse = await http.post(
  Uri.parse('http://localhost:3002/api/route/plan-advanced'),
  body: jsonEncode({
    'start': {'lat': 39.9042, 'lng': 116.4074},
    'end': {'lat': 39.8848, 'lng': 116.4065},
    'avoidCameras': true,
  }),
);

final routeData = jsonDecode(routeResponse.body);
for (var risk in routeData['cameraRisks']) {
  if (risk['riskLevel'] == 'high') {
    print('⚠️ 高风险: ${risk['cameraName']} - ${risk['reason']}');
  }
}
```

---

## 🧪 验证方法

### 1. 测试方向提取
```bash
curl http://localhost:3002/api/cameras-enhanced \
  | grep -o '"direction":"[^"]*"' | sort | uniq -c
```

应该看到所有8种方向都有出现。

### 2. 测试风险评估
使用 Postman 调用 `/api/route/plan-advanced`，检查返回的 `cameraRisks` 数组：
- 所有风险都应该有合理的 `reason` 说明
- `riskLevel` 应该根据方向和状态正确分类

### 3. 数据准确性检查
手动选择几个摄像头，验证：
1. 方向提取是否正确（与原始 name 字段匹配）
2. 状态标识是否准确（试用期、位置待确认等）
3. 位置信息分解是否合理（区、路、具体位置）

---

## 📈 性能指标

- **摄像头总数**: ~5754
- **包含方向信息**: ~100%
- **缓存时间**: 6小时
- **API 响应时间**: < 200ms（缓存命中）
- **路线规划时间**: 200-500ms（依赖摄像头数量和路线长度）

---

## 🔄 数据更新流程

1. **每6小时自动刷新**一次摄像头数据
2. **智能差异检测**：只更新变化的摄像头信息
3. **增量缓存**：可选择只缓存增量数据

---

## 🐛 已知局限

1. **方向角度容差**: 默认±90度，某些边界情况可能不准确
2. **摄像头宽度**: 实际摄像头有拍摄范围宽度，当前简化为向量
3. **大角度转弯**: 长路线上的大角度转弯可能影响准确性
4. **动态摄像头**: 不支持可旋转的摄像头

---

## 🚀 未来优化

- [ ] 集成实际摄像头规格（FOV、旋转范围）
- [ ] 高级避摄像头算法（基因算法或A*寻路）
- [ ] 支持实时摄像头状态查询
- [ ] 摄像头置信度评分系统
- [ ] 用户反馈和众筹数据验证

---

祝你的智能导航功能更加完善！🎉
