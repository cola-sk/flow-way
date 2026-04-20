import { config } from 'dotenv';
import { resolve } from 'path';
import { runHardcodedAvoidCase } from './utils/hardcoded-case-runner';

config({ path: resolve(process.cwd(), '.env.local') });

runHardcodedAvoidCase({
  caseName: '瑞都公园世家南区 -> 通州运河公园体育场',
  start: {
    name: '瑞都公园世家南区',
    lat: 39.865137,
    lng: 116.679391,
  },
  end: {
    name: '通州运河公园体育场',
    lat: 39.910209,
    lng: 116.685768,
  },
  waypoints: [],
  retriesPerLeg: 3,
  maxTotalHits: 0,
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FAIL]', error);
    process.exit(1);
  });
