import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { once } from 'node:events'
import { mkdtemp, rm } from 'node:fs/promises'
import { createServer } from 'node:net'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { setTimeout as delay } from 'node:timers/promises'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('..', import.meta.url))
const relayRoot = resolve(process.argv[2] ?? join(root, '../aimeio-backend-ws'))
const flutter = process.env.FLUTTER_BIN ?? 'flutter'
const stateDir = await mkdtemp(join(tmpdir(), 'controller-relay-'))
const allocator = createServer()
allocator.listen(0, '127.0.0.1')
await once(allocator, 'listening')
const port = allocator.address().port
await new Promise((resolve, reject) => allocator.close(error => error ? reject(error) : resolve()))
const worker = spawn(process.execPath, [
  join(relayRoot, 'node_modules/wrangler/bin/wrangler.js'), 'dev',
  '--local', '--ip', '127.0.0.1', '--port', String(port),
  '--inspector-port', '0', '--persist-to', stateDir,
  '--show-interactive-dev-session=false',
], {
  cwd: relayRoot, env: { ...process.env, WRANGLER_SEND_METRICS: 'false' },
  stdio: ['ignore', 'pipe', 'pipe'],
})
let output = ''
let spawnError
worker.on('error', error => { spawnError = error })
worker.stdout.on('data', data => { output = (output + data).slice(-16000) })
worker.stderr.on('data', data => { output = (output + data).slice(-16000) })
let tests
try {
  let ready = false
  const deadline = Date.now() + 30000
  while (Date.now() < deadline) {
    if (spawnError) throw spawnError
    if (worker.exitCode !== null || worker.signalCode !== null) throw new Error('Wrangler exited')
    try {
      const response = await fetch(`http://127.0.0.1:${port}/ready`, { signal: AbortSignal.timeout(1000) })
      if (response.status === 426) { ready = true; break }
    } catch { /* Worker is starting. */ }
    await delay(200)
  }
  assert.ok(ready, 'Local Relay did not become ready')
  tests = spawn(flutter, ['test', 'test/relay_integration_test.dart', '--concurrency=1', '--reporter=expanded'], {
    cwd: root,
    env: { ...process.env, RELAY_TEST_URL: `http://127.0.0.1:${port}/frontend-smoke` },
    stdio: 'inherit',
  })
  const testResult = await new Promise((resolve, reject) => {
    tests.once('error', reject)
    tests.once('exit', (code, signal) => resolve({ code, signal }))
  })
  assert.equal(testResult.code, 0, `Controller integration tests failed: ${JSON.stringify(testResult)}`)
  console.log('Controller WebSocket smoke passed: commands and three IO events, plaintext and E2EE_V1.')
} catch (error) {
  process.stderr.write(output)
  throw error
} finally {
  if (tests && tests.exitCode === null && tests.signalCode === null) tests.kill('SIGTERM')
  if (worker.exitCode === null && worker.signalCode === null) {
    const stopped = once(worker, 'exit')
    worker.kill('SIGTERM')
    await stopped
  }
  await rm(stateDir, { recursive: true, force: true })
}
