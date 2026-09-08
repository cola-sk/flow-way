'use client';

export function BetaDownloadButton() {
  const handleClick = () => {
    const confirmed = window.confirm(
      'Beta 版为测试版本，可能不稳定，建议使用正式版。\n是否继续下载 Beta 版？'
    );
    if (confirmed) {
      try {
        if (typeof navigator !== 'undefined' && navigator.sendBeacon) {
          const blob = new Blob(
            [
              JSON.stringify({
                event: 'download_click',
                data: { type: 'beta', version: 'beta', channel: 'web_beta' },
              }),
            ],
            { type: 'application/json' }
          );
          navigator.sendBeacon('/api/logs', blob);
        } else {
          fetch('/api/logs', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              event: 'download_click',
              data: { type: 'beta', version: 'beta', channel: 'web_beta' },
            }),
          }).catch(() => {});
        }
      } catch (e) {
        console.error('Failed to log beta download_click:', e);
      }
      window.location.href = '/api/download?version=beta';
    }
  };

  return (
    <button
      onClick={handleClick}
      style={{
        display: 'inline-block',
        padding: '0.55rem 1.25rem',
        background: '#7c3aed',
        color: '#fff',
        borderRadius: 8,
        border: 'none',
        cursor: 'pointer',
        fontWeight: 600,
        fontSize: '0.95rem',
      }}
    >
      ↓ 下载 Beta 版
    </button>
  );
}