import { CHANGELOG } from './changelog';
import { BetaDownloadButton } from './beta-download-button';

export default function Home() {
  const latest = CHANGELOG[0];

  return (
    <main style={{
      maxWidth: 720,
      margin: '0 auto',
      padding: '2.5rem 1.5rem 4rem',
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      color: '#1a1a1a',
      lineHeight: 1.6,
    }}>
      {/* 头部 */}
      <div style={{ marginBottom: '2.5rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, margin: 0 }}>绕川 Flow-Way</h1>
        <p style={{ color: '#666', marginTop: '0.4rem', marginBottom: '1.25rem' }}>
          进京证摄像头绕行导航 · Android 客户端
        </p>
        <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
          <a
            href="/api/download"
            style={{
              display: 'inline-block',
              padding: '0.55rem 1.25rem',
              background: '#1a56db',
              color: '#fff',
              borderRadius: 8,
              textDecoration: 'none',
              fontWeight: 600,
              fontSize: '0.95rem',
            }}
          >
            ↓ 下载最新版 v{latest.version}
          </a>
          <BetaDownloadButton />
        </div>
      </div>

      {/* 更新日志 */}
      <h2 style={{ fontSize: '1.2rem', fontWeight: 700, marginBottom: '1.25rem', borderBottom: '1px solid #e5e7eb', paddingBottom: '0.5rem' }}>
        更新日志
      </h2>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
        {CHANGELOG.map((release, i) => (
          <div key={release.version} style={{
            borderLeft: `3px solid ${i === 0 ? '#1a56db' : '#d1d5db'}`,
            paddingLeft: '1.25rem',
          }}>
            {/* 版本标题行 */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '0.25rem', flexWrap: 'wrap' }}>
              <span style={{
                background: i === 0 ? '#1a56db' : '#6b7280',
                color: '#fff',
                borderRadius: 6,
                padding: '0.1rem 0.55rem',
                fontSize: '0.8rem',
                fontWeight: 700,
                letterSpacing: '0.02em',
              }}>
                v{release.version}
              </span>
              {i === 0 && (
                <span style={{
                  background: '#dcfce7',
                  color: '#166534',
                  borderRadius: 6,
                  padding: '0.1rem 0.5rem',
                  fontSize: '0.75rem',
                  fontWeight: 600,
                }}>
                  最新版
                </span>
              )}
              <span style={{ color: '#9ca3af', fontSize: '0.85rem' }}>{release.date}</span>
            </div>

            <h3 style={{ margin: '0.35rem 0 0.75rem', fontSize: '1.05rem', fontWeight: 600 }}>
              {release.title}
            </h3>

            {/* 核心亮点 */}
            <ul style={{ margin: '0 0 0.75rem', paddingLeft: '1.1rem', color: '#374151' }}>
              {release.highlights.map((item, j) => (
                <li key={j} style={{ marginBottom: '0.4rem', fontSize: '0.93rem' }}>{item}</li>
              ))}
            </ul>

            {/* 优化与修复 */}
            {(release.improvements || release.fixes) && (
              <details style={{ fontSize: '0.88rem', color: '#6b7280' }}>
                <summary style={{ cursor: 'pointer', userSelect: 'none', marginBottom: '0.4rem' }}>
                  其他改进
                </summary>
                <ul style={{ paddingLeft: '1.1rem', margin: '0.4rem 0 0' }}>
                  {[...(release.improvements ?? []), ...(release.fixes ?? [])].map((item, j) => (
                    <li key={j} style={{ marginBottom: '0.3rem' }}>{item}</li>
                  ))}
                </ul>
              </details>
            )}

            {/* 指定版本下载 */}
            <a
              href={`/api/download?version=${release.version}`}
              style={{ display: 'inline-block', marginTop: '0.75rem', fontSize: '0.82rem', color: '#6b7280', textDecoration: 'underline' }}
            >
              下载 v{release.version}
            </a>
          </div>
        ))}
      </div>
    </main>
  );
}

