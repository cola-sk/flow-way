import { createHash } from 'crypto';

const TENCENT_MAP_KEY = process.env.TENCENT_MAP_KEY ?? '';
const TENCENT_MAP_SK = process.env.TENCENT_MAP_SK ?? '';

/**
 * 给腾讯地图 WebService API 的 URL 追加 key 和 sig 参数。
 * SN 签名算法：sig = MD5(路径 + "?" + 按 key 字典序排列的参数 + SK)
 *
 * 参考：https://lbs.qq.com/service/webService/webServiceGuide/webServiceSignature
 */
export function signTencentUrl(url: URL): string {
  // 确保 key 在参数中
  url.searchParams.set('key', TENCENT_MAP_KEY);

  // 按 key 字典序排列参数
  const sortedParams = new URLSearchParams(
    [...url.searchParams.entries()].sort(([a], [b]) => a.localeCompare(b))
  );

  if (TENCENT_MAP_SK) {
    const pathAndQuery = `${url.pathname}?${sortedParams.toString()}${TENCENT_MAP_SK}`;
    const sig = createHash('md5').update(pathAndQuery).digest('hex');
    sortedParams.set('sig', sig);
  }

  return `${url.origin}${url.pathname}?${sortedParams.toString()}`;
}

export { TENCENT_MAP_KEY };
