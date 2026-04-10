# 绕川 Flow-Way

进京证摄像头绕行导航 App

## 项目结构

```
flow-way/
├── app/          # Flutter 客户端
├── server/       # Next.js API 服务端 (Vercel 部署)
└── README.md
```

## 快速开始

### 服务端

```bash
cd server
npm install
npm run dev    # 本地启动 http://localhost:3002
```

API 端点：
- `GET /api/cameras` — 获取所有摄像头坐标数据

### 客户端

```bash
cd app
flutter pub get
flutter run     # 在模拟器或真机运行
```

## 技术栈

- **客户端**: Flutter + flutter_map + 高德瓦片
- **服务端**: Next.js (App Router) + TypeScript
- **部署**: Vercel (服务端) + App Store / Play Store (客户端)
- **数据源**: jinjing365.com 摄像头坐标 (GCJ-02 坐标系)
