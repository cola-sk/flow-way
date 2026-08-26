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
    </main>
  );
}
