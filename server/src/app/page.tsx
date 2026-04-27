export default function Home() {
  return (
    <main style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>绕川 Flow-Way API</h1>
      <p>进京证摄像头绕行导航服务</p>
      <ul>
        <li>
          <code>GET /api/cameras</code> — 获取所有摄像头坐标
        </li>
        {/* <li>
          <code>GET /api/cron/refresh</code> — 刷新摄像头缓存（Cron）
        </li> */}
        <li>
          <a href="/api/download" target="_blank">下载APK</a>
        </li>
      </ul>
    </main>
  );
}
