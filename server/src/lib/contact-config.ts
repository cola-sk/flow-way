import { getRedis } from './redis';
import contactFallback from '../config/contact.json';

export const APP_CONTACT_CONFIG_KEY = 'app:contact-config';

export interface ContactConfig {
  wechatId: string;
  xianyuUrl: string;
  updatedAt?: string;
}

export async function getContactConfigFromDb(): Promise<ContactConfig> {
  try {
    const redis = getRedis();
    if (redis) {
      const data = await redis.get<ContactConfig | string>(APP_CONTACT_CONFIG_KEY);
      if (data) {
        const parsed = typeof data === 'string' ? JSON.parse(data) : data;
        return {
          wechatId: parsed.wechatId || contactFallback.wechatId || '',
          xianyuUrl: parsed.xianyuUrl || contactFallback.xianyuUrl || '',
          updatedAt: parsed.updatedAt,
        };
      }
    }
  } catch (err) {
    console.warn('读取数据库联系方式失败，使用本地兜底:', err);
  }

  return {
    wechatId: contactFallback.wechatId || '',
    xianyuUrl: contactFallback.xianyuUrl || '',
  };
}

export async function saveContactConfigToDb(config: {
  wechatId: string;
  xianyuUrl: string;
}): Promise<ContactConfig> {
  const redis = getRedis();
  if (!redis) {
    throw new Error('Redis is not configured in environment');
  }

  const payload: ContactConfig = {
    wechatId: config.wechatId.trim(),
    xianyuUrl: config.xianyuUrl.trim(),
    updatedAt: new Date().toISOString(),
  };

  await redis.set(APP_CONTACT_CONFIG_KEY, JSON.stringify(payload));
  return payload;
}
