import { createHash } from 'crypto';

// 每次调用时从 process.env 读取，避免模块初始化时 env 未就绪的问题
function getKey() { return process.env.TENCENT_MAP_KEY ?? ''; }
function getSk() { return process.env.TENCENT_MAP_SK ?? ''; }

/**
 * 给腾讯地图 WebService API 的 URL 追加 key 和 sig 参数。
 * SN 签名算法：sig = MD5(路径 + "?" + 按 key 字典序排列的参数 + SK)
 *
 * 参考：https://lbs.qq.com/service/webService/webServiceGuide/webServiceSignature
 */
export function signTencentUrl(url: URL): string {
  const TENCENT_MAP_KEY = getKey();
  const TENCENT_MAP_SK = getSk();

  console.log('[sign] key present:', !!TENCENT_MAP_KEY, 'sk present:', !!TENCENT_MAP_SK);

  // 确保 key 在参数中
  url.searchParams.set('key', TENCENT_MAP_KEY);

  // 按 key 字典序排列参数
  const sortedEntries = [...url.searchParams.entries()].sort(([a], [b]) => a.localeCompare(b));

  if (TENCENT_MAP_SK) {
    // 签名字符串必须使用原始未编码的参数值（腾讯签名规范要求）
    const rawQuery = sortedEntries.map(([k, v]) => `${k}=${v}`).join('&');
    const pathAndQuery = `${url.pathname}?${rawQuery}${TENCENT_MAP_SK}`;
    const sig = createHash('md5').update(pathAndQuery).digest('hex');
    sortedEntries.push(['sig', sig]);
  }

  const sortedParams = new URLSearchParams(sortedEntries);
  return `${url.origin}${url.pathname}?${sortedParams.toString()}`;
}

export function getTencentMapKey() { return getKey(); }
