# Test Suite Documentation

This directory contains integration and regression tests for the Flow Way routing system.

## Test Files Overview

### 1. `regression.ts` - Regression Test for Camera Avoidance Algorithm
**Purpose**: Ensure the camera avoidance routing algorithm continues to work correctly after code changes.

**What it tests**:
- Fixed route coordinates that previously couldn't avoid cameras
- Ensures the algorithm finds routes with ZERO cameras
- Validates algorithm performance and distance ratios

**Test Case**: 瑞都公园世家南区 -> 台湖大集
- Start: `{ lat: 39.865137, lng: 116.679391 }`
- End: `{ lat: 39.839413, lng: 116.629009 }`

**Success Criteria**:
- ✅ Algorithm completes within reasonable time
- ✅ Returned route has 0 cameras
- ✅ Total distance stays within acceptable bounds

**Run**: `npx ts-node test/regression.ts`

### 2. `test-route.ts` - Dynamic Route Planning Test
**Purpose**: Test the camera avoidance routing algorithm against previously saved routes from the database.

**What it tests**:
- Loading saved routes from persistence layer (Redis)
- Fetching camera data for a geographic bounding box
- Running the camera avoidance routing algorithm
- Measuring algorithm performance (execution time)
- Verifying the algorithm finds alternative routes

**Prerequisites**:
- Next.js dev server running on `http://localhost:3000`
- Redis database with saved routes
- Camera data available via `/api/cameras` endpoint

**Run**: `npx ts-node test/test-route.ts`

---

## Running Tests

### Using npm scripts (Recommended)

```bash
# Run all tests
pnpm run test

# Run only regression test
pnpm run test:regression

# Run only dynamic route test
pnpm run test:route

# Run all tests with summary
pnpm run test:all
```

### Manual execution

```bash
# Ensure Next.js dev server is running first
cd server
pnpm run dev

# In another terminal, run tests
npx ts-node test/regression.ts
npx ts-node test/test-route.ts
```

---

## Test Output Examples

### Successful Regression Test
```
[REGRESSION TEST] Camera Avoidance Algorithm Regression Test

[INFO] Route: 瑞都公园世家南区 -> 台湖大集
[INFO] Start point: { lat: 39.865137, lng: 116.679391 }
[INFO] End point: { lat: 39.839413, lng: 116.629009 }
[INFO] Fetched cameras via API: 8
[INFO] Starting camera-avoidance route planning algorithm...

[RESULTS] ==================================
[RESULT] Execution Time: 245 ms
[RESULT] Cameras still on route: 0
[RESULT] Total Distance: 18450 meters
[RESULT] ==================================

✅ [PASS] Regression test PASSED! Successfully avoided all cameras.
```

### Successful Dynamic Route Test
```
[TEST] Starting Dynamic Route Planning Test...

[INFO] Found 3 saved routes
[INFO] Testing route: 瑞都公园世家南区 -> 台湖大集
[INFO] Start point: { lat: 39.865137, lng: 116.679391 }
[INFO] End point: { lat: 39.839413, lng: 116.629009 }
[INFO] Fetched cameras via API: 8

[RESULTS] =================================
[RESULT] Execution Time: 312 ms
[RESULT] Cameras still on route: 0
[RESULT] Total Distance: 18450 meters
[RESULT] ==================================

✅ [PASS] Route successfully avoids all cameras!
[TEST] Dynamic Route Planning Test completed.
```

---

## When to Add New Tests

Add a new test file when:
- 🐛 You encounter a bug in the routing algorithm
- 📊 You optimize a critical algorithm
- 🎯 You add a new feature that needs regression protection
- 🔄 You refactor major code sections

## Test Naming Convention

- **Regression tests**: `regression-*.ts` or `{feature}-regression.ts`
- **Integration tests**: `test-*.ts` or `{feature}-integration.ts`
- **Unit tests** (if added): `*.test.ts` or `*.spec.ts`

## CI/CD Integration

These tests are designed to be run in CI/CD pipelines:

```bash
# Example GitHub Actions workflow
- name: Run tests
  run: pnpm run test
```

---

## Troubleshooting

### Test fails with "Cannot find module" error
- Ensure Next.js dev server is running: `pnpm run dev`
- Verify you're in the `server` directory
- Check environment variables are loaded: `.env.local`

### Test times out
- Verify camera API is responding: `curl http://localhost:3000/api/cameras`
- Check Redis connection status
- Increase timeout in the test file if needed

### "No routes found" in dynamic route test
- Ensure you have saved at least one route via the app
- Check Redis database has saved routes: `redis-cli hgetall saved-routes`

---

## Contributing

When adding a new test:
1. Add comprehensive JSDoc comments at the top of the file
2. Include clear log statements with `[TEST]`, `[INFO]`, `[RESULT]`, `[ERROR]` prefixes
3. Add the test to `package.json` scripts
4. Update this README with test details
5. Test locally before committing

