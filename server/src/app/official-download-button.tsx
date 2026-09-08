'use client';

interface OfficialDownloadButtonProps {
  version: string;
}

export function OfficialDownloadButton({ version }: OfficialDownloadButtonProps) {
  return (
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
      ↓ 下载最新版 v{version}
    </a>
  );
}
