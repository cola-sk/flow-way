import { Camera } from '@/types/camera';
import { EnhancedCamera } from '@/types/camera-enhanced';
import { createEnhancedCamera } from '@/lib/camera-parser';
import { v4 as uuidv4 } from 'uuid';

const SOURCE_URL = 'https://www.jinjing365.com/index.asp';

/**
 * 从 jinjing365.com 抓取摄像头坐标数据
 * 页面将摄像头数据内嵌在 JS 变量 LabelsData 数组中
 */
export async function scrapeCameras(): Promise<{
  cameras: Camera[];
  updatedAt: string;
}> {
  const res = await fetch(SOURCE_URL, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  });

  const html = await res.text();

  // 提取更新时间
  const timeMatch = html.match(
    /(\d{4}-\d{2}-\d{2}-\d{2}[：:]\d{2}[：:]\d{2})/
  );
  const updatedAt = timeMatch
    ? timeMatch[1].replace(/：/g, ':')
    : new Date().toISOString();

  // 提取 LabelsData 数组中的每一项
  // 每项格式: { name: '...', position: [lng, lat], aa: '1', time: '...', href: '...' }
  const cameras: Camera[] = [];

  const entryRegex =
    /name:\s*'([^']*)',\s*position:\s*\[([0-9.]+),([0-9.]+)\],\s*aa:\s*'(\d+)',\s*time:\s*'([^']*)'/g;

  let match: RegExpExecArray | null;
  while ((match = entryRegex.exec(html)) !== null) {
    cameras.push({
      name: match[1],
      lng: parseFloat(match[2]),
      lat: parseFloat(match[3]),
      type: parseInt(match[4], 10),
      date: match[5],
      href: '', // href 由单独的正则获取，简化处理
    });
  }

  // 尝试提取 href（可选，结构较复杂时跳过）
  const hrefRegex =
    /name:\s*'([^']*)'[\s\S]*?href:\s*'([^']*)'/g;
  const hrefMap = new Map<string, string>();
  while ((match = hrefRegex.exec(html)) !== null) {
    hrefMap.set(match[1], match[2]);
  }

  for (const cam of cameras) {
    const href = hrefMap.get(cam.name);
    if (href) cam.href = href;
  }

  return { cameras, updatedAt };
}

/**
 * 从 jinjing365.com 抓取增强的摄像头数据
 * 包含方向、状态、位置描述等详细信息
 */
export async function scrapeCamerasEnhanced(): Promise<{
  cameras: EnhancedCamera[];
  updatedAt: string;
}> {
  const { cameras: basicCameras, updatedAt } = await scrapeCameras();

  // 将基础摄像头数据转换为增强数据
  const cameras: EnhancedCamera[] = basicCameras.map((cam, index) =>
    createEnhancedCamera(
      `camera_${index}_${uuidv4().substring(0, 8)}`,
      cam.name,
      cam.lng,
      cam.lat,
      cam.type,
      cam.date,
      cam.href
    )
  );

  return { cameras, updatedAt };
}
