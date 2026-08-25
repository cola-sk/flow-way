# server/scripts/release.ts

- readVersion · function · L34-L39 — function readVersion(): { semver: string; build: number }
- bumpSemver · function · L42-L56 — function bumpSemver(current: string, bump: string): string
- writeVersion · function · L59-L66 — function writeVersion(newSemver: string, newBuild: number)
- uploadApk · function · L69-L103 — async function uploadApk(semver: string, build: number, fileBuffer: Buffer)
- main · function · L106-L144 — async function main()
