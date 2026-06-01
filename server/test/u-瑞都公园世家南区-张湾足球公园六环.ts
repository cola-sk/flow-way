import { config } from 'dotenv';
import { resolve } from 'path';
import { runHardcodedAvoidCase } from './utils/hardcoded-case-runner';

config({ path: resolve(process.cwd(), '.env.local') });

runHardcodedAvoidCase({
  caseName: '[用户方案] 瑞都公园世家南区 -> 张湾足球公园(六环)',
  start: { name: '瑞都公园世家南区', lat: 39.865137, lng: 116.679391 },
  end: { name: '通州区张家湾张湾足球公园西100米(六环)', lat: 39.856372, lng: 116.697001 },
  waypoints: [],
  retriesPerLeg: 3,
  // v1 基线: hits=3~4, distance=4692~4731. 六环附近短途路线，摄像头极密集，难以完全避让
  maxTotalHits: 4,
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FAIL]', error);
    process.exit(1);
  });
