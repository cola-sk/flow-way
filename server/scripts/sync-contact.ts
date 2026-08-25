/**
 * sync-contact.ts — 将本地 contact.json 或命令行参数同步更新到 Redis 数据库
 *
 * 用法:
 *   pnpm run sync-contact                          # 读取 server/src/config/contact.json 同步到数据库
 *   pnpm run sync-contact -- --wechat kero_wi      # 单独更新微信号
 *   pnpm run sync-contact -- --xianyu "https://..." # 单独更新闲鱼链接
 *   pnpm run sync-contact -- --show                # 仅查看当前数据库中的联系方式
 */

import { config } from 'dotenv';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 加载环境变量
config({ path: path.resolve(__dirname, '../.env.local') });
config();

import {
  getContactConfigFromDb,
  saveContactConfigToDb,
} from '../src/lib/contact-config';

async function main() {
  const args = process.argv.slice(2).filter((a) => a !== '--');
  const jsonPath = path.resolve(__dirname, '../src/config/contact.json');

  if (args.includes('--show')) {
    console.log('🔍 正在从数据库获取当前联系配置...');
    const current = await getContactConfigFromDb();
    console.log('----------------------------------------');
    console.log(`📱 微信号: ${current.wechatId}`);
    console.log(`🐟 闲鱼地址: ${current.xianyuUrl}`);
    console.log(`⏰ 最后更新时间: ${current.updatedAt || '无（使用兜底）'}`);
    console.log('----------------------------------------');
    return;
  }

  let wechatId: string | undefined;
  let xianyuUrl: string | undefined;

  const wechatIdx = args.indexOf('--wechat');
  if (wechatIdx !== -1 && args[wechatIdx + 1]) {
    wechatId = args[wechatIdx + 1].trim();
  }

  const xianyuIdx = args.indexOf('--xianyu');
  if (xianyuIdx !== -1 && args[xianyuIdx + 1]) {
    xianyuUrl = args[xianyuIdx + 1].trim();
  }

  // 如果没有通过命令行参数完全指定，则读取本地 contact.json
  if (!wechatId || !xianyuUrl) {
    if (fs.existsSync(jsonPath)) {
      try {
        const local = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
        if (!wechatId && local.wechatId) wechatId = local.wechatId;
        if (!xianyuUrl && local.xianyuUrl) xianyuUrl = local.xianyuUrl;
      } catch (err) {
        console.warn('⚠️ 读取本地 contact.json 失败:', err);
      }
    }
  }

  if (!wechatId || !xianyuUrl) {
    console.error('❌ 无法获取有效的联系方式配置 (wechatId 或 xianyuUrl 为空)');
    process.exit(1);
  }

  console.log('🔄 准备同步联系配置到数据库:');
  console.log(`   微信号: ${wechatId}`);
  console.log(`   闲鱼地址: ${xianyuUrl}`);

  const saved = await saveContactConfigToDb({ wechatId, xianyuUrl });
  console.log('✅ 已成功写入数据库！');
  console.log(`   更新时间: ${saved.updatedAt}`);

  // 同时同步写回本地 contact.json，保证本地与远端一致
  try {
    fs.writeFileSync(
      jsonPath,
      JSON.stringify({ wechatId: saved.wechatId, xianyuUrl: saved.xianyuUrl }, null, 2),
      'utf-8'
    );
    console.log('✅ 已同步更新本地 server/src/config/contact.json');
  } catch (err) {
    console.warn('⚠️ 写回本地 contact.json 失败:', err);
  }
}

main().catch((err) => {
  console.error('❌ 同步失败:', err);
  process.exit(1);
});
