import { config } from 'dotenv';
import { resolve } from 'path';
import { runHardcodedAvoidCase } from './utils/hardcoded-case-runner';

config({ path: resolve(process.cwd(), '.env.local') });

runHardcodedAvoidCase({
  caseName: '[用户方案] 瑞都公园世家南区 -> 隆昊肉类(西关店)',
  start: { name: '瑞都公园世家南区', lat: 39.865137, lng: 116.679391 },
  end: { name: '隆昊肉类(西关店)', lat: 39.902183, lng: 116.641321 },
  waypoints: [],
  retriesPerLeg: 3,
  maxTotalHits: 2,
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FAIL]', error);
    process.exit(1);
  });
