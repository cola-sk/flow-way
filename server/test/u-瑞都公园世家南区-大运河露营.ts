import { config } from 'dotenv';
import { resolve } from 'path';
import { runHardcodedAvoidCase } from './utils/hardcoded-case-runner';

config({ path: resolve(process.cwd(), '.env.local') });

runHardcodedAvoidCase({
  caseName: '[用户方案] 瑞都公园世家南区 -> 大运河露营',
  start: { name: '瑞都公园世家南区', lat: 39.865137, lng: 116.679391 },
  end: { name: '通州区运河别墅西南150米(云帆路东)', lat: 39.872462, lng: 116.752954 },
  waypoints: [],
  retriesPerLeg: 3,
  maxTotalHits: 2,
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FAIL]', error);
    process.exit(1);
  });
