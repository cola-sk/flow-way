'use client';

import { useState } from 'react';

const WECHAT_ID = 'kero_wi';
const XIANYU_URL = 'https://m.tb.cn/h.RZUBs4W?tk=VoEy5pFEchA';

export function ContactMeButton() {
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(WECHAT_ID);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      const textarea = document.createElement('textarea');
      textarea.value = WECHAT_ID;
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleOpenXianyu = () => {
    window.open(XIANYU_URL, '_blank');
    setOpen(false);
  };

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        style={{
          display: 'inline-block',
          padding: '0.55rem 1.25rem',
          background: '#6E5E0D',
          color: '#fff',
          borderRadius: 8,
          border: 'none',
          cursor: 'pointer',
          fontWeight: 600,
          fontSize: '0.95rem',
        }}
      >
        联系我
      </button>
      {open && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0,0,0,0.4)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999,
          }}
          onClick={(e) => {
            if (e.target === e.currentTarget) setOpen(false);
          }}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: '1.5rem',
              maxWidth: 360,
              width: '90%',
              boxShadow: '0 4px 24px rgba(0,0,0,0.15)',
            }}
          >
            <h3 style={{ margin: '0 0 0.75rem', fontSize: '1.1rem', fontWeight: 700 }}>联系我</h3>
            <p style={{ margin: '0 0 1rem', fontSize: '0.9rem', color: '#555' }}>
              微信号: <strong>{WECHAT_ID}</strong>
            </p>
            <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center' }}>
              <button
                onClick={handleCopy}
                style={{
                  padding: '0.5rem 1rem',
                  background: copied ? '#dcfce7' : '#f3f4f6',
                  color: copied ? '#166534' : '#1a1a1a',
                  borderRadius: 8,
                  border: copied ? '1px solid #86efac' : '1px solid #d1d5db',
                  cursor: 'pointer',
                  fontWeight: 600,
                  fontSize: '0.85rem',
                }}
              >
                {copied ? '已复制' : '复制微信号'}
              </button>
              <button
                onClick={handleOpenXianyu}
                style={{
                  padding: '0.5rem 1rem',
                  background: '#6E5E0D',
                  color: '#fff',
                  borderRadius: 8,
                  border: 'none',
                  cursor: 'pointer',
                  fontWeight: 600,
                  fontSize: '0.85rem',
                }}
              >
                打开闲鱼咨询
              </button>
            </div>
            <button
              onClick={() => setOpen(false)}
              style={{
                display: 'block',
                margin: '1rem auto 0',
                padding: '0.35rem 1rem',
                background: 'transparent',
                color: '#6b7280',
                border: 'none',
                cursor: 'pointer',
                fontSize: '0.85rem',
              }}
            >
              关闭
            </button>
          </div>
        </div>
      )}
    </>
  );
}