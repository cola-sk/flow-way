import { BetaDownloadButton } from '../beta-download-button';

export default function BetaPage() {
  return (
    <main
      style={{
        maxWidth: 640,
        margin: '0 auto',
        padding: '2.5rem 1.5rem 4rem',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        color: '#1a1a1a',
        lineHeight: 1.6,
      }}
    >
      <div style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, margin: 0 }}>
          绕川 Flow-Way Beta
        </h1>
        <p style={{ color: '#666', margin: '0.4rem 0 0' }}>
          Android 测试版本下载
        </p>
      </div>

      <section
        style={{
          padding: '1.25rem',
          border: '1px solid #ddd6fe',
          borderRadius: 12,
          background: '#faf5ff',
        }}
      >
        <h2 style={{ margin: '0 0 0.6rem', fontSize: '1.1rem', color: '#5b21b6' }}>
          测试版说明
        </h2>
        <p style={{ margin: '0 0 0.75rem', color: '#4b5563', fontSize: '0.93rem' }}>
          Beta 版连接 Preview 服务，用于体验和验证尚未正式发布的功能，可能存在不稳定或兼容性问题。
        </p>
        <p style={{ margin: '0 0 1.1rem', color: '#4b5563', fontSize: '0.93rem' }}>
          如需日常使用，请前往正式版下载页获取稳定版本。
        </p>
        <BetaDownloadButton />
      </section>

      <section style={{ marginTop: '2rem' }}>
        <h2
          style={{
            margin: '0 0 0.9rem',
            paddingBottom: '0.5rem',
            borderBottom: '1px solid #e5e7eb',
            fontSize: '1.2rem',
            fontWeight: 700,
          }}
        >
          本次测试更新
        </h2>
        <ul style={{ margin: 0, paddingLeft: '1.2rem', color: '#374151' }}>
          <li style={{ marginBottom: '0.65rem' }}>
            导航播报改用腾讯路线返回的结构化动作；当接口提供数据时，可正确展示和播报进入辅路、进入主路、匝道、出口、上桥、下桥等特殊路段。
          </li>
          <li style={{ marginBottom: '0.65rem' }}>
            详细播报模式会为特殊路段提供远、中、近三次提醒，最早可在前方 1 公里预告；简洁模式保持 150 米预告和临近执行提示。
          </li>
          <li style={{ marginBottom: '0.65rem' }}>
            不再根据自然语言关键词猜测左右或特殊动作，避免将路线指令误解为错误的变道提示。
          </li>
          <li>
            此测试包连接独立的 Preview 服务，与正式版数据和发布入口隔离。
          </li>
        </ul>
      </section>
    </main>
  );
}
