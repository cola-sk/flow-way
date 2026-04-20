import { config } from 'dotenv';
import { resolve } from 'path';
import { runHardcodedAvoidCase } from './utils/hardcoded-case-runner';

config({ path: resolve(process.cwd(), '.env.local') });

runHardcodedAvoidCase({
  caseName: '瑞都公园世家南区 -> 台湖大集（孙庄村支部委员会途径点）',
  start: {
    name: '瑞都公园世家南区',
    lat: 39.865137,
    lng: 116.679391,
  },
  end: {
    name: '台湖大集',
    lat: 39.839413,
    lng: 116.629009,
  },
  waypoints: [
    {
      name: '中共通州区梨园镇孙庄村支部委员会(日新路西)',
      lat: 39.866252,
      lng: 116.650658,
    },
  ],
  retriesPerLeg: 3,
  maxTotalHits: 1,
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FAIL]', error);
    process.exit(1);
  });
