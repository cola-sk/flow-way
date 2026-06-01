import { config } from 'dotenv';
import { resolve } from 'path';
import { runHardcodedAvoidCase } from './utils/hardcoded-case-runner';

config({ path: resolve(process.cwd(), '.env.local') });

runHardcodedAvoidCase({
  caseName: '[用户方案] 京华福满园(福园) -> 瑞都公园世家南区',
  start: { name: '京华福满园(福园)', lat: 39.888496, lng: 116.711198 },
  end: { name: '瑞都公园世家南区', lat: 39.865137, lng: 116.679391 },
  waypoints: [],
  retriesPerLeg: 3,
  maxTotalHits: 2,
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FAIL]', error);
    process.exit(1);
  });
