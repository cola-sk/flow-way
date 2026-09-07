'use client';

interface OfficialDownloadButtonProps {
  version: string;
}

export function OfficialDownloadButton({ version }: OfficialDownloadButtonProps) {
  const handleClick = () => {
    try {
      if (typeof navigator !== 'undefined' && navigator.sendBeacon) {
        const blob = new Blob(
          [
            JSON.stringify({
              event: 'download_click',
              data: { type: 'official', version, channel: 'web_official' },
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
            data: { type: 'official', version, channel: 'web_official' },
          }),
        }).catch(() => {});
      }
    } catch (e) {
      console.error('Failed to log download_click:', e);
    }
  };

  return (
    <a
      href="/api/download"
      onClick={handleClick}
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
      ↓ 下载最新版 v{version}
    </a>
  );
}
