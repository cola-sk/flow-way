import { loadEnvConfig } from '@next/env';
import { resolve } from 'path';

loadEnvConfig(resolve(process.cwd(), './'));

import { planAvoidCamerasRoute } from '../src/lib/route';
import { getCameras } from '../src/lib/cache';

async function run() {
  const { cameras } = await getCameras();
  // 模拟从瑞都公园（南门） -> 大运河森林公园（西门）
  const start = { lat: 39.881265, lng: 116.657158 }; 
  const end = { lat: 39.878953, lng: 116.712686 }; 
  
  console.log('加载摄像头总数:', cameras.length);
  console.log('开始使用新算法计算避让路线...');
  
  const startT = Date.now();
  const res = await planAvoidCamerasRoute(start, end, cameras);
  
  console.log('\n--- 测试结果 ---');
  console.log('总耗时:', Date.now() - startT, 'ms');
  console.log('该路线上由于无法避开或达到最优解，最终途径摄像头数:', res.cameraIndices.length);
  console.log('路线总长:', res.distance, 'm');
}
run().catch(console.error);
