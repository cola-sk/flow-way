# Flow-Way 导航功能实现指南

## 🎯 功能概览

已实现以下功能：

### 1. **导航路线规划** 🗺️
- 从任意起点到终点的路线规划
- 支持**避开摄像头**的智能路由
- 实时显示路线上的摄像头数量
- 路线距离和预计时间计算

### 2. **标记点管理** 📍
- 点击地图添加标记点
- 给标记点命名和保存
- 查看已保存的标记点
- 从标记点快速导航
- 删除不需要的标记点

### 3. **交互体验** ✨
- 地图上显示所有摄像头位置（不同类型不同颜色）
- 地图上显示用户标记的地点
- 路线显示起点(绿色)和终点(红色)
- 长按或点击地图添加标记点
- 底部信息栏显示摄像头数和标记点数

---

## 📱 前端实现 (Flutter)

### 新增文件

#### 1. `lib/models/route.dart`
- `WayPoint`: 用户标记的位置点
- `NavigationRoute`: 导航路线信息
- `RouteResponse`: API 响应数据模型

#### 2. `lib/widgets/navigation_dialog.dart`
- `NavigationDialog`: 导航对话框组件
- 输入起点和终点
- 选择是否避开摄像头

#### 3. `lib/services/api_service.dart` (更新)
新增方法：
- `planRoute()`: 规划路线
- `saveWayPoint()`: 保存标记点
- `getWayPoints()`: 获取所有标记点
- `deleteWayPoint()`: 删除标记点

#### 4. `lib/pages/map_page.dart` (更新)
核心功能：
```dart
// 显示路线
if (_currentRoute != null)
  PolylineLayer(...) // 绘制路线线条

// 显示标记点
MarkerLayer(
  markers: _wayPoints.map((wayPoint) => Marker(...))
)

// 路线规划
_planRoute(start, end, avoidCameras)

// 标记点管理
_addWayPoint(location)
_deleteWayPoint(wayPoint)
```

### 新增依赖

在 `pubspec.yaml` 中：
```yaml
polyline: ^1.0.3      # 路线绘制
uuid: ^4.0.0          # 生成唯一ID
fl_location: ^1.0.0   # 位置服务（可选）
```

---

## 🚀 后端实现 (Next.js)

### 新增文件

#### 1. `src/types/route.ts`
数据类型定义：
- `Coordinate`: 坐标
- `RouteRequest`: 路线请求
- `Route`: 路线对象
- `WayPoint`: 标记点
- `RouteResponse`: 响应数据

#### 2. `src/lib/route.ts`
核心算法：
- `calculateDistance()`: Haversine 距离公式
- `generateLinearRoute()`: 生成直线路线
- `findCamerasNearRoute()`: 检测路线附近的摄像头
- `planAvoidCamerasRoute()`: 避开摄像头的智能路由
- `createRoute()`: 创建路线对象

#### 3. `src/app/api/route/plan/route.ts`
**POST /api/route/plan**

请求：
```json
{
  "start": { "lat": 39.9042, "lng": 116.4074 },
  "end": { "lat": 39.8848, "lng": 116.4065 },
  "avoidCameras": true
}
```

响应：
```json
{
  "route": {
    "id": "uuid",
    "startPoint": { "lat": 39.9042, "lng": 116.4074 },
    "endPoint": { "lat": 39.8848, "lng": 116.4065 },
    "polylinePoints": [...],
    "distance": 12500,
    "duration": 900,
    "routeType": "avoid_cameras",
    "cameraIndicesOnRoute": [1, 3, 5],
    "createdAt": "2024-04-10T..."
  }
}
```

#### 4. `src/app/api/waypoints/route.ts`
**GET /api/waypoints**: 获取所有标记点
**POST /api/waypoints**: 创建标记点

请求（POST）：
```json
{
  "name": "公司",
  "lat": 39.9042,
  "lng": 116.4074
}
```

#### 5. `src/app/api/waypoints/[id]/route.ts`
**DELETE /api/waypoints/{id}**: 删除标记点

### 新增依赖

在 `server/package.json` 中：
```json
"uuid": "^9.0.0"
```

---

## 🧩 工作流程

### 1. 规划路线
```
用户打开导航 → 输入起点/终点 → 选择是否避开摄像头
  ↓
前端调用 POST /api/route/plan
  ↓
后端：
  1. 获取所有摄像头数据
  2. 如果避开摄像头：生成多条路线，选择摄像头最少的
  3. 否则：生成直线路线，检测附近摄像头
  4. 返回路线信息
  ↓
前端：
  1. 在地图上绘制路线
  2. 显示起点和终点标记
  3. 显示路线上有多少摄像头
  4. 缩放地图以显示整个路线
```

### 2. 添加标记点
```
用户点击地图 → 输入标记点名称
  ↓
前端调用 POST /api/waypoints
  ↓
后端：生成UUID，保存到存储
  ↓
前端：
  1. 刷新标记点列表
  2. 地图上显示新标记点（琥珀色书签图标）
  3. 更新底部信息栏计数
```

### 3. 查看标记点信息
```
用户点击地图上的标记点
  ↓
前端显示 BottomSheet：
  - 标记点名称
  - 坐标
  - 创建时间
  - 导航和删除按钮
```

---

## ⚙️ 配置说明

### 前端配置

**API 地址** (`lib/services/api_service.dart`)：
```dart
static const String _baseUrl = 'http://localhost:3002';
```
- 开发环境：`http://localhost:3002`
- iOS 模拟器：`http://localhost:3002`
- Android 模拟器：`http://10.0.2.2:3002`
- 生产环境：改为 Vercel 域名

### 后端配置

**标记点存储** (`src/app/api/waypoints/route.ts`)：
目前使用内存存储（服务器重启后丢失）

生产环境建议：
- Vercel KV (Redis)
- Supabase PostgreSQL
- MongoDB Atlas

---

## 🧪 测试说明

### 启动开发环境

1. **启动后端**
```bash
cd server
npm install
npm run dev  # 启动在 http://localhost:3002
```

2. **启动前端**
```bash
cd app
flutter pub get
flutter run
```

### 手动测试

1. **测试导航功能**
   - 点击"开始导航"按钮
   - 输入起点和终点地址
   - 勾选"尽量避开摄像头"
   - 点击"开始导航"
   - 验证路线显示和摄像头标记

2. **测试标记点**
   - 点击地图任意位置
   - 输入标记点名称并保存
   - 验证标记点出现在地图上
   - 点击标记点查看详情
   - 测试"导航到这里"和"删除"功能

3. **API 测试** (使用 Postman/curl)

规划路线：
```bash
curl -X POST http://localhost:3002/api/route/plan \
  -H "Content-Type: application/json" \
  -d '{
    "start": {"lat": 39.9042, "lng": 116.4074},
    "end": {"lat": 39.8848, "lng": 116.4065},
    "avoidCameras": true
  }'
```

获取标记点：
```bash
curl http://localhost:3002/api/waypoints
```

创建标记点：
```bash
curl -X POST http://localhost:3002/api/waypoints \
  -H "Content-Type: application/json" \
  -d '{
    "name": "我的地点",
    "lat": 39.9042,
    "lng": 116.4074
  }'
```

---

## 🐛 已知限制

1. **地址转坐标**: 目前使用固定坐标，实际应集成高德地图地址解析 API
2. **路线算法**: 简化实现，生成 3 条备选路线。生产环境应使用高德/百度地图 API
3. **标记点存储**: 内存存储，需改为数据库
4. **定位功能**: 未实现 GPS 定位，需使用 geolocator/fl_location 包

---

## 🚀 下一步优化

### 短期
- [ ] 集成高德地图地址搜索 API
- [ ] 实现 GPS 实时定位
- [ ] 添加数据库持久化（Supabase）
- [ ] 优化避开摄像头的算法

### 中期
- [ ] 支持多个途径点的路线规划
- [ ] 添加路线历史记录
- [ ] 标记点分类和收藏
- [ ] 离线地图支持

### 长期
- [ ] 实时路线导航和转向提醒
- [ ] 摄像头数据众筹更新
- [ ] 社交分享路线功能
- [ ] AR 导航界面

---

## 📝 文件总结

### 新增文件 (7个)
- `app/lib/models/route.dart` - 路线和标记点数据模型
- `app/lib/widgets/navigation_dialog.dart` - 导航对话框
- `server/src/types/route.ts` - 后端路线类型定义
- `server/src/lib/route.ts` - 路线规划算法
- `server/src/app/api/route/plan/route.ts` - 路线规划 API
- `server/src/app/api/waypoints/route.ts` - 标记点列表和创建 API
- `server/src/app/api/waypoints/[id]/route.ts` - 标记点删除 API

### 修改文件 (4个)
- `app/pubspec.yaml` - 添加依赖
- `app/lib/services/api_service.dart` - 添加新 API 方法
- `app/lib/pages/map_page.dart` - 完整重写，添加导航和标记点功能
- `server/package.json` - 添加 uuid 依赖

---

祝你的导航 App 开发顺利！🎉
